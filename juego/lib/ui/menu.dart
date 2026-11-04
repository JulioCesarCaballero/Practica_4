import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../data/ajustes.dart';
import '../data/modelo.dart';
import '../data/repositorio.dart';
import 'opciones.dart';
import 'pantalla_juego.dart';
import 'partidas.dart';

/// Menú principal.
class PantallaMenu extends StatefulWidget {
  const PantallaMenu({super.key});

  @override
  State<PantallaMenu> createState() => _PantallaMenuState();
}

class _PantallaMenuState extends State<PantallaMenu> {
  Partida? _enCurso;

  @override
  void initState() {
    super.initState();
    _buscarAutoguardado();
  }

  Future<void> _buscarAutoguardado() async {
    final p = await Repositorio.leerAutoguardado();
    if (mounted) setState(() => _enCurso = p);
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    _buscarAutoguardado();
  }

  Future<void> _nueva() async {
    final nivel = await showModalBottomSheet<Nivel>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Elige un modo de juego')),
          for (final n in Nivel.values)
            ListTile(
              leading: CircleAvatar(child: Text('${n.numero}')),
              title: Text(n.nombre),
              subtitle: Text(n.descripcion),
              onTap: () => Navigator.pop(ctx, n),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (nivel == null || !mounted) return;
    await _ir(PantallaJuego(partida: Partida.nueva(nivel, ajustes.configuracion)));
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final enCurso = _enCurso;
    final botones = <Widget>[
      if (enCurso != null)
        FilledButton.icon(
          onPressed: () => _ir(PantallaJuego(partida: enCurso)),
          icon: const Icon(Icons.play_circle),
          label: Text('Continuar (${enCurso.nivel.nombre} · ${enCurso.puntuacion} pts · '
              '${tiempoLegible(enCurso.segundos)})'),
        ),
      FilledButton.tonalIcon(onPressed: _nueva, icon: const Icon(Icons.add), label: const Text('Nueva partida')),
      FilledButton.tonalIcon(
        onPressed: () => _ir(const PantallaPartidas()),
        icon: const Icon(Icons.folder_open),
        label: const Text('Partidas guardadas'),
      ),
      OutlinedButton.icon(
        onPressed: () => _ir(const PantallaOpciones()),
        icon: const Icon(Icons.settings),
        label: const Text('Opciones'),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [esquema.primaryContainer, esquema.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, r) {
            final horizontal = r.maxWidth > r.maxHeight;
            final titulo = Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.memory, size: horizontal ? 72 : 96, color: esquema.primary),
              const SizedBox(height: 8),
              Text('Memoria ESCOM', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text('Encuentra los pares antes que nadie', style: t.bodyMedium),
            ]);
            final columna = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final b in botones) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: b),
                ],
              ),
            );
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: horizontal
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        titulo,
                        const SizedBox(width: 48),
                        Flexible(child: columna),
                      ])
                    : Column(children: [titulo, const SizedBox(height: 32), columna]),
              ),
            );
          }),
        ),
      ),
    );
  }
}
