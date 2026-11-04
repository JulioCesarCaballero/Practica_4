// Pruebas unitarias de utilidades del gestor. Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/core/formato.dart';
import 'package:gestor_archivos/data/entrada.dart';
import 'package:gestor_archivos/data/tipos.dart';

Entrada _archivo(String nombre, {String? mime}) =>
    Entrada(id: '/tmp/$nombre', nombre: nombre, esCarpeta: false, origen: Origen.local, mime: mime);

void main() {
  test('Detección de tipo de visor', () {
    expect(tipoDe(_archivo('notas.md')), TipoVista.texto);
    expect(tipoDe(_archivo('a.TXT')), TipoVista.texto);
    expect(tipoDe(_archivo('config.json')), TipoVista.json);
    expect(tipoDe(_archivo('catalogo.xml')), TipoVista.xml);
    expect(tipoDe(_archivo('foto.JPG')), TipoVista.imagen);
    expect(tipoDe(_archivo('datos.bin')), TipoVista.noSoportado);
    expect(tipoDe(_archivo('sin_ext', mime: 'application/json')), TipoVista.json);
  });

  test('Formato de tamaño', () {
    expect(tamanoLegible(null), 'No disponible');
    expect(tamanoLegible(512), '512 B');
    expect(tamanoLegible(2048), '2.0 KB');
  });

  test('Serialización de favoritos/recientes', () {
    final e = _archivo('x.txt', mime: 'text/plain');
    final copia = Entrada.fromJson(e.toJson());
    expect(copia.id, e.id);
    expect(copia.nombre, e.nombre);
    expect(copia.origen, Origen.local);
  });
}
