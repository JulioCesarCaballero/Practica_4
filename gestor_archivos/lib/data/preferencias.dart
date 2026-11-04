import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tema.dart';
import 'entrada.dart';

/// Instancia global; se inicializa en main().
late final Preferencias preferencias;

/// Persistencia ligera con shared_preferences (SharedPreferences en Android):
/// tema elegido, archivos recientes y favoritos.
class Preferencias extends ChangeNotifier {
  Preferencias._(this._p);

  final SharedPreferences _p;
  static const _kPaleta = 'paleta';
  static const _kRecientes = 'recientes';
  static const _kFavoritos = 'favoritos';
  static const maxRecientes = 20;

  Paleta paleta = Paleta.guinda;
  List<Entrada> recientes = [];
  List<Entrada> favoritos = [];

  static Future<void> inicializar() async {
    final p = Preferencias._(await SharedPreferences.getInstance());
    p.paleta = Paleta.desdeNombre(p._p.getString(_kPaleta));
    p.recientes = p._leerLista(_kRecientes);
    p.favoritos = p._leerLista(_kFavoritos);
    preferencias = p;
  }

  List<Entrada> _leerLista(String clave) {
    try {
      final texto = _p.getString(clave);
      if (texto == null) return [];
      return (jsonDecode(texto) as List)
          .map((e) => Entrada.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // Datos dañados: se descartan sin bloquear la app.
      _p.remove(clave);
      return [];
    }
  }

  Future<void> _guardarLista(String clave, List<Entrada> lista) =>
      _p.setString(clave, jsonEncode(lista.map((e) => e.toJson()).toList()));

  Future<void> cambiarPaleta(Paleta nueva) async {
    paleta = nueva;
    notifyListeners();
    await _p.setString(_kPaleta, nueva.name);
  }

  Future<void> agregarReciente(Entrada e) async {
    recientes.removeWhere((r) => r.id == e.id);
    recientes.insert(0, e);
    if (recientes.length > maxRecientes) recientes = recientes.sublist(0, maxRecientes);
    notifyListeners();
    await _guardarLista(_kRecientes, recientes);
  }

  Future<void> quitarReciente(Entrada e) async {
    recientes.removeWhere((r) => r.id == e.id);
    notifyListeners();
    await _guardarLista(_kRecientes, recientes);
  }

  Future<void> limpiarRecientes() async {
    recientes = [];
    notifyListeners();
    await _guardarLista(_kRecientes, recientes);
  }

  bool esFavorito(Entrada e) => favoritos.any((f) => f.id == e.id);

  Future<void> alternarFavorito(Entrada e) async {
    if (esFavorito(e)) {
      favoritos.removeWhere((f) => f.id == e.id);
    } else {
      favoritos.add(e);
    }
    notifyListeners();
    await _guardarLista(_kFavoritos, favoritos);
  }

  /// Quita una entrada de recientes y favoritos (p. ej. al eliminarla).
  Future<void> olvidar(Entrada e) async {
    recientes.removeWhere((r) => r.id == e.id || r.id.startsWith('${e.id}/'));
    favoritos.removeWhere((f) => f.id == e.id || f.id.startsWith('${e.id}/'));
    notifyListeners();
    await _guardarLista(_kRecientes, recientes);
    await _guardarLista(_kFavoritos, favoritos);
  }
}
