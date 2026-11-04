import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../data/ajustes.dart';
import '../data/repositorio.dart';
import '../data/serializacion.dart';
import 'comun.dart';
import 'partidas.dart';

/// Menú de opciones: formato de guardado, gestión de partidas,
/// aspecto visual y jugabilidad.
class PantallaOpciones extends StatelessWidget {
  const PantallaOpciones({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Opciones')),
      body: ListenableBuilder(
        listenable: ajustes,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Formato de guardado', style: t.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<FormatoGuardado>(
              segments: [
                for (final f in FormatoGuardado.values)
                  ButtonSegment(value: f, label: Text('${f.etiqueta}\n.${f.extension}', textAlign: TextAlign.center)),
              ],
              selected: {ajustes.formato},
              onSelectionChanged: (s) => ajustes.cambiarFormato(s.first),
            ),
            const SizedBox(height: 4),
            Text('Se usa al guardar una partida nueva. También puedes elegirlo en "Guardar como".', style: t.bodySmall),
            const Divider(height: 32),
            Text('Partidas', style: t.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_open),
              title: const Text('Gestionar partidas guardadas'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaPartidas())),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Crear archivos dañados de prueba'),
              subtitle: const Text('Para probar la validación de archivos vacíos, incompletos y corruptos'),
              onTap: () async {
                await Repositorio.crearArchivosDanados();
                if (context.mounted) mostrarMensaje(context, 'Se crearon 3 archivos de prueba en Partidas.');
              },
            ),
            const Divider(height: 32),
            Text('Aspecto visual', style: t.titleMedium),
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
              selected: {ajustes.paleta},
              onSelectionChanged: (s) => ajustes.cambiarPaleta(s.first),
            ),
            const SizedBox(height: 4),
            Text('El modo claro/oscuro sigue la configuración del sistema.', style: t.bodySmall),
            const Divider(height: 32),
            Text('Jugabilidad (partidas nuevas)', style: t.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sonido'),
              value: ajustes.sonido,
              onChanged: ajustes.cambiarSonido,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibración'),
              value: ajustes.vibracion,
              onChanged: ajustes.cambiarVibracion,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vista previa al iniciar'),
              subtitle: Text(ajustes.vistaPrevia == 0
                  ? 'Desactivada'
                  : 'Mostrar todas las cartas ${ajustes.vistaPrevia} s'),
            ),
            Slider(
              value: ajustes.vistaPrevia.toDouble(),
              min: 0,
              max: 3,
              divisions: 3,
              label: '${ajustes.vistaPrevia} s',
              onChanged: (v) => ajustes.cambiarVistaPrevia(v.round()),
            ),
          ],
        ),
      ),
    );
  }
}
