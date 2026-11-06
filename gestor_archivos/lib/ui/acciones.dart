import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../core/errores.dart';
import '../core/formato.dart';
import '../data/archivos.dart';
import '../data/entrada.dart';
import '../platform/saf_android.dart';

/// Acciones comunes sobre un archivo, reutilizadas por el explorador y el visor.

void mostrarMensaje(BuildContext context, String texto, {bool error = false, SnackBarAction? accion}) {
  final esquema = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto, style: error ? TextStyle(color: esquema.onErrorContainer) : null),
      backgroundColor: error ? esquema.errorContainer : null,
      action: accion,
      duration: Duration(seconds: error ? 5 : 3),
    ));
}

/// Ejecuta una operación mostrando un indicador de progreso y el resultado.
/// Devuelve true si terminó bien. Nunca deja que una excepción cierre la app.
Future<bool> ejecutarConProgreso(
  BuildContext context,
  Future<void> Function() operacion, {
  String? exito,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  Object? error;
  try {
    await operacion();
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return error == null;
  Navigator.of(context, rootNavigator: true).pop();
  if (error != null) {
    mostrarMensaje(context, mensajeError(error), error: true);
    return false;
  }
  if (exito != null) mostrarMensaje(context, exito);
  return true;
}

Future<void> compartirArchivo(BuildContext context, Entrada e) async {
  try {
    if (e.origen == Origen.saf) {
      await SafAndroid.compartir(e);
    } else {
      await Share.shareXFiles([XFile(e.id, mimeType: e.mime)], subject: e.nombre);
    }
  } catch (err) {
    if (context.mounted) mostrarMensaje(context, mensajeError(err), error: true);
  }
}

Future<void> abrirConOtraApp(BuildContext context, Entrada e) async {
  try {
    if (e.origen == Origen.saf) {
      await SafAndroid.abrirCon(e);
      return;
    }
    final r = await OpenFilex.open(e.id, type: e.mime);
    if (r.type != ResultType.done && context.mounted) {
      final texto = r.type == ResultType.noAppToOpen
          ? 'No hay ninguna app instalada que pueda abrir este tipo de archivo.'
          : 'No se pudo abrir: ${r.message}';
      mostrarMensaje(context, texto, error: true);
    }
  } catch (err) {
    if (context.mounted) mostrarMensaje(context, mensajeError(err), error: true);
  }
}

/// Exporta una copia a una ubicación elegida por el usuario (ACTION_CREATE_DOCUMENT).
Future<void> exportarArchivo(BuildContext context, Entrada e) async {
  try {
    final local = await Archivos.archivoLegible(e);
    final uri = await SafAndroid.exportar(local.path, e.nombre, e.mime);
    if (!context.mounted) return;
    mostrarMensaje(context, uri == null ? 'Exportación cancelada.' : 'Archivo exportado correctamente.');
  } catch (err) {
    if (context.mounted) mostrarMensaje(context, mensajeError(err), error: true);
  }
}

/// Diálogo para formatos que la app no puede mostrar.
Future<void> dialogoNoSoportado(BuildContext context, Entrada e) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.help_outline),
      title: const Text('Formato no soportado'),
      content: Text('La app no puede mostrar "${e.nombre}" '
          '(${e.mime ?? 'tipo desconocido'}).\n\n¿Qué quieres hacer?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            exportarArchivo(context, e);
          },
          child: const Text('Exportar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            compartirArchivo(context, e);
          },
          child: const Text('Compartir'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            abrirConOtraApp(context, e);
          },
          child: const Text('Abrir con…'),
        ),
      ],
    ),
  );
}

/// Hoja inferior con los metadatos disponibles.
Future<void> mostrarDetalles(BuildContext context, Entrada original) async {
  Entrada e = original;
  try {
    e = await Archivos.actualizar(original);
  } catch (_) {
    // Se muestran los datos que ya se tenían.
  }
  if (!context.mounted) return;
  String si(bool v) => v ? 'Sí' : 'No';
  final filas = <(String, String)>[
    ('Nombre', e.nombre),
    ('Tipo', e.esCarpeta ? 'Carpeta' : (e.mime ?? 'No disponible (tipo desconocido)')),
    if (!e.esCarpeta) ('Tamaño', e.tamano == null ? 'No disponible' : '${tamanoLegible(e.tamano)} (${e.tamano} bytes)'),
    ('Modificado', fechaLegible(e.modificado)),
    ('Creado', e.creado == null ? 'No disponible (el sistema no expone este dato)' : fechaLegible(e.creado)),
    ('Origen', e.origen == Origen.local ? 'Almacenamiento privado de la app' : (Platform.isIOS ? 'Documento autorizado (selector de Archivos)' : 'Documento autorizado (SAF)')),
    ('Ubicación', e.id),
    if (e.origen == Origen.saf) ...[
      ('Escritura', si(e.puedeEscribir || e.puedeCrear)),
      ('Renombrar', si(e.puedeRenombrar)),
      ('Eliminar', si(e.puedeEliminar)),
    ],
  ];
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalles', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final (etiqueta, valor) in filas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: SelectableText(valor)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Diálogo genérico para pedir un texto (nombre de archivo, etc.).
Future<String?> pedirTexto(BuildContext context, String titulo,
    {String inicial = '', String etiqueta = 'Nombre', int lineas = 1}) {
  final c = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: lineas,
        decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
        onSubmitted: lineas == 1 ? (v) => Navigator.pop(ctx, v) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Aceptar')),
      ],
    ),
  );
}

Future<bool> confirmar(BuildContext context, String titulo, String mensaje, {String accion = 'Eliminar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return r ?? false;
}
