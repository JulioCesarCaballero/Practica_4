import 'package:flutter/material.dart';

import 'core/tema.dart';
import 'data/archivos.dart';
import 'data/preferencias.dart';
import 'ui/pantalla_inicio.dart';

/// Práctica 4 - Parte 1: Gestor de archivos multiplataforma.
/// ESCOM IPN · Desarrollo de aplicaciones móviles nativas.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Preferencias.inicializar();
  await Archivos.inicializar();
  runApp(const GestorApp());
}

class GestorApp extends StatelessWidget {
  const GestorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferencias,
      builder: (context, _) => MaterialApp(
        title: 'Gestor ESCOM',
        debugShowCheckedModeBanner: false,
        theme: Temas.crear(preferencias.paleta, Brightness.light),
        darkTheme: Temas.crear(preferencias.paleta, Brightness.dark),
        themeMode: ThemeMode.system, // claro/oscuro automático según el sistema
        home: const PantallaInicio(),
      ),
    );
  }
}
