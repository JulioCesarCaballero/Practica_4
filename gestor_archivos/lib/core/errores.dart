import 'dart:io';

import 'package:flutter/services.dart';

/// Error con un mensaje ya pensado para mostrarse al usuario.
class ErrorApp implements Exception {
  const ErrorApp(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Convierte cualquier excepción en un mensaje legible en español.
/// Así ningún error de E/S bloquea la app: siempre se muestra un aviso.
String mensajeError(Object e) {
  if (e is ErrorApp) return e.mensaje;

  if (e is PlatformException) {
    switch (e.code) {
      case 'PERMISO':
        return 'Permiso denegado o revocado. Vuelve a autorizar la carpeta desde "Ubicaciones".';
      case 'NO_ENCONTRADO':
        return 'El archivo o carpeta ya no existe o no está disponible.';
      case 'NO_SOPORTADO':
        return 'Operación no permitida: ${e.message ?? 'el proveedor de documentos no la admite.'}';
      case 'SIN_ESPACIO':
        return 'Almacenamiento insuficiente para completar la operación.';
      case 'SIN_APP':
        return e.message ?? 'No hay ninguna app instalada que pueda hacer esto.';
      case 'OCUPADO':
        return 'Ya hay un selector abierto.';
      default:
        return 'No se pudo completar la operación: ${e.message ?? e.code}';
    }
  }

  if (e is MissingPluginException) {
    return 'Esta función no está disponible en esta plataforma.';
  }

  if (e is FileSystemException) {
    final codigo = e.osError?.errorCode;
    switch (codigo) {
      case 2: // ENOENT
        return 'El archivo o carpeta ya no existe.';
      case 1: // EPERM
      case 13: // EACCES
        return 'No tienes permiso para acceder a esta ubicación.';
      case 17: // EEXIST
        return 'Ya existe un elemento con ese nombre.';
      case 28: // ENOSPC
        return 'Almacenamiento insuficiente.';
      case 39: // ENOTEMPTY
        return 'La carpeta no está vacía.';
    }
    return 'Error de archivo: ${e.message}${e.path != null ? ' (${e.path})' : ''}';
  }

  if (e is FormatException) {
    return 'Formato inválido: ${e.message}';
  }

  return 'Error inesperado: $e';
}
