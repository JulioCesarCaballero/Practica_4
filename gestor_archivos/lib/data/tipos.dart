import 'package:flutter/material.dart';

import 'entrada.dart';

/// Cómo se debe visualizar un archivo.
enum TipoVista { texto, json, xml, imagen, noSoportado }

const _texto = {
  'txt', 'md', 'markdown', 'csv', 'log', 'ini', 'cfg', 'conf', 'yaml', 'yml',
  'properties', 'dart', 'kt', 'java', 'py', 'js', 'ts', 'c', 'cpp', 'h', 'css',
  'html', 'htm', 'sh', 'sql', 'gradle', 'toml',
};
const _imagen = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

TipoVista tipoDe(Entrada e) {
  final ext = e.extension;
  if (ext == 'json') return TipoVista.json;
  if (ext == 'xml' || ext == 'svg' || ext == 'plist') return TipoVista.xml;
  if (_imagen.contains(ext)) return TipoVista.imagen;
  if (_texto.contains(ext)) return TipoVista.texto;
  final mime = e.mime ?? '';
  if (mime == 'application/json') return TipoVista.json;
  if (mime.endsWith('/xml')) return TipoVista.xml;
  if (mime.startsWith('image/') && mime != 'image/heic') return TipoVista.imagen;
  if (mime.startsWith('text/')) return TipoVista.texto;
  return TipoVista.noSoportado;
}

IconData iconoDe(Entrada e) {
  if (e.esCarpeta) return Icons.folder;
  switch (tipoDe(e)) {
    case TipoVista.texto:
      return e.extension == 'md' ? Icons.article : Icons.description;
    case TipoVista.json:
      return Icons.data_object;
    case TipoVista.xml:
      return Icons.code;
    case TipoVista.imagen:
      return Icons.image;
    case TipoVista.noSoportado:
      final mime = e.mime ?? '';
      if (mime.startsWith('audio/')) return Icons.audiotrack;
      if (mime.startsWith('video/')) return Icons.movie;
      if (mime == 'application/pdf') return Icons.picture_as_pdf;
      return Icons.insert_drive_file;
  }
}
