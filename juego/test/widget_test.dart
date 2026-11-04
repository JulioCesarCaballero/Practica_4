// Pruebas de serialización: guardar y cargar en TXT, XML y JSON debe
// recuperar exactamente el mismo estado, y los archivos dañados deben rechazarse.
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:juego/data/modelo.dart';
import 'package:juego/data/serializacion.dart';

Partida _partidaDePrueba() {
  final p = Partida.nueva(Nivel.contrarreloj, Configuracion(sonido: false, vistaPrevia: 3, paleta: 'azul'));
  p.nombre = 'Prueba con "comillas" & <símbolos>';
  p.etiqueta = 'Difícil';
  // Descubrir la primera pareja.
  final s = p.tablero[0];
  final j = p.tablero.indexOf(s, 1);
  p.descubiertas[0] = true;
  p.descubiertas[j] = true;
  p.puntuacion = 230;
  p.racha = 1;
  p.fallos = 2;
  p.segundos = 47;
  p.historial.addAll(const [
    Movimiento(segundo: 5, a: 1, b: 2, acierto: false, puntos: 0),
    Movimiento(segundo: 9, a: 3, b: 4, acierto: false, puntos: 0),
  ]);
  p.historial.add(Movimiento(segundo: 12, a: 0, b: j, acierto: true, puntos: 100));
  return p;
}

void main() {
  for (final formato in FormatoGuardado.values) {
    test('Ida y vuelta en ${formato.etiqueta}', () {
      final original = _partidaDePrueba();
      final texto = Serializador.serializar(original, formato);
      final leida = Serializador.deserializar(texto, formato);
      expect(Serializador.aMapa(leida), Serializador.aMapa(original));
    });

    test('Archivo vacío en ${formato.etiqueta} se rechaza', () {
      expect(() => Serializador.deserializar('   ', formato), throwsFormatException);
    });

    test('Archivo truncado en ${formato.etiqueta} se rechaza', () {
      final texto = Serializador.serializar(_partidaDePrueba(), formato);
      final truncado = texto.substring(0, texto.length ~/ 2);
      expect(() => Serializador.deserializar(truncado, formato), throwsFormatException);
    });
  }

  test('Tablero manipulado se rechaza', () {
    final p = _partidaDePrueba();
    p.tablero[0] = p.tablero[1] == 0 ? 1 : 0; // rompe las parejas
    final texto = Serializador.aJson(p);
    expect(() => Serializador.deserializar(texto, FormatoGuardado.json), throwsFormatException);
  });
}
