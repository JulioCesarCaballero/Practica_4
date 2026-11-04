import 'package:flutter/material.dart';

/// Paletas disponibles en la app.
enum Paleta {
  guinda('Guinda IPN'),
  azul('Azul ESCOM');

  const Paleta(this.etiqueta);
  final String etiqueta;

  static Paleta desdeNombre(String? nombre) =>
      Paleta.values.firstWhere((p) => p.name == nombre, orElse: () => Paleta.guinda);
}

/// Construye los temas Guinda (IPN) y Azul (ESCOM) en versión clara y oscura.
/// La app usa `ThemeMode.system`, así que el modo claro/oscuro sigue al sistema.
class Temas {
  static const Color guindaIpn = Color(0xFF6C1D45);
  static const Color azulEscom = Color(0xFF003D79);

  static Color semilla(Paleta p) => p == Paleta.guinda ? guindaIpn : azulEscom;

  static ThemeData crear(Paleta paleta, Brightness brillo) {
    final color = semilla(paleta);
    final base = ColorScheme.fromSeed(seedColor: color, brightness: brillo);
    final claro = brillo == Brightness.light;
    // En modo claro se usa el color institucional exacto como primario.
    final esquema = claro ? base.copyWith(primary: color, onPrimary: Colors.white) : base;
    final barra = claro ? color : Color.lerp(color, Colors.black, 0.45)!;

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      appBarTheme: AppBarTheme(
        backgroundColor: barra,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: esquema.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: esquema.primaryContainer,
        foregroundColor: esquema.onPrimaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
