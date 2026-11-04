import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/errores.dart';
import '../core/formato.dart';
import '../platform/saf_android.dart';
import 'entrada.dart';

/// Operaciones sobre archivos. Cada método decide si usa dart:io
/// (almacenamiento privado) o el Storage Access Framework (documentos autorizados).
class Archivos {
  static late Directory raizLocal;

  static Entrada get entradaRaizLocal => Entrada(
        id: raizLocal.path,
        nombre: 'Almacenamiento de la app',
        esCarpeta: true,
        origen: Origen.local,
      );

  /// Prepara el almacenamiento privado y crea archivos de ejemplo la primera vez.
  static Future<void> inicializar() async {
    raizLocal = await getApplicationDocumentsDirectory();
    final marca = File(p.join(raizLocal.path, '.ejemplos_creados'));
    if (!await marca.exists()) {
      try {
        await crearEjemplos();
        await marca.writeAsString(DateTime.now().toIso8601String());
      } catch (_) {
        // Si falla (p. ej. sin espacio) la app sigue funcionando.
      }
    }
  }

  /// Crea archivos de ejemplo de cada formato para probar los visores.
  static Future<void> crearEjemplos() async {
    final base = raizLocal.path;
    await Directory(p.join(base, 'Documentos')).create(recursive: true);
    await Directory(p.join(base, 'Imágenes')).create(recursive: true);
    await Directory(p.join(base, 'Datos')).create(recursive: true);
    await Directory(p.join(base, 'Carpeta vacía')).create(recursive: true);

    await File(p.join(base, 'Bienvenida.txt')).writeAsString(
      'Gestor de archivos - Práctica 4\n'
      'Desarrollo de aplicaciones móviles nativas - ESCOM IPN\n\n'
      'Estos archivos se crearon en el almacenamiento privado de la app.\n'
      'Prueba abrirlos, renombrarlos, copiarlos, moverlos o eliminarlos.\n',
    );
    await File(p.join(base, 'Documentos', 'notas.md')).writeAsString(
      '# Notas de la práctica\n\n'
      '- Scoped Storage: la app solo ve su espacio y lo que el usuario autoriza.\n'
      '- SAF: Storage Access Framework (ACTION_OPEN_DOCUMENT_TREE).\n'
      '- Formatos: **TXT**, **JSON**, **XML**, imágenes.\n',
    );
    await File(p.join(base, 'Datos', 'configuracion.json')).writeAsString(jsonEncode({
      'app': 'Gestor ESCOM',
      'version': 1,
      'tema': {'paleta': 'guinda', 'modo': 'sistema'},
      'offline': true,
      'formatos': ['txt', 'md', 'json', 'xml', 'png'],
      'limites': {'recientes': 20, 'miniaturas': 150},
    }));
    await File(p.join(base, 'Datos', 'catalogo.xml')).writeAsString(
      '<?xml version="1.0" encoding="UTF-8"?><catalogo><materia clave="DAMN" semestre="7">'
      '<nombre>Desarrollo de aplicaciones móviles nativas</nombre><practica numero="4">'
      '<titulo>Gestión de archivos multiplataforma</titulo><entregada>false</entregada>'
      '</practica></materia><!-- Comentario de ejemplo --></catalogo>',
    );
    await File(p.join(base, 'Datos', 'alumnos.csv')).writeAsString(
      'boleta,nombre,grupo\n2027000001,Ana López,7CM1\n2027000002,Luis Pérez,7CM1\n',
    );
    final imagen = await rootBundle.load('assets/ejemplo/paisaje.png');
    await File(p.join(base, 'Imágenes', 'paisaje.png'))
        .writeAsBytes(imagen.buffer.asUint8List(imagen.offsetInBytes, imagen.lengthInBytes));
    await File(p.join(base, 'Datos', 'datos.bin'))
        .writeAsBytes(List<int>.generate(512, (i) => (i * 37) % 256));
  }

  // ------------------------------------------------------------------ lectura

  static Future<Entrada> entradaLocal(FileSystemEntity e) async {
    final st = await e.stat();
    if (st.type == FileSystemEntityType.notFound) {
      throw const ErrorApp('El archivo o carpeta ya no existe.');
    }
    final esCarpeta = st.type == FileSystemEntityType.directory;
    return Entrada(
      id: e.path,
      nombre: p.basename(e.path),
      esCarpeta: esCarpeta,
      origen: Origen.local,
      tamano: esCarpeta ? null : st.size,
      modificado: st.modified,
      creado: null, // Android/Linux no exponen la fecha de creación por dart:io
      mime: esCarpeta ? null : lookupMimeType(e.path),
    );
  }

  static List<Entrada> _ordenar(List<Entrada> lista) {
    lista.sort((a, b) {
      if (a.esCarpeta != b.esCarpeta) return a.esCarpeta ? -1 : 1;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return lista;
  }

  static Future<List<Entrada>> listar(Entrada carpeta) async {
    if (carpeta.origen == Origen.saf) {
      return _ordenar(await SafAndroid.listar(carpeta));
    }
    final dir = Directory(carpeta.id);
    if (!await dir.exists()) throw const ErrorApp('La carpeta ya no existe.');
    final lista = <Entrada>[];
    await for (final e in dir.list(followLinks: false)) {
      if (p.basename(e.path).startsWith('.')) continue; // archivos internos ocultos
      try {
        lista.add(await entradaLocal(e));
      } catch (_) {
        // Se omite un elemento ilegible sin interrumpir el listado.
      }
    }
    return _ordenar(lista);
  }

  /// Devuelve un File legible con dart:io. Para SAF copia el documento a la caché.
  static Future<File> archivoLegible(Entrada e) async {
    if (e.esCarpeta) throw const ErrorApp('Es una carpeta, no un archivo.');
    if (e.origen == Origen.saf) return File(await SafAndroid.copiarACache(e));
    final f = File(e.id);
    if (!await f.exists()) {
      throw const ErrorApp('El archivo ya no existe. Pudo haberse movido o eliminado.');
    }
    return f;
  }

  /// Metadatos actualizados de una entrada.
  static Future<Entrada> actualizar(Entrada e) async {
    if (e.origen == Origen.saf) return SafAndroid.info(e);
    return entradaLocal(e.esCarpeta ? Directory(e.id) : File(e.id));
  }

  // ------------------------------------------------------------------ validaciones

  static void validarNombre(String nombre) {
    final n = nombre.trim();
    if (n.isEmpty) throw const ErrorApp('El nombre no puede estar vacío.');
    if (n == '.' || n == '..') throw const ErrorApp('Nombre no válido.');
    if (RegExp(r'[/\\:*?"<>|\x00]').hasMatch(n)) {
      throw const ErrorApp('El nombre no puede contener / \\ : * ? " < > |');
    }
    if (n.length > 255) throw const ErrorApp('El nombre es demasiado largo.');
  }

  static Future<bool> _existe(String ruta) async =>
      await FileSystemEntity.type(ruta, followLinks: false) != FileSystemEntityType.notFound;

  /// Si ya existe "nombre", genera "nombre (1)", "nombre (2)", ...
  static Future<String> _rutaLibre(String carpeta, String nombre) async {
    var ruta = p.join(carpeta, nombre);
    final base = p.basenameWithoutExtension(nombre);
    final ext = p.extension(nombre);
    var i = 1;
    while (await _existe(ruta)) {
      ruta = p.join(carpeta, '$base ($i)$ext');
      i++;
    }
    return ruta;
  }

  static Future<int> _tamanoCarpeta(Directory d) async {
    var total = 0;
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  static Future<void> _verificarEspacio(int necesario, String destino) async {
    final libre = await SafAndroid.espacioLibre(destino);
    if (libre != null && necesario > libre) {
      throw ErrorApp('Almacenamiento insuficiente: se necesitan ${tamanoLegible(necesario)} '
          'y solo hay ${tamanoLegible(libre)} libres.');
    }
  }

  static void _validarDestino(Entrada e, Entrada destino) {
    if (!destino.esCarpeta) throw const ErrorApp('El destino debe ser una carpeta.');
    if (e.origen != destino.origen) {
      throw const ErrorApp('Usa "Importar a la app" o "Exportar" para pasar archivos '
          'entre el almacenamiento de la app y carpetas externas.');
    }
    if (destino.origen == Origen.saf && !destino.puedeCrear) {
      throw const ErrorApp('Operación no permitida: la carpeta destino no admite escritura.');
    }
  }

  // ------------------------------------------------------------------ escritura

  static Future<Entrada> renombrar(Entrada e, String nuevo) async {
    validarNombre(nuevo);
    nuevo = nuevo.trim();
    if (e.origen == Origen.saf) {
      if (!e.puedeRenombrar) throw const ErrorApp('El proveedor no permite renombrar este elemento.');
      return SafAndroid.renombrar(e, nuevo);
    }
    final destino = p.join(p.dirname(e.id), nuevo);
    if (await _existe(destino)) throw ErrorApp('Ya existe "$nuevo" en esta carpeta.');
    final FileSystemEntity entidad = e.esCarpeta ? Directory(e.id) : File(e.id);
    return entradaLocal(await entidad.rename(destino));
  }

  static Future<void> eliminar(Entrada e) async {
    if (e.origen == Origen.saf) {
      if (!e.puedeEliminar) throw const ErrorApp('El proveedor no permite eliminar este elemento.');
      await SafAndroid.eliminar(e);
      return;
    }
    final FileSystemEntity entidad = e.esCarpeta ? Directory(e.id) : File(e.id);
    if (!await entidad.exists()) throw const ErrorApp('El elemento ya no existe.');
    await entidad.delete(recursive: true);
  }

  static Future<void> copiar(Entrada e, Entrada destino) async {
    _validarDestino(e, destino);
    if (e.origen == Origen.saf) {
      await SafAndroid.copiar(e, destino);
      return;
    }
    if (!await Directory(destino.id).exists()) throw const ErrorApp('La carpeta destino no existe.');
    if (e.esCarpeta && (p.equals(e.id, destino.id) || p.isWithin(e.id, destino.id))) {
      throw const ErrorApp('No puedes copiar una carpeta dentro de sí misma.');
    }
    final tamano = e.esCarpeta ? await _tamanoCarpeta(Directory(e.id)) : await File(e.id).length();
    await _verificarEspacio(tamano, destino.id);
    final ruta = await _rutaLibre(destino.id, e.nombre);
    if (e.esCarpeta) {
      await _copiarCarpeta(Directory(e.id), Directory(ruta));
    } else {
      await File(e.id).copy(ruta);
    }
  }

  static Future<void> _copiarCarpeta(Directory origen, Directory destino) async {
    await destino.create(recursive: true);
    await for (final e in origen.list(followLinks: false)) {
      final nuevo = p.join(destino.path, p.basename(e.path));
      if (e is Directory) {
        await _copiarCarpeta(e, Directory(nuevo));
      } else if (e is File) {
        await e.copy(nuevo);
      }
    }
  }

  static Future<void> mover(Entrada e, Entrada padreActual, Entrada destino) async {
    _validarDestino(e, destino);
    if (e.origen == Origen.saf) {
      if (!e.puedeEliminar) {
        throw const ErrorApp('No se puede mover: el proveedor no permite quitar el original.');
      }
      await SafAndroid.mover(e, padreActual, destino);
      return;
    }
    if (p.equals(p.dirname(e.id), destino.id)) throw const ErrorApp('El elemento ya está en esa carpeta.');
    if (e.esCarpeta && (p.equals(e.id, destino.id) || p.isWithin(e.id, destino.id))) {
      throw const ErrorApp('No puedes mover una carpeta dentro de sí misma.');
    }
    final ruta = await _rutaLibre(destino.id, e.nombre);
    final FileSystemEntity entidad = e.esCarpeta ? Directory(e.id) : File(e.id);
    await entidad.rename(ruta);
  }

  static Future<void> crearCarpeta(Entrada padre, String nombre) async {
    validarNombre(nombre);
    if (padre.origen == Origen.saf) {
      if (!padre.puedeCrear) throw const ErrorApp('Operación no permitida en esta carpeta.');
      await SafAndroid.crearCarpeta(padre, nombre.trim());
      return;
    }
    final ruta = p.join(padre.id, nombre.trim());
    if (await _existe(ruta)) throw ErrorApp('Ya existe "$nombre".');
    await Directory(ruta).create();
  }

  static Future<void> crearArchivoTexto(Entrada padre, String nombre, String texto) async {
    validarNombre(nombre);
    var n = nombre.trim();
    if (p.extension(n).isEmpty) n = '$n.txt';
    if (padre.origen == Origen.saf) {
      if (!padre.puedeCrear) throw const ErrorApp('Operación no permitida en esta carpeta.');
      await SafAndroid.crearArchivo(padre, n, texto);
      return;
    }
    final ruta = p.join(padre.id, n);
    if (await _existe(ruta)) throw ErrorApp('Ya existe "$n".');
    await _verificarEspacio(utf8.encode(texto).length, padre.id);
    await File(ruta).writeAsString(texto, flush: true);
  }

  /// Copia un documento externo (SAF) al almacenamiento privado de la app.
  static Future<String> importar(Entrada e) async {
    if (e.esCarpeta) throw const ErrorApp('Solo se pueden importar archivos.');
    final temporal = await archivoLegible(e);
    await _verificarEspacio(await temporal.length(), raizLocal.path);
    final ruta = await _rutaLibre(raizLocal.path, e.nombre);
    await temporal.copy(ruta);
    return p.basename(ruta);
  }

  // ------------------------------------------------------------------ caché

  static Future<Directory> carpetaCacheSaf() async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'saf'));

  static Future<int> tamanoCache() async {
    final d = await carpetaCacheSaf();
    return await d.exists() ? _tamanoCarpeta(d) : 0;
  }

  static Future<void> limpiarCache() async {
    final d = await carpetaCacheSaf();
    if (await d.exists()) await d.delete(recursive: true);
  }
}
