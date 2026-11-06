import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../data/archivos.dart';
import '../data/preferencias.dart';
import 'acciones.dart';
import 'miniaturas.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  int? _tamanoCache;

  @override
  void initState() {
    super.initState();
    _medirCache();
  }

  Future<void> _medirCache() async {
    try {
      final t = await Archivos.tamanoCache();
      if (mounted) setState(() => _tamanoCache = t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final oscuro = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return ListenableBuilder(
      listenable: preferencias,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tema', style: t.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<Paleta>(
            segments: [
              for (final p in Paleta.values)
                ButtonSegment(
                  value: p,
                  label: Text(p.etiqueta),
                  icon: CircleAvatar(radius: 8, backgroundColor: Temas.semilla(p)),
                ),
            ],
            selected: {preferencias.paleta},
            onSelectionChanged: (s) => preferencias.cambiarPaleta(s.first),
          ),
          const SizedBox(height: 8),
          Text('Modo ${oscuro ? 'oscuro' : 'claro'} detectado: el tema se adapta automáticamente '
              'a la configuración del sistema.', style: t.bodySmall),
          const Divider(height: 32),
          Text('Caché', style: t.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Miniaturas en memoria'),
            subtitle: Text('${CacheMiniaturas.cantidad} de ${CacheMiniaturas.maximo} (reducidas a ${CacheMiniaturas.ancho} px)'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cached),
            title: const Text('Copias temporales de documentos externos'),
            subtitle: Text(_tamanoCache == null ? 'Calculando…' : tamanoLegible(_tamanoCache)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                CacheMiniaturas.limpiar();
                await ejecutarConProgreso(context, Archivos.limpiarCache, exito: 'Caché liberada.');
                _medirCache();
              },
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Limpiar caché'),
            ),
          ),
          const Divider(height: 32),
          Text('Datos de ejemplo', style: t.titleMedium),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => ejecutarConProgreso(context, Archivos.crearEjemplos,
                  exito: 'Archivos de ejemplo restaurados en el almacenamiento de la app.'),
              icon: const Icon(Icons.restore),
              label: const Text('Restaurar archivos de ejemplo'),
            ),
          ),
          const Divider(height: 32),
          Text('Acerca de', style: t.titleMedium),
          const SizedBox(height: 8),
          Text('Práctica 4 · Parte 1: Gestor de archivos\n'
              'Desarrollo de aplicaciones móviles nativas · ESCOM IPN\n\n'
              'Funciona 100 % sin conexión. ${Platform.isIOS ? 'En iOS se respeta el sandbox: la app solo usa su almacenamiento privado y las carpetas o archivos que elijas con el selector de Archivos (document picker).' : 'En Android se respeta Scoped Storage: la app solo usa su almacenamiento privado y las carpetas o archivos que elijas con el selector del sistema (Storage Access Framework).'}'),
        ],
      ),
    );
  }
}
