import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tema.dart';
import 'modelo.dart';
import 'serializacion.dart';

late final Ajustes ajustes;

/// Preferencias globales del juego (persisten con SharedPreferences).
/// Son los valores por defecto para las partidas nuevas.
class Ajustes extends ChangeNotifier {
  Ajustes._(this._p);

  final SharedPreferences _p;

  Paleta paleta = Paleta.guinda;
  FormatoGuardado formato = FormatoGuardado.json;
  bool sonido = true;
  bool vibracion = true;
  int vistaPrevia = 2;

  static Future<void> inicializar() async {
    final a = Ajustes._(await SharedPreferences.getInstance());
    a.paleta = Paleta.desdeNombre(a._p.getString('paleta'));
    a.formato = FormatoGuardado.desdeNombre(a._p.getString('formato'));
    a.sonido = a._p.getBool('sonido') ?? true;
    a.vibracion = a._p.getBool('vibracion') ?? true;
    a.vistaPrevia = (a._p.getInt('vistaPrevia') ?? 2).clamp(0, 3);
    ajustes = a;
  }

  Configuracion get configuracion =>
      Configuracion(sonido: sonido, vibracion: vibracion, vistaPrevia: vistaPrevia, paleta: paleta.name);

  Future<void> cambiarPaleta(Paleta v) async {
    paleta = v;
    notifyListeners();
    await _p.setString('paleta', v.name);
  }

  Future<void> cambiarFormato(FormatoGuardado v) async {
    formato = v;
    notifyListeners();
    await _p.setString('formato', v.name);
  }

  Future<void> cambiarSonido(bool v) async {
    sonido = v;
    notifyListeners();
    await _p.setBool('sonido', v);
  }

  Future<void> cambiarVibracion(bool v) async {
    vibracion = v;
    notifyListeners();
    await _p.setBool('vibracion', v);
  }

  Future<void> cambiarVistaPrevia(int v) async {
    vistaPrevia = v;
    notifyListeners();
    await _p.setInt('vistaPrevia', v);
  }
}
