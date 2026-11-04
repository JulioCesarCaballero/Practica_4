import 'package:flutter/services.dart';

/// Puente con MainActivity.kt: exporta un archivo a la ubicación que el
/// usuario elija con el selector de Android (ACTION_CREATE_DOCUMENT / SAF).
class ExportarAndroid {
  static const _canal = MethodChannel('mx.ipn.escom/archivos');

  /// Devuelve la URI creada, o null si el usuario canceló.
  static Future<String?> exportar(String ruta, String nombre, String mime) =>
      _canal.invokeMethod<String>('exportar', {'ruta': ruta, 'nombre': nombre, 'mime': mime});
}
