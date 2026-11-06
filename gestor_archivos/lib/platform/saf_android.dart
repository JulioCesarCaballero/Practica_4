import 'dart:io';

import 'package:flutter/services.dart';

import '../data/entrada.dart';

/// Puente con el código nativo que implementa el acceso a archivos autorizados:
///  - Android: MainActivity.kt (Storage Access Framework).
///  - iOS: ios/Runner/SafPlugin.swift (UIDocumentPickerViewController + security-scoped bookmarks).
///
/// Es la única parte de la app que depende de la plataforma. Si en otra
/// plataforma no existe el canal, las llamadas lanzan MissingPluginException,
/// que `mensajeError` traduce a un aviso legible.
class SafAndroid {
  static const MethodChannel _canal = MethodChannel('mx.ipn.escom/saf');

  static bool get disponible => Platform.isAndroid || Platform.isIOS;

  static Map<String, dynamic>? _mapa(Object? valor) =>
      valor == null ? null : Map<String, dynamic>.from(valor as Map);

  /// Abre el selector de carpetas. Devuelve null si el usuario cancela.
  static Future<Entrada?> elegirCarpeta() async {
    final m = _mapa(await _canal.invokeMethod('elegirCarpeta'));
    return m == null ? null : Entrada.desdeSaf(m);
  }

  /// Abre el selector de archivos. Devuelve null si el usuario cancela.
  static Future<Entrada?> elegirArchivo() async {
    final m = _mapa(await _canal.invokeMethod('elegirArchivo'));
    return m == null ? null : Entrada.desdeSaf(m);
  }

  /// Pide al usuario un destino (ACTION_CREATE_DOCUMENT) y copia ahí el archivo local.
  /// Devuelve la URI creada o null si canceló.
  static Future<String?> exportar(String rutaLocal, String nombre, String? mime) =>
      _canal.invokeMethod<String>('exportar', {'ruta': rutaLocal, 'nombre': nombre, 'mime': mime});

  static Future<List<Entrada>> carpetasAutorizadas() async {
    if (!disponible) return [];
    final lista = await _canal.invokeListMethod<dynamic>('carpetasAutorizadas') ?? [];
    return lista.map((e) => Entrada.desdeSaf(e as Map)).toList();
  }

  static Future<void> quitarAcceso(Entrada raiz) =>
      _canal.invokeMethod('quitarAcceso', {'uri': raiz.id});

  static Future<Entrada> info(Entrada e) async =>
      Entrada.desdeSaf(_mapa(await _canal.invokeMethod('info', {'uri': e.id, 'raiz': e.raiz}))!);

  static Future<List<Entrada>> listar(Entrada carpeta) async {
    final lista = await _canal.invokeListMethod<dynamic>(
          'listar',
          {'uri': carpeta.id, 'raiz': carpeta.raiz},
        ) ??
        [];
    return lista.map((e) => Entrada.desdeSaf(e as Map)).toList();
  }

  /// Copia el documento a la caché privada para poder leerlo con dart:io.
  static Future<String> copiarACache(Entrada e) async =>
      (await _canal.invokeMethod<String>('copiarACache', {'uri': e.id, 'nombre': e.nombre}))!;

  static Future<Entrada> renombrar(Entrada e, String nombre) async => Entrada.desdeSaf(
      _mapa(await _canal.invokeMethod('renombrar', {'uri': e.id, 'raiz': e.raiz, 'nombre': nombre}))!);

  static Future<void> eliminar(Entrada e) => _canal.invokeMethod('eliminar', {'uri': e.id});

  static Future<Entrada> copiar(Entrada e, Entrada destino) async => Entrada.desdeSaf(_mapa(
      await _canal.invokeMethod('copiar', {'uri': e.id, 'destino': destino.id, 'raiz': destino.raiz}))!);

  static Future<Entrada> mover(Entrada e, Entrada padre, Entrada destino) async =>
      Entrada.desdeSaf(_mapa(await _canal.invokeMethod('mover', {
        'uri': e.id,
        'padre': padre.id,
        'destino': destino.id,
        'raiz': destino.raiz,
      }))!);

  static Future<Entrada> crearCarpeta(Entrada padre, String nombre) async => Entrada.desdeSaf(_mapa(
      await _canal.invokeMethod('crearCarpeta', {'uri': padre.id, 'raiz': padre.raiz, 'nombre': nombre}))!);

  static Future<Entrada> crearArchivo(Entrada padre, String nombre, String texto) async =>
      Entrada.desdeSaf(_mapa(await _canal.invokeMethod('crearArchivo', {
        'uri': padre.id,
        'raiz': padre.raiz,
        'nombre': nombre,
        'mime': 'text/plain',
        'texto': texto,
      }))!);

  static Future<void> abrirCon(Entrada e) =>
      _canal.invokeMethod('abrirCon', {'uri': e.id, 'mime': e.mime});

  static Future<void> compartir(Entrada e) =>
      _canal.invokeMethod('compartir', {'uri': e.id, 'mime': e.mime});

  /// Bytes libres en el volumen de la ruta indicada (null si no se puede saber).
  static Future<int?> espacioLibre(String ruta) async {
    if (!disponible) return null;
    try {
      return await _canal.invokeMethod<int>('espacioLibre', {'ruta': ruta});
    } catch (_) {
      return null;
    }
  }
}
