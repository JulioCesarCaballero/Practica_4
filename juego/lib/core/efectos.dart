import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Retroalimentación sonora y háptica. Nunca lanza excepciones al juego.
class Efectos {
  static final Map<String, AudioPlayer> _jugadores = {};

  static Future<void> sonar(String nombre, {required bool activo}) async {
    if (!activo) return;
    try {
      final j = _jugadores.putIfAbsent(nombre, AudioPlayer.new);
      await j.stop();
      await j.play(AssetSource('sonidos/$nombre.wav'));
    } catch (_) {
      // Si el audio falla (p. ej. emulador sin audio) el juego continúa.
    }
  }

  static void vibrar({required bool activo, bool fuerte = false}) {
    if (!activo) return;
    fuerte ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  }
}
