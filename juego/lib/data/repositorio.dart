import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'modelo.dart';
import 'serializacion.dart';

/// Resumen de un archivo de partida para la lista de partidas guardadas.
/// Si el archivo está dañado, [partida] es null y [error] explica el problema.
class ResumenPartida {
  ResumenPartida({
    required this.archivo,
    required this.formato,
    required this.tamano,
    required this.modificado,
    this.partida,
    this.error,
  });

  final File archivo;
  final FormatoGuardado formato;
  final int tamano;
  final DateTime modificado;
  final Partida? partida;
  final String? error;

  bool get valida => partida != null;
  String get nombreArchivo => p.basename(archivo.path);
}

/// Guarda y carga partidas en el almacenamiento PRIVADO de la app
/// (getApplicationDocumentsDirectory → /data/data/<paquete>/app_flutter en Android).
class Repositorio {
  static late Directory carpeta;
  static late File _autoguardado;

  static Future<void> inicializar() async {
    final docs = await getApplicationDocumentsDirectory();
    carpeta = Directory(p.join(docs.path, 'partidas'));
    await carpeta.create(recursive: true);
    _autoguardado = File(p.join(docs.path, 'autoguardado.json'));
  }

  /// Escritura atómica: primero a un .tmp y luego se renombra.
  /// Si la app se cierra a la mitad, el archivo anterior sigue intacto.
  static Future<void> _escribirSeguro(File destino, String contenido) async {
    final tmp = File('${destino.path}.tmp');
    await tmp.writeAsString(contenido, flush: true);
    await tmp.rename(destino.path);
  }

  static File archivoDe(Partida partida, FormatoGuardado f) =>
      File(p.join(carpeta.path, '${partida.id}.${f.extension}'));

  /// Guarda la partida en el formato indicado. Si la misma partida existía en
  /// otro formato, se reemplaza para no tener duplicados del mismo espacio.
  static Future<File> guardar(Partida partida, FormatoGuardado formato) async {
    partida.guardada = DateTime.now();
    final destino = archivoDe(partida, formato);
    await _escribirSeguro(destino, Serializador.serializar(partida, formato));
    for (final otro in FormatoGuardado.values) {
      if (otro == formato) continue;
      final viejo = archivoDe(partida, otro);
      if (await viejo.exists()) await viejo.delete();
    }
    return destino;
  }

  static Future<Partida> cargar(File archivo) async {
    final formato = FormatoGuardado.desdeExtension(p.extension(archivo.path));
    if (formato == null) throw const FormatException('Extensión no soportada (usa .txt, .xml o .json)');
    if (!await archivo.exists()) throw const FormatException('El archivo ya no existe');
    final bytes = await archivo.readAsBytes();
    final texto = utf8.decode(bytes, allowMalformed: true);
    return Serializador.deserializar(texto, formato);
  }

  /// Lista todas las partidas. Un archivo dañado no impide ver las demás.
  static Future<List<ResumenPartida>> listar() async {
    final lista = <ResumenPartida>[];
    if (!await carpeta.exists()) return lista;
    await for (final e in carpeta.list()) {
      if (e is! File) continue;
      final formato = FormatoGuardado.desdeExtension(p.extension(e.path));
      if (formato == null) continue;
      FileStat st;
      try {
        st = await e.stat();
      } catch (_) {
        continue;
      }
      try {
        final partida = await cargar(e);
        lista.add(ResumenPartida(
            archivo: e, formato: formato, tamano: st.size, modificado: st.modified, partida: partida));
      } on FormatException catch (err) {
        lista.add(ResumenPartida(
            archivo: e, formato: formato, tamano: st.size, modificado: st.modified, error: err.message));
      } catch (err) {
        lista.add(ResumenPartida(
            archivo: e, formato: formato, tamano: st.size, modificado: st.modified, error: '$err'));
      }
    }
    lista.sort((a, b) => b.modificado.compareTo(a.modificado));
    return lista;
  }

  static Future<void> eliminar(File archivo) async {
    if (await archivo.exists()) await archivo.delete();
  }

  static Future<void> cambiarEtiqueta(ResumenPartida r, String etiqueta) async {
    final partida = r.partida;
    if (partida == null) throw const FormatException('La partida está dañada');
    partida.etiqueta = etiqueta.trim();
    await _escribirSeguro(r.archivo, Serializador.serializar(partida, r.formato));
  }

  // ------------------------------------------------------------------ autoguardado

  static Future<void> autoguardar(Partida partida) async {
    try {
      await _escribirSeguro(_autoguardado, Serializador.aJson(partida));
    } catch (_) {
      // Un fallo de autoguardado nunca debe interrumpir el juego.
    }
  }

  /// Devuelve la partida en curso guardada automáticamente, o null.
  /// Si el autoguardado está dañado se descarta sin afectar las demás partidas.
  static Future<Partida?> leerAutoguardado() async {
    try {
      if (!await _autoguardado.exists()) return null;
      final partida = Serializador.deserializar(await _autoguardado.readAsString(), FormatoGuardado.json);
      return partida.terminada ? null : partida;
    } catch (_) {
      await borrarAutoguardado();
      return null;
    }
  }

  static Future<void> borrarAutoguardado() async {
    try {
      if (await _autoguardado.exists()) await _autoguardado.delete();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ pruebas

  /// Crea archivos dañados a propósito para demostrar la validación.
  static Future<void> crearArchivosDanados() async {
    await File(p.join(carpeta.path, 'prueba_vacia.json')).writeAsString('');
    await File(p.join(carpeta.path, 'prueba_incompleta.txt')).writeAsString(
      '# Partida de Memoria ESCOM\nformato=memoria-escom\nid=xyz\nnivel=1\n',
    );
    await File(p.join(carpeta.path, 'prueba_corrupta.xml'))
        .writeAsString('<?xml version="1.0"?><partida formato="memoria-escom"><id>abc</id><tablero>1,2');
  }
}
