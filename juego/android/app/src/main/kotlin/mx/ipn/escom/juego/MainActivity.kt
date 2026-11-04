package mx.ipn.escom.juego

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Código específico de Android del juego.
 *
 * Exporta una partida a la ubicación que el usuario elija con el selector del
 * sistema (Storage Access Framework, ACTION_CREATE_DOCUMENT). No se piden
 * permisos de almacenamiento: el usuario decide el destino y Android concede
 * acceso solo a ese documento.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CANAL = "mx.ipn.escom/archivos"
        private const val REQ_EXPORTAR = 5101
    }

    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())
    private var pendiente: MethodChannel.Result? = null
    private var rutaPorExportar: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportar" -> {
                    if (pendiente != null) {
                        result.error("OCUPADO", "Ya hay un selector abierto", null)
                        return@setMethodCallHandler
                    }
                    rutaPorExportar = call.argument<String>("ruta")
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType(call.argument<String>("mime") ?: "application/octet-stream")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("nombre") ?: "partida")
                    pendiente = result
                    try {
                        startActivityForResult(intent, REQ_EXPORTAR)
                    } catch (e: ActivityNotFoundException) {
                        pendiente = null
                        result.error("NO_SOPORTADO", "Este dispositivo no tiene selector de documentos", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_EXPORTAR) return
        val result = pendiente ?: return
        pendiente = null
        val ruta = rutaPorExportar
        rutaPorExportar = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || ruta == null) {
            result.success(null) // cancelado por el usuario
            return
        }
        hilo.execute {
            try {
                val salida = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("No se pudo escribir en el destino")
                salida.use { s -> File(ruta).inputStream().use { it.copyTo(s) } }
                principal.post { result.success(uri.toString()) }
            } catch (e: SecurityException) {
                principal.post { result.error("PERMISO", e.message ?: "Permiso denegado", null) }
            } catch (e: Exception) {
                principal.post { result.error("ERROR", e.message ?: e.toString(), null) }
            }
        }
    }
}
