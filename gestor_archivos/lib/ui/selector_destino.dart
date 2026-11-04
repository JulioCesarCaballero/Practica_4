import 'package:flutter/material.dart';

import '../core/errores.dart';
import '../data/archivos.dart';
import '../data/entrada.dart';

/// Diálogo para elegir la carpeta destino de copiar / mover.
/// Navega solo dentro de la misma ubicación (app o carpeta autorizada).
Future<Entrada?> elegirDestino(BuildContext context, List<Entrada> rutaInicial, String titulo) {
  return showDialog<Entrada>(
    context: context,
    builder: (_) => _SelectorDestino(rutaInicial: rutaInicial, titulo: titulo),
  );
}

class _SelectorDestino extends StatefulWidget {
  const _SelectorDestino({required this.rutaInicial, required this.titulo});

  final List<Entrada> rutaInicial;
  final String titulo;

  @override
  State<_SelectorDestino> createState() => _SelectorDestinoState();
}

class _SelectorDestinoState extends State<_SelectorDestino> {
  late final List<Entrada> _ruta = List.of(widget.rutaInicial);
  late Future<List<Entrada>> _carpetas = _cargar();

  Future<List<Entrada>> _cargar() async =>
      (await Archivos.listar(_ruta.last)).where((e) => e.esCarpeta).toList();

  void _ir(void Function() cambio) => setState(() {
        cambio();
        _carpetas = _cargar();
      });

  @override
  Widget build(BuildContext context) {
    final actual = _ruta.last;
    return AlertDialog(
      title: Text(widget.titulo),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(children: [
          ListTile(
            dense: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: 'Subir',
              onPressed: _ruta.length > 1 ? () => _ir(() => _ruta.removeLast()) : null,
            ),
            title: Text(_ruta.map((e) => e.nombre).join(' › '), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Entrada>>(
              future: _carpetas,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) return Center(child: Text(mensajeError(s.error!), textAlign: TextAlign.center));
                final lista = s.data!;
                if (lista.isEmpty) return const Center(child: Text('Sin subcarpetas'));
                return ListView(
                  children: [
                    for (final c in lista)
                      ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(c.nombre),
                        onTap: () => _ir(() => _ruta.add(c)),
                      ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: (actual.origen == Origen.saf && !actual.puedeCrear)
              ? null
              : () => Navigator.pop(context, actual),
          child: const Text('Elegir esta carpeta'),
        ),
      ],
    );
  }
}
