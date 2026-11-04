import 'package:flutter/material.dart';

import 'core/tema.dart';
import 'data/ajustes.dart';
import 'data/repositorio.dart';
import 'ui/menu.dart';

/// Práctica 4 - Parte 2: Memoria ESCOM, juego con gestión de archivos.
/// ESCOM IPN · Desarrollo de aplicaciones móviles nativas.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Ajustes.inicializar();
  await Repositorio.inicializar();
  runApp(const JuegoApp());
}

class JuegoApp extends StatelessWidget {
  const JuegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) => MaterialApp(
        title: 'Memoria ESCOM',
        debugShowCheckedModeBanner: false,
        theme: Temas.crear(ajustes.paleta, Brightness.light),
        darkTheme: Temas.crear(ajustes.paleta, Brightness.dark),
        themeMode: ThemeMode.system,
        home: const PantallaMenu(),
      ),
    );
  }
}
