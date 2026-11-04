import 'dart:io';

import 'package:flutter/painting.dart';

/// Caché LRU de miniaturas.
///
/// Cada miniatura se decodifica reducida (ResizeImage, 160 px) en lugar de la
/// imagen completa, y se reutiliza mientras el archivo no cambie (la clave
/// incluye la fecha de modificación). Al superar el máximo se libera la más antigua.
class CacheMiniaturas {
  static const maximo = 150;
  static const ancho = 160;
  static final Map<String, ImageProvider> _cache = <String, ImageProvider>{};

  static int get cantidad => _cache.length;

  static ImageProvider obtener(String ruta, DateTime? modificado) {
    final clave = '$ruta|${modificado?.millisecondsSinceEpoch}';
    final existente = _cache.remove(clave);
    if (existente != null) {
      _cache[clave] = existente; // se mueve al final (más reciente)
      return existente;
    }
    final nuevo = ResizeImage(FileImage(File(ruta)), width: ancho);
    _cache[clave] = nuevo;
    if (_cache.length > maximo) {
      final viejo = _cache.remove(_cache.keys.first);
      viejo?.evict();
    }
    return nuevo;
  }

  static void limpiar() {
    for (final img in _cache.values) {
      img.evict();
    }
    _cache.clear();
    PaintingBinding.instance.imageCache.clear();
  }
}
