import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/efectos.dart';
import '../core/formato.dart';
import '../data/ajustes.dart';
import '../data/modelo.dart';
import '../data/repositorio.dart';
import '../data/serializacion.dart';
import 'comun.dart';

/// Pantalla de juego: Memoria ESCOM.
///
/// Mecánica: voltea dos cartas; si son iguales suman puntos (con bono por racha),
/// si no, se penaliza. El estado se autoguarda periódicamente y al pasar la app
/// a segundo plano, así se recupera aunque se cierre.
class PantallaJuego extends StatefulWidget {
  const PantallaJuego({super.key, required this.partida, this.archivo});

  final Partida partida;

  /// Archivo desde el que se cargó (para "Guardar" sin preguntar).
  final File? archivo;

  @override
  State<PantallaJuego> createState() => _PantallaJuegoState();
}

class _PantallaJuegoState extends State<PantallaJuego> with WidgetsBindingObserver {
  late final Partida p = widget.partida;
  File? _archivo;
  Timer? _reloj;
  int? _primera;
  final Set<int> _visibles = {};
  Set<int> _recienAcertadas = {};
  bool _bloqueado = false;
  bool _pausado = false;
  bool _vistaPrevia = false;

  @override
  void initState() {
    super.initState();
    _archivo = widget.archivo;
    WidgetsBinding.instance.addObserver(this);
    if (p.historial.isEmpty && !p.terminada && p.configuracion.vistaPrevia > 0) {
      _vistaPrevia = true;
      Future.delayed(Duration(seconds: p.configuracion.vistaPrevia), () {
        if (mounted) setState(() => _vistaPrevia = false);
      });
    }
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!p.terminada) Repositorio.autoguardar(p);
    super.dispose();
  }

  /// Persistencia robusta: al salir a segundo plano se guarda el progreso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (!p.terminada) {
        Repositorio.autoguardar(p);
        if (state == AppLifecycleState.paused) setState(() => _pausado = true);
      }
    }
  }

  void _tic() {
    if (_pausado || _vistaPrevia || p.terminada) return;
    setState(() => p.segundos++);
    if (p.segundos % 10 == 0) Repositorio.autoguardar(p);
    final restantes = p.segundosRestantes;
    if (restantes != null && restantes <= 0) _terminar(ganada: false);
  }

  Future<void> _tocar(int i) async {
    if (_bloqueado || _pausado || _vistaPrevia || p.terminada) return;
    if (p.descubiertas[i] || _visibles.contains(i)) return;
    final c = p.configuracion;
    Efectos.vibrar(activo: c.vibracion);
    Efectos.sonar('voltear', activo: c.sonido);
    setState(() => _visibles.add(i));

    if (_primera == null) {
      _primera = i;
      return;
    }
    final a = _primera!;
    final b = i;
    _primera = null;

    if (p.tablero[a] == p.tablero[b]) {
      final puntos = 100 + 20 * p.racha;
      setState(() {
        p.descubiertas[a] = true;
        p.descubiertas[b] = true;
        p.racha++;
        p.puntuacion += puntos;
        _visibles.removeAll([a, b]);
        _recienAcertadas = {a, b};
        p.historial.add(Movimiento(segundo: p.segundos, a: a, b: b, acierto: true, puntos: puntos));
      });
      Efectos.sonar('acierto', activo: c.sonido);
      if (p.descubiertas.every((d) => d)) _terminar(ganada: true);
    } else {
      final penalizacion = min(10, p.puntuacion);
      setState(() {
        _bloqueado = true;
        p.racha = 0;
        p.fallos++;
        p.puntuacion -= penalizacion;
        p.historial.add(Movimiento(segundo: p.segundos, a: a, b: b, acierto: false, puntos: -penalizacion));
      });
      Efectos.sonar('fallo', activo: c.sonido);
      Efectos.vibrar(activo: c.vibracion, fuerte: true);
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() {
        _visibles.removeAll([a, b]);
        _bloqueado = false;
      });
    }
  }

  Future<void> _terminar({required bool ganada}) async {
    if (p.terminada) return;
    var bono = 0;
    setState(() {
      p.terminada = true;
      p.ganada = ganada;
      final restantes = p.segundosRestantes;
      if (ganada && restantes != null) {
        bono = restantes * 5;
        p.puntuacion += bono;
      }
    });
    await Repositorio.borrarAutoguardado();
    if (_archivo != null) await _guardarEnArchivoActual(silencioso: true);
    Efectos.sonar(ganada ? 'victoria' : 'fallo', activo: p.configuracion.sonido);
    if (!mounted) return;
    final accion = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(ganada ? Icons.emoji_events : Icons.timer_off, size: 48),
        title: Text(ganada ? '¡Ganaste!' : 'Se acabó el tiempo'),
        content: Text('Puntuación: ${p.puntuacion}${bono > 0 ? ' (incluye bono de tiempo +$bono)' : ''}\n'
            'Tiempo: ${tiempoLegible(p.segundos)}\n'
            'Pares: ${p.paresEncontrados}/${p.nivel.pares} · Fallos: ${p.fallos}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Menú')),
          TextButton(onPressed: () => Navigator.pop(ctx, 1), child: const Text('Guardar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 2), child: const Text('Otra vez')),
        ],
      ),
    );
    if (!mounted) return;
    switch (accion) {
      case 1:
        await _guardar();
      case 2:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PantallaJuego(partida: Partida.nueva(p.nivel, ajustes.configuracion)),
        ));
      default:
        Navigator.of(context).pop();
    }
  }

  // ------------------------------------------------------------------ guardado

  Future<void> _guardarEnArchivoActual({bool silencioso = false}) async {
    final archivo = _archivo!;
    final formato = FormatoGuardado.desdeExtension(archivo.path.split('.').last) ?? ajustes.formato;
    try {
      _archivo = await Repositorio.guardar(p, formato);
      if (mounted && !silencioso) mostrarMensaje(context, 'Partida guardada (${formato.etiqueta}).');
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo guardar: ${mensajeError(e)}', error: true);
    }
  }

  Future<void> _guardar() async {
    if (_archivo != null) return _guardarEnArchivoActual();
    await _guardarComo(nuevaCopia: false);
  }

  Future<void> _guardarComo({bool nuevaCopia = true}) async {
    final pausadoAntes = _pausado;
    setState(() => _pausado = true);
    final datos = await dialogoGuardarComo(context, nombre: p.nombre, etiqueta: p.etiqueta);
    if (!mounted) return;
    setState(() => _pausado = pausadoAntes);
    if (datos == null) return;
    if (nuevaCopia) p.id = Partida.nuevoId(); // nuevo espacio de guardado
    p.nombre = datos.nombre;
    p.etiqueta = datos.etiqueta;
    try {
      _archivo = await Repositorio.guardar(p, datos.formato);
      if (mounted) mostrarMensaje(context, 'Guardada como ${_archivo!.path.split('/').last}');
    } catch (e) {
      if (mounted) mostrarMensaje(context, 'No se pudo guardar: ${mensajeError(e)}', error: true);
    }
  }

  Future<void> _opcionesRapidas() async {
    setState(() => _pausado = true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(title: Text('Opciones de esta partida')),
            SwitchListTile(
              title: const Text('Sonido'),
              value: p.configuracion.sonido,
              onChanged: (v) => setLocal(() => p.configuracion.sonido = v),
            ),
            SwitchListTile(
              title: const Text('Vibración'),
              value: p.configuracion.vibracion,
              onChanged: (v) => setLocal(() => p.configuracion.vibracion = v),
            ),
            ListTile(
              title: const Text('Formato de guardado'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListenableBuilder(
                  listenable: ajustes,
                  builder: (_, __) => SegmentedButton<FormatoGuardado>(
                    segments: [
                      for (final f in FormatoGuardado.values) ButtonSegment(value: f, label: Text(f.etiqueta)),
                    ],
                    selected: {ajustes.formato},
                    onSelectionChanged: (s) => ajustes.cambiarFormato(s.first),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !p.terminada) Repositorio.autoguardar(p);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.nivel.nombre),
          actions: [
            IconButton(
              tooltip: _pausado ? 'Continuar' : 'Pausa',
              icon: Icon(_pausado ? Icons.play_arrow : Icons.pause),
              onPressed: p.terminada ? null : () => setState(() => _pausado = !_pausado),
            ),
            IconButton(tooltip: 'Guardar', icon: const Icon(Icons.save), onPressed: _guardar),
            PopupMenuButton<int>(
              onSelected: (v) {
                if (v == 0) _guardarComo();
                if (v == 1) _opcionesRapidas();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('Guardar como nueva…')),
                PopupMenuItem(value: 1, child: Text('Opciones de la partida')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, r) {
            final horizontal = r.maxWidth > r.maxHeight;
            final tablero = _Tablero(
              partida: p,
              visibles: _vistaPrevia ? Set<int>.from(List.generate(p.tablero.length, (i) => i)) : _visibles,
              resaltadas: _recienAcertadas,
              horizontal: horizontal,
              onTocar: _tocar,
            );
            final panel = _Marcador(partida: p, horizontal: horizontal);
            return Stack(children: [
              Positioned.fill(
                child: horizontal
                    ? Row(children: [SizedBox(width: 220, child: panel), Expanded(child: tablero)])
                    : Column(children: [panel, Expanded(child: tablero)]),
              ),
              if (_vistaPrevia)
                const Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(child: Chip(avatar: Icon(Icons.visibility), label: Text('¡Memoriza!'))),
                ),
              if (_pausado && !p.terminada) _capaPausa(),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _capaPausa() => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withAlpha(150),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.pause_circle, size: 56),
                  const SizedBox(height: 8),
                  Text('Pausa', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  const Text('Tu progreso está guardado automáticamente.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _pausado = false),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Puntuación, tiempo y progreso.
class _Marcador extends StatelessWidget {
  const _Marcador({required this.partida, required this.horizontal});

  final Partida partida;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final p = partida;
    final esquema = Theme.of(context).colorScheme;
    final restantes = p.segundosRestantes;
    final datos = [
      _Dato(Icons.star, 'Puntos', '${p.puntuacion}', animar: true),
      _Dato(Icons.timer, restantes == null ? 'Tiempo' : 'Restante',
          tiempoLegible(restantes ?? p.segundos), alerta: restantes != null && restantes <= 15),
      _Dato(Icons.grid_view, 'Pares', '${p.paresEncontrados}/${p.nivel.pares}'),
      _Dato(Icons.local_fire_department, 'Racha', '${p.racha}'),
      _Dato(Icons.close, 'Fallos', '${p.fallos}'),
    ];
    final progreso = Column(children: [
      LinearProgressIndicator(
        value: restantes == null ? p.paresEncontrados / p.nivel.pares : restantes / p.nivel.limiteSegundos!,
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
        color: restantes != null && restantes <= 15 ? esquema.error : null,
      ),
    ]);
    if (horizontal) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final d in datos) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: d),
          const SizedBox(height: 8),
          progreso,
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: datos),
        const SizedBox(height: 8),
        progreso,
      ]),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.etiqueta, this.valor, {this.animar = false, this.alerta = false});

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool animar;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estilo = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: alerta ? esquema.error : esquema.primary,
        );
    final texto = Text(valor, key: ValueKey(valor), style: estilo);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 18, color: alerta ? esquema.error : esquema.onSurfaceVariant),
      animar
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: texto,
            )
          : texto,
      Text(etiqueta, style: Theme.of(context).textTheme.labelSmall),
    ]);
  }
}

/// Tablero responsivo: calcula el tamaño de carta para que quepa completo.
class _Tablero extends StatelessWidget {
  const _Tablero({
    required this.partida,
    required this.visibles,
    required this.resaltadas,
    required this.horizontal,
    required this.onTocar,
  });

  final Partida partida;
  final Set<int> visibles;
  final Set<int> resaltadas;
  final bool horizontal;
  final void Function(int) onTocar;

  @override
  Widget build(BuildContext context) {
    final n = partida.nivel;
    // En horizontal se usa la dimensión larga como columnas.
    final columnas = horizontal ? max(n.columnas, n.filas) : min(n.columnas, n.filas);
    final filas = n.casillas ~/ columnas;
    return LayoutBuilder(builder: (context, r) {
      const espacio = 8.0;
      final lado = min(
        (r.maxWidth - espacio * (columnas + 1)) / columnas,
        (r.maxHeight - espacio * (filas + 1)) / filas,
      ).clamp(24.0, 160.0).toDouble();
      return Center(
        child: SizedBox(
          width: lado * columnas + espacio * (columnas + 1),
          height: lado * filas + espacio * (filas + 1),
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(espacio),
            crossAxisCount: columnas,
            mainAxisSpacing: espacio,
            crossAxisSpacing: espacio,
            children: [
              for (var i = 0; i < partida.tablero.length; i++)
                _Carta(
                  simbolo: simbolos[partida.tablero[i]],
                  bocaArriba: partida.descubiertas[i] || visibles.contains(i),
                  descubierta: partida.descubiertas[i],
                  resaltada: resaltadas.contains(i),
                  onTap: () => onTocar(i),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Carta con animación de volteo (rotación en Y) y efecto al acertar.
class _Carta extends StatelessWidget {
  const _Carta({
    required this.simbolo,
    required this.bocaArriba,
    required this.descubierta,
    required this.resaltada,
    required this.onTap,
  });

  final IconData simbolo;
  final bool bocaArriba;
  final bool descubierta;
  final bool resaltada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final frente = Container(
      key: const ValueKey('frente'),
      decoration: BoxDecoration(
        color: descubierta ? esquema.tertiaryContainer : esquema.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: descubierta ? esquema.tertiary : esquema.primary, width: 2),
      ),
      child: LayoutBuilder(
        builder: (_, r) => Icon(simbolo, size: r.maxWidth * 0.55,
            color: descubierta ? esquema.onTertiaryContainer : esquema.primary),
      ),
    );
    final reverso = Container(
      key: const ValueKey('reverso'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [esquema.primary, Color.lerp(esquema.primary, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26)],
      ),
      child: LayoutBuilder(
        builder: (_, r) => Icon(Icons.question_mark, size: r.maxWidth * 0.4, color: esquema.onPrimary),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: resaltada ? 1.08 : (descubierta ? 0.94 : 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (hijo, anim) => AnimatedBuilder(
            animation: anim,
            child: hijo,
            builder: (_, c) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY((1 - anim.value) * pi / 2),
              child: c,
            ),
          ),
          child: bocaArriba ? frente : reverso,
        ),
      ),
    );
  }
}
