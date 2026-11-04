import 'dart:math';

import 'package:flutter/material.dart';

/// Niveles / modos de juego.
enum Nivel {
  clasico(1, 'Clásico', 'Tablero 4×4 sin límite de tiempo', 4, 4, null),
  contrarreloj(2, 'Contrarreloj', 'Tablero 4×6 con 120 segundos', 4, 6, 120);

  const Nivel(this.numero, this.nombre, this.descripcion, this.columnas, this.filas, this.limiteSegundos);

  final int numero;
  final String nombre;
  final String descripcion;
  final int columnas;
  final int filas;
  final int? limiteSegundos;

  int get casillas => columnas * filas;
  int get pares => casillas ~/ 2;

  static Nivel desdeNumero(int n) {
    for (final v in values) {
      if (v.numero == n) return v;
    }
    throw FormatException('Nivel desconocido: $n');
  }
}

/// Símbolos de las cartas (temática de cómputo). El índice es lo que se guarda.
const List<IconData> simbolos = [
  Icons.school,
  Icons.computer,
  Icons.memory,
  Icons.code,
  Icons.terminal,
  Icons.wifi,
  Icons.android,
  Icons.bug_report,
  Icons.storage,
  Icons.cloud,
  Icons.router,
  Icons.smartphone,
];

/// Configuraciones personalizadas que se guardan con cada partida.
class Configuracion {
  Configuracion({
    this.sonido = true,
    this.vibracion = true,
    this.vistaPrevia = 2,
    this.paleta = 'guinda',
  });

  bool sonido;
  bool vibracion;

  /// Segundos que se muestran todas las cartas al iniciar (0-3).
  int vistaPrevia;
  String paleta;

  Configuracion copia() =>
      Configuracion(sonido: sonido, vibracion: vibracion, vistaPrevia: vistaPrevia, paleta: paleta);
}

/// Un movimiento del historial: dos cartas volteadas.
class Movimiento {
  const Movimiento({
    required this.segundo,
    required this.a,
    required this.b,
    required this.acierto,
    required this.puntos,
  });

  final int segundo;
  final int a;
  final int b;
  final bool acierto;
  final int puntos;
}

/// Estado completo y recuperable de una partida.
class Partida {
  Partida({
    required this.id,
    required this.nombre,
    required this.etiqueta,
    required this.nivel,
    required this.tablero,
    required this.descubiertas,
    required this.creada,
    required this.guardada,
    required this.configuracion,
    required this.historial,
    this.puntuacion = 0,
    this.racha = 0,
    this.fallos = 0,
    this.segundos = 0,
    this.terminada = false,
    this.ganada = false,
  });

  String id;
  String nombre;
  String etiqueta;
  final Nivel nivel;

  /// Índice del símbolo en cada casilla.
  final List<int> tablero;
  final List<bool> descubiertas;
  final DateTime creada;
  DateTime guardada;
  Configuracion configuracion;
  final List<Movimiento> historial;
  int puntuacion;
  int racha;
  int fallos;
  int segundos;
  bool terminada;
  bool ganada;

  static String nuevoId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 20).toRadixString(36)}';
  }

  factory Partida.nueva(Nivel nivel, Configuracion config) {
    final simbolosNivel = List<int>.generate(nivel.pares, (i) => i);
    final tablero = [...simbolosNivel, ...simbolosNivel]..shuffle(Random());
    final ahora = DateTime.now();
    return Partida(
      id: nuevoId(),
      nombre: '${nivel.nombre} ${ahora.day}/${ahora.month} ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')}',
      etiqueta: '',
      nivel: nivel,
      tablero: tablero,
      descubiertas: List<bool>.filled(tablero.length, false),
      creada: ahora,
      guardada: ahora,
      configuracion: config.copia(),
      historial: [],
    );
  }

  int get paresEncontrados => descubiertas.where((d) => d).length ~/ 2;

  int? get segundosRestantes =>
      nivel.limiteSegundos == null ? null : max(0, nivel.limiteSegundos! - segundos);

  /// Comprueba que el estado sea coherente. Lanza FormatException si no.
  /// Se usa al cargar para detectar archivos incompletos o manipulados.
  void validar() {
    if (id.trim().isEmpty) throw const FormatException('El identificador está vacío');
    if (tablero.length != nivel.casillas) {
      throw FormatException('El tablero debe tener ${nivel.casillas} casillas y tiene ${tablero.length}');
    }
    if (descubiertas.length != tablero.length) {
      throw const FormatException('La lista de cartas descubiertas no coincide con el tablero');
    }
    final conteo = <int, int>{};
    for (final s in tablero) {
      if (s < 0 || s >= nivel.pares) throw FormatException('Símbolo fuera de rango: $s');
      conteo[s] = (conteo[s] ?? 0) + 1;
    }
    if (conteo.length != nivel.pares || conteo.values.any((c) => c != 2)) {
      throw const FormatException('Cada símbolo debe aparecer exactamente dos veces');
    }
    for (var s = 0; s < nivel.pares; s++) {
      final pos = [for (var i = 0; i < tablero.length; i++) if (tablero[i] == s) i];
      if (descubiertas[pos[0]] != descubiertas[pos[1]]) {
        throw const FormatException('Hay una pareja descubierta a medias');
      }
    }
    if (puntuacion < 0 || segundos < 0 || fallos < 0 || racha < 0) {
      throw const FormatException('Valores numéricos negativos');
    }
    for (final m in historial) {
      if (m.a < 0 || m.a >= tablero.length || m.b < 0 || m.b >= tablero.length) {
        throw const FormatException('Movimiento con casillas fuera del tablero');
      }
    }
    if (configuracion.vistaPrevia < 0 || configuracion.vistaPrevia > 10) {
      throw const FormatException('Vista previa fuera de rango');
    }
  }
}
