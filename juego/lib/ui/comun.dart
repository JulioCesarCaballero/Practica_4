import 'package:flutter/material.dart';

import '../data/ajustes.dart';
import '../data/serializacion.dart';

const etiquetasSugeridas = ['Favorita', 'Práctica', 'Difícil', 'Récord', 'Pendiente'];

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  final esquema = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto, style: error ? TextStyle(color: esquema.onErrorContainer) : null),
      backgroundColor: error ? esquema.errorContainer : null,
    ));
}

/// Datos del diálogo "Guardar como".
class DatosGuardado {
  DatosGuardado(this.nombre, this.etiqueta, this.formato);
  final String nombre;
  final String etiqueta;
  final FormatoGuardado formato;
}

/// Diálogo para elegir nombre, etiqueta y formato (TXT / XML / JSON).
Future<DatosGuardado?> dialogoGuardarComo(BuildContext context, {required String nombre, String etiqueta = ''}) {
  final cNombre = TextEditingController(text: nombre);
  final cEtiqueta = TextEditingController(text: etiqueta);
  var formato = ajustes.formato;
  return showDialog<DatosGuardado>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Guardar partida'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: cNombre,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cEtiqueta,
              decoration: const InputDecoration(labelText: 'Etiqueta / categoría', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final e in etiquetasSugeridas)
                ActionChip(label: Text(e), onPressed: () => setLocal(() => cEtiqueta.text = e)),
            ]),
            const SizedBox(height: 16),
            const Text('Formato del archivo'),
            const SizedBox(height: 8),
            SegmentedButton<FormatoGuardado>(
              segments: [
                for (final f in FormatoGuardado.values)
                  ButtonSegment(value: f, label: Text('.${f.extension}')),
              ],
              selected: {formato},
              onSelectionChanged: (s) => setLocal(() => formato = s.first),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final n = cNombre.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, DatosGuardado(n, cEtiqueta.text.trim(), formato));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
