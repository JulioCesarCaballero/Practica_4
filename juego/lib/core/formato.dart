import 'package:flutter/services.dart';

String tamanoLegible(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaLegible(DateTime f) {
  final l = f.toLocal();
  return '${_dos(l.day)}/${_dos(l.month)}/${l.year} ${_dos(l.hour)}:${_dos(l.minute)}';
}

String tiempoLegible(int segundos) => '${_dos(segundos ~/ 60)}:${_dos(segundos % 60)}';

/// Mensaje legible para errores de archivos y del canal de Android.
String mensajeError(Object e) {
  if (e is FormatException) return e.message;
  if (e is PlatformException) {
    if (e.code == 'PERMISO') return 'Permiso denegado para escribir en ese destino.';
    return e.message ?? e.code;
  }
  if (e is MissingPluginException) return 'Esta función no está disponible en esta plataforma.';
  final t = e.toString();
  if (t.contains('No space left') || t.contains('errno = 28')) return 'Almacenamiento insuficiente.';
  return 'Error: $t';
}
