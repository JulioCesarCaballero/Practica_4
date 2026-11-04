package mx.ipn.escom.gestor_archivos

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/**
 * Código específico de Android para la Práctica 4.
 *
 * Implementa el acceso a documentos con el Storage Access Framework (SAF):
 *  - ACTION_OPEN_DOCUMENT_TREE: el usuario elige una carpeta y la app recibe
 *    un permiso persistente SOLO sobre esa carpeta (Scoped Storage).
 *  - ACTION_OPEN_DOCUMENT: el usuario elige un archivo suelto.
 *  - ACTION_CREATE_DOCUMENT: el usuario elige dónde exportar un archivo.
 *  - DocumentsContract: listar, renombrar, eliminar, copiar, mover y crear.
 *
 * La app NO declara READ/WRITE_EXTERNAL_STORAGE ni MANAGE_EXTERNAL_STORAGE:
 * todo el acceso fuera del almacenamiento privado pasa por el selector del sistema.
 *
 * Dart se comunica con esta clase por el MethodChannel "mx.ipn.escom/saf".
 * Las operaciones de E/S se ejecutan en un hilo secundario para no bloquear la UI.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CANAL = "mx.ipn.escom/saf"
        private const val REQ_CARPETA = 4101
        private const val REQ_ARCHIVO = 4102
        private const val REQ_EXPORTAR = 4103

        private val COLUMNAS = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_SIZE,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_FLAGS
        )
    }

    private val permisoLecturaEscritura =
        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    private val flagsSelector = permisoLecturaEscritura or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION

    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())
    private var resultadoPendiente: MethodChannel.Result? = null
    private var rutaPorExportar: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { call, result -> manejar(call, result) }
    }

    private fun manejar(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "elegirCarpeta" -> lanzarSelector(
                result, REQ_CARPETA,
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(flagsSelector)
            )
            "elegirArchivo" -> lanzarSelector(
                result, REQ_ARCHIVO,
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*")
                    .addFlags(flagsSelector)
            )
            "exportar" -> {
                rutaPorExportar = call.argument<String>("ruta")
                lanzarSelector(
                    result, REQ_EXPORTAR,
                    Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType(call.argument<String>("mime") ?: "application/octet-stream")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("nombre") ?: "archivo")
                )
            }
            "carpetasAutorizadas" -> enSegundoPlano(result) { carpetasAutorizadas() }
            "quitarAcceso" -> enSegundoPlano(result) { quitarAcceso(uri(call)) }
            "info" -> enSegundoPlano(result) { info(uri(call), raiz(call)) }
            "listar" -> enSegundoPlano(result) { listar(uri(call), raiz(call)) }
            "copiarACache" -> enSegundoPlano(result) {
                copiarACache(uri(call), call.argument<String>("nombre") ?: "archivo")
            }
            "renombrar" -> enSegundoPlano(result) {
                val nuevo = DocumentsContract.renameDocument(
                    contentResolver, uri(call), call.argument<String>("nombre")!!
                ) ?: throw UnsupportedOperationException("El proveedor no permitió renombrar")
                info(nuevo, raiz(call))
            }
            "eliminar" -> enSegundoPlano(result) {
                if (!DocumentsContract.deleteDocument(contentResolver, uri(call))) {
                    throw UnsupportedOperationException("El proveedor no permitió eliminar el documento")
                }
                true
            }
            "copiar" -> enSegundoPlano(result) {
                copiar(uri(call), Uri.parse(call.argument<String>("destino")!!), raiz(call))
            }
            "mover" -> enSegundoPlano(result) {
                mover(
                    uri(call),
                    Uri.parse(call.argument<String>("padre")!!),
                    Uri.parse(call.argument<String>("destino")!!),
                    raiz(call)
                )
            }
            "crearCarpeta" -> enSegundoPlano(result) {
                val nueva = DocumentsContract.createDocument(
                    contentResolver, uri(call), Document.MIME_TYPE_DIR, call.argument<String>("nombre")!!
                ) ?: throw UnsupportedOperationException("La carpeta no permite crear elementos")
                info(nueva, raiz(call))
            }
            "crearArchivo" -> enSegundoPlano(result) {
                val nuevo = DocumentsContract.createDocument(
                    contentResolver, uri(call),
                    call.argument<String>("mime") ?: "text/plain",
                    call.argument<String>("nombre")!!
                ) ?: throw UnsupportedOperationException("La carpeta no permite crear archivos")
                val texto = call.argument<String>("texto") ?: ""
                contentResolver.openOutputStream(nuevo)?.use { it.write(texto.toByteArray()) }
                    ?: throw FileNotFoundException("No se pudo escribir el archivo")
                info(nuevo, raiz(call))
            }
            "abrirCon" -> abrirCon(result, uri(call), call.argument<String>("mime"))
            "compartir" -> compartir(result, uri(call), call.argument<String>("mime"))
            "espacioLibre" -> enSegundoPlano(result) {
                StatFs(call.argument<String>("ruta")!!).availableBytes
            }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------- selectores

    private fun lanzarSelector(result: MethodChannel.Result, codigo: Int, intent: Intent) {
        if (resultadoPendiente != null) {
            result.error("OCUPADO", "Ya hay un selector abierto", null)
            return
        }
        resultadoPendiente = result
        try {
            startActivityForResult(intent, codigo)
        } catch (e: ActivityNotFoundException) {
            resultadoPendiente = null
            result.error("NO_SOPORTADO", "Este dispositivo no tiene selector de documentos", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_CARPETA && requestCode != REQ_ARCHIVO && requestCode != REQ_EXPORTAR) return
        val result = resultadoPendiente ?: return
        resultadoPendiente = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            // El usuario canceló: se respeta su decisión y se devuelve null.
            rutaPorExportar = null
            result.success(null)
            return
        }
        when (requestCode) {
            REQ_CARPETA -> enSegundoPlano(result) {
                persistir(uri)
                val raiz = DocumentsContract.buildDocumentUriUsingTree(
                    uri, DocumentsContract.getTreeDocumentId(uri)
                )
                info(raiz, raiz)
            }
            REQ_ARCHIVO -> enSegundoPlano(result) {
                persistir(uri)
                info(uri, null)
            }
            REQ_EXPORTAR -> {
                val ruta = rutaPorExportar
                rutaPorExportar = null
                enSegundoPlano(result) {
                    if (ruta == null) throw FileNotFoundException("No hay archivo para exportar")
                    contentResolver.openOutputStream(uri)?.use { salida ->
                        File(ruta).inputStream().use { it.copyTo(salida) }
                    } ?: throw FileNotFoundException("No se pudo escribir en el destino")
                    uri.toString()
                }
            }
        }
    }

    /** Conserva el permiso después de reiniciar la app (lectura/escritura si es posible). */
    private fun persistir(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(uri, permisoLecturaEscritura)
        } catch (e: SecurityException) {
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (ignorada: SecurityException) {
                // El proveedor no ofrece permisos persistentes; solo habrá acceso en esta sesión.
            }
        }
    }

    // ---------------------------------------------------------------- consultas

    private fun carpetasAutorizadas(): List<Map<String, Any?>> =
        contentResolver.persistedUriPermissions
            .filter { DocumentsContract.isTreeUri(it.uri) }
            .map { permiso ->
                val raiz = DocumentsContract.buildDocumentUriUsingTree(
                    permiso.uri, DocumentsContract.getTreeDocumentId(permiso.uri)
                )
                try {
                    info(raiz, raiz) + mapOf("disponible" to true)
                } catch (e: Exception) {
                    mapOf(
                        "uri" to raiz.toString(),
                        "raiz" to raiz.toString(),
                        "nombre" to (permiso.uri.lastPathSegment ?: "Carpeta"),
                        "esCarpeta" to true,
                        "disponible" to false
                    )
                }
            }

    private fun quitarAcceso(raiz: Uri): Boolean {
        val arbol = DocumentsContract.buildTreeDocumentUri(
            raiz.authority, DocumentsContract.getTreeDocumentId(raiz)
        )
        for (p in contentResolver.persistedUriPermissions) {
            if (p.uri.toString() == arbol.toString()) {
                var flags = 0
                if (p.isReadPermission) flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
                if (p.isWritePermission) flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                contentResolver.releasePersistableUriPermission(p.uri, flags)
            }
        }
        return true
    }

    private fun info(uri: Uri, raiz: Uri?): Map<String, Any?> {
        contentResolver.query(uri, COLUMNAS, null, null, null)?.use { c ->
            if (c.moveToFirst()) return fila(c, uri, raiz)
        }
        throw FileNotFoundException("El documento ya no existe o no está disponible")
    }

    private fun listar(carpeta: Uri, raiz: Uri?): List<Map<String, Any?>> {
        val docId = DocumentsContract.getDocumentId(carpeta)
        val hijos = DocumentsContract.buildChildDocumentsUriUsingTree(carpeta, docId)
        val lista = ArrayList<Map<String, Any?>>()
        contentResolver.query(hijos, COLUMNAS, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val hijo = DocumentsContract.buildDocumentUriUsingTree(carpeta, c.getString(0))
                lista.add(fila(c, hijo, raiz))
            }
        } ?: throw FileNotFoundException("No se pudo leer la carpeta")
        return lista
    }

    private fun fila(c: Cursor, uri: Uri, raiz: Uri?): Map<String, Any?> {
        val mime: String? = if (c.isNull(2)) null else c.getString(2)
        val flags = if (c.isNull(5)) 0 else c.getInt(5)
        val esCarpeta = mime == Document.MIME_TYPE_DIR
        return mapOf(
            "uri" to uri.toString(),
            "raiz" to raiz?.toString(),
            "nombre" to (if (c.isNull(1)) "(sin nombre)" else c.getString(1)),
            "mime" to (if (esCarpeta) null else mime),
            "esCarpeta" to esCarpeta,
            "tamano" to (if (c.isNull(3) || esCarpeta) null else c.getLong(3)),
            "modificado" to (if (c.isNull(4)) null else c.getLong(4)),
            "puedeEscribir" to ((flags and Document.FLAG_SUPPORTS_WRITE) != 0),
            "puedeEliminar" to ((flags and Document.FLAG_SUPPORTS_DELETE) != 0),
            "puedeRenombrar" to ((flags and Document.FLAG_SUPPORTS_RENAME) != 0),
            "puedeCrear" to ((flags and Document.FLAG_DIR_SUPPORTS_CREATE) != 0),
            "disponible" to true
        )
    }

    // ---------------------------------------------------------------- operaciones

    private fun copiarACache(uri: Uri, nombre: String): String {
        val dir = File(cacheDir, "saf").apply { mkdirs() }
        val seguro = nombre.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val destino = File(dir, Integer.toHexString(uri.toString().hashCode()) + "_" + seguro)
        contentResolver.openInputStream(uri)?.use { entrada ->
            destino.outputStream().use { entrada.copyTo(it) }
        } ?: throw FileNotFoundException("No se pudo abrir el documento")
        return destino.absolutePath
    }

    private fun copiar(origen: Uri, destino: Uri, raiz: Uri?): Map<String, Any?> {
        val datos = info(origen, null)
        if (datos["esCarpeta"] == true) {
            throw UnsupportedOperationException("Copiar carpetas completas no está disponible en carpetas externas")
        }
        val nombre = datos["nombre"] as String
        val mime = (datos["mime"] as String?) ?: "application/octet-stream"
        val nuevo = DocumentsContract.createDocument(contentResolver, destino, mime, nombre)
            ?: throw UnsupportedOperationException("La carpeta destino no permite crear archivos")
        contentResolver.openInputStream(origen)?.use { entrada ->
            contentResolver.openOutputStream(nuevo)?.use { salida -> entrada.copyTo(salida) }
                ?: throw FileNotFoundException("No se pudo escribir en el destino")
        } ?: throw FileNotFoundException("No se pudo leer el original")
        return info(nuevo, raiz)
    }

    private fun mover(origen: Uri, padre: Uri, destino: Uri, raiz: Uri?): Map<String, Any?> {
        // 1) Intento nativo (solo algunos proveedores lo soportan).
        try {
            val movido = DocumentsContract.moveDocument(contentResolver, origen, padre, destino)
            if (movido != null) return info(movido, raiz)
        } catch (e: Exception) {
            // Se intenta copiar + eliminar.
        }
        // 2) Alternativa: copiar y luego eliminar el original.
        val copia = copiar(origen, destino, raiz)
        if (!DocumentsContract.deleteDocument(contentResolver, origen)) {
            throw UnsupportedOperationException("Se copió el archivo, pero el proveedor no permitió eliminar el original")
        }
        return copia
    }

    private fun abrirCon(result: MethodChannel.Result, uri: Uri, mime: String?) {
        try {
            val intent = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, mime ?: "*/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(intent, "Abrir con"))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("SIN_APP", "No hay ninguna app para abrir este tipo de archivo", null)
        }
    }

    private fun compartir(result: MethodChannel.Result, uri: Uri, mime: String?) {
        try {
            val intent = Intent(Intent.ACTION_SEND)
                .setType(mime ?: "application/octet-stream")
                .putExtra(Intent.EXTRA_STREAM, uri)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(intent, "Compartir"))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("SIN_APP", "No hay ninguna app para compartir", null)
        }
    }

    // ---------------------------------------------------------------- utilidades

    private fun uri(call: MethodCall): Uri = Uri.parse(call.argument<String>("uri")!!)

    private fun raiz(call: MethodCall): Uri? = call.argument<String>("raiz")?.let { Uri.parse(it) }

    /** Ejecuta en segundo plano y traduce las excepciones a códigos que entiende Dart. */
    private fun enSegundoPlano(result: MethodChannel.Result, tarea: () -> Any?) {
        hilo.execute {
            try {
                val valor = tarea()
                principal.post { result.success(valor) }
            } catch (e: SecurityException) {
                principal.post { result.error("PERMISO", e.message ?: "Permiso denegado o revocado", null) }
            } catch (e: FileNotFoundException) {
                principal.post { result.error("NO_ENCONTRADO", e.message ?: "No encontrado", null) }
            } catch (e: IllegalArgumentException) {
                principal.post { result.error("NO_ENCONTRADO", e.message ?: "Documento no válido", null) }
            } catch (e: UnsupportedOperationException) {
                principal.post { result.error("NO_SOPORTADO", e.message ?: "Operación no permitida", null) }
            } catch (e: Exception) {
                val sinEspacio = (e.message ?: "").contains("ENOSPC") || (e.message ?: "").contains("No space")
                principal.post {
                    result.error(if (sinEspacio) "SIN_ESPACIO" else "ERROR", e.message ?: e.toString(), null)
                }
            }
        }
    }
}