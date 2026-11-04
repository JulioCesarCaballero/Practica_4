import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/formato.dart';
import '../data/repositorio.dart';
import '../platform/exportar_android.dart';
import 'comun.dart';
import 'pantalla_juego.dart';
import 'ver_archivo.dart';

enum _Op { cargar, ver, etiqueta, compartir, exportar, eliminar }

/// Lista de partidas guardadas con metadatos, filtro por etiqueta,
/// visualización del archivo, exportación y eliminación.
class PantallaPartidas extends StatefulWidget {
  const PantallaPartidas({super.key});

  @override
  State<PantallaPartidas> createState() => _PantallaPartidasState();
}

class _PantallaPartidasState extends State<PantallaPartidas> {
  late Future<List<ResumenPartida>> _futuro = Repositorio.listar();
  String? _filtro; // null = todas

  void _recargar() => setState(() => _futuro = Repositorio.listar());

  Future<void> _operacion(_Op op, ResumenPartida r) async {
    switch (op) {
      case _Op.cargar:
        await _cargar(r);
      case _Op.ver:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaVerArchivo(resumen: r)));
      case _Op.etiqueta:
        await _cambiarEtiqueta(r);
      case _Op.compartir:
        try {
          await Share.shareXFiles([XFile(r.archivo.path, mimeType: r.formato.mime)],
              subject: 'Partida de Memoria ESCOM');
        } catch (e) {
          if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
        }
      case _Op.exportar:
        try {
          final uri = await ExportarAndroid.exportar(r.archivo.path, r.nombreArchivo, r.formato.mime);
          if (mounted) mostrarMensaje(context, uri == null ? 'Exportación cancelada.' : 'Partida exportada.');
        } catch (e) {
          if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
        }
      case _Op.eliminar:
        await _eliminar(r);
    }
  }

  Future<void> _cargar(ResumenPartida r) async {
    try {
      // Se vuelve a leer del disco para obtener el estado más reciente.
      final partida = await Repositorio.cargar(r.archivo);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PantallaJuego(partida: partida, archivo: r.archivo)),
      );
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo cargar: ${mensajeError(e)}', error: true);
    }
  }

  Future<void> _cambiarEtiqueta(ResumenPartida r) async {
    final c = TextEditingController(text: r.partida?.etiqueta ?? '');
    final nueva = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Etiqueta / categoría'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final e in etiquetasSugeridas) ActionChip(label: Text(e), onPressed: () => Navigator.pop(ctx, e)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Quitar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Aceptar')),
        ],
      ),
    );
    if (nueva == null) return;
    try {
      await Repositorio.cambiarEtiqueta(r, nueva);
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
    }
  }

  Future<void> _eliminar(ResumenPartida r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('¿Eliminar partida?'),
        content: Text('Se borrará "${r.partida?.nombre ?? r.nombreArchivo}". No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Repositorio.eliminar(r.archivo);
      if (mounted) mostrarMensaje(context, 'Partida eliminada.');
      _recargar();
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partidas guardadas'),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _recargar)],
      ),
      body: FutureBuilder<List<ResumenPartida>>(
        future: _futuro,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text(mensajeError(s.error!)));
          final todas = s.data!;
          if (todas.isEmpty) {
            return const Center(child: Text('No hay partidas guardadas.\nJuega y usa el botón Guardar.', textAlign: TextAlign.center));
          }
          final etiquetas = {
            for (final r in todas)
              if (r.partida != null && r.partida!.etiqueta.isNotEmpty) r.partida!.etiqueta
          }.toList()
            ..sort();
          final visibles = _filtro == null
              ? todas
              : todas.where((r) => r.partida?.etiqueta == _filtro).toList();
          final danadas = todas.where((r) => !r.valida).length;
          return Column(children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('Todas (${todas.length})'),
                      selected: _filtro == null,
                      onSelected: (_) => setState(() => _filtro = null),
                    ),
                  ),
                  for (final e in etiquetas)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(e),
                        selected: _filtro == e,
                        onSelected: (_) => setState(() => _filtro = _filtro == e ? null : e),
                      ),
                    ),
                ],
              ),
            ),
            if (danadas > 0)
              MaterialBanner(
                leading: const Icon(Icons.report_problem_outlined),
                content: Text('$danadas archivo(s) dañado(s). Las demás partidas siguen disponibles.'),
                actions: const [SizedBox.shrink()],
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: visibles.length,
                itemBuilder: (context, i) => _tarjeta(visibles[i]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _tarjeta(ResumenPartida r) {
    final esquema = Theme.of(context).colorScheme;
    final p = r.partida;
    final formatoChip = Chip(
      label: Text(r.formato.extension.toUpperCase()),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
    if (p == null) {
      return Card(
        color: esquema.errorContainer,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Icon(Icons.broken_image_outlined, color: esquema.onErrorContainer),
          title: Text(r.nombreArchivo, style: TextStyle(color: esquema.onErrorContainer)),
          subtitle: Text('Archivo dañado: ${r.error}\n${tamanoLegible(r.tamano)} · ${fechaLegible(r.modificado)}',
              style: TextStyle(color: esquema.onErrorContainer)),
          isThreeLine: true,
          trailing: PopupMenuButton<_Op>(
            onSelected: (op) => _operacion(op, r),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Op.ver, child: Text('Ver contenido')),
              PopupMenuItem(value: _Op.eliminar, child: Text('Eliminar')),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _operacion(_Op.cargar, r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: p.terminada ? esquema.tertiaryContainer : esquema.primaryContainer,
              child: Icon(p.terminada ? (p.ganada ? Icons.emoji_events : Icons.timer_off) : Icons.play_arrow),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${p.nivel.nombre} · ${p.puntuacion} pts · ${tiempoLegible(p.segundos)} · '
                    '${p.paresEncontrados}/${p.nivel.pares} pares'),
                Text('${fechaLegible(p.guardada)} · ${tamanoLegible(r.tamano)} · ${p.historial.length} movimientos',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  formatoChip,
                  if (p.etiqueta.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.label_outline, size: 16),
                      label: Text(p.etiqueta),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (p.terminada)
                    Chip(
                      label: Text(p.ganada ? 'Ganada' : 'Perdida'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ]),
              ]),
            ),
            PopupMenuButton<_Op>(
              onSelected: (op) => _operacion(op, r),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Op.cargar, child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Cargar'))),
                PopupMenuItem(value: _Op.ver, child: ListTile(leading: Icon(Icons.description), title: Text('Ver archivo'))),
                PopupMenuItem(value: _Op.etiqueta, child: ListTile(leading: Icon(Icons.label), title: Text('Etiqueta'))),
                PopupMenuItem(value: _Op.compartir, child: ListTile(leading: Icon(Icons.share), title: Text('Compartir'))),
                PopupMenuItem(value: _Op.exportar, child: ListTile(leading: Icon(Icons.save_alt), title: Text('Exportar a…'))),
                PopupMenuItem(value: _Op.eliminar, child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
