import 'dart:convert';

import 'package:xml/xml.dart';

import 'modelo.dart';

/// Formatos de guardado soportados.
enum FormatoGuardado {
  txt('Texto plano', 'text/plain'),
  xml('XML', 'application/xml'),
  json('JSON', 'application/json');

  const FormatoGuardado(this.etiqueta, this.mime);
  final String etiqueta;
  final String mime;

  String get extension => name;

  static FormatoGuardado? desdeExtension(String ext) {
    final e = ext.toLowerCase().replaceFirst('.', '');
    for (final f in values) {
      if (f.name == e) return f;
    }
    return null;
  }

  static FormatoGuardado desdeNombre(String? n) =>
      values.firstWhere((f) => f.name == n, orElse: () => FormatoGuardado.json);
}

/// Convierte una partida a TXT, XML o JSON y viceversa.
/// Todos los formatos guardan exactamente la misma información.
class Serializador {
  static const _firma = 'memoria-escom';
  static const _version = 1;

  static String serializar(Partida p, FormatoGuardado f) => switch (f) {
        FormatoGuardado.json => aJson(p),
        FormatoGuardado.xml => aXml(p),
        FormatoGuardado.txt => aTxt(p),
      };

  /// Lanza FormatException con un mensaje legible si el contenido es inválido.
  static Partida deserializar(String texto, FormatoGuardado f) {
    if (texto.trim().isEmpty) throw const FormatException('El archivo está vacío');
    final Partida p;
    try {
      p = switch (f) {
        FormatoGuardado.json => desdeJson(texto),
        FormatoGuardado.xml => desdeXml(texto),
        FormatoGuardado.txt => desdeTxt(texto),
      };
    } on FormatException {
      rethrow;
    } on XmlException catch (e) {
      throw FormatException('XML mal formado: ${e.message}');
    } catch (e) {
      throw FormatException('Contenido incompleto o dañado ($e)');
    }
    p.validar();
    return p;
  }

  // ------------------------------------------------------------------ JSON

  static Map<String, dynamic> aMapa(Partida p) => {
        'formato': _firma,
        'version': _version,
        'id': p.id,
        'nombre': p.nombre,
        'etiqueta': p.etiqueta,
        'nivel': p.nivel.numero,
        'creada': p.creada.toIso8601String(),
        'guardada': p.guardada.toIso8601String(),
        'puntuacion': p.puntuacion,
        'racha': p.racha,
        'fallos': p.fallos,
        'segundos': p.segundos,
        'terminada': p.terminada,
        'ganada': p.ganada,
        'tablero': p.tablero,
        'descubiertas': p.descubiertas,
        'configuracion': {
          'sonido': p.configuracion.sonido,
          'vibracion': p.configuracion.vibracion,
          'vistaPrevia': p.configuracion.vistaPrevia,
          'paleta': p.configuracion.paleta,
        },
        'historial': [
          for (final m in p.historial)
            {'segundo': m.segundo, 'a': m.a, 'b': m.b, 'acierto': m.acierto, 'puntos': m.puntos},
        ],
      };

  static String aJson(Partida p) => const JsonEncoder.withIndent('  ').convert(aMapa(p));

  static T _campo<T>(Map<String, dynamic> m, String clave) {
    final v = m[clave];
    if (v is! T) throw FormatException('Falta el campo "$clave" o tiene un tipo incorrecto');
    return v;
  }

  static Partida desdeJson(String texto) {
    final raiz = jsonDecode(texto);
    if (raiz is! Map<String, dynamic>) throw const FormatException('El JSON no es un objeto');
    if (raiz['formato'] != _firma) throw const FormatException('No es una partida de Memoria ESCOM');
    final c = _campo<Map<String, dynamic>>(raiz, 'configuracion');
    return Partida(
      id: _campo<String>(raiz, 'id'),
      nombre: _campo<String>(raiz, 'nombre'),
      etiqueta: (raiz['etiqueta'] as String?) ?? '',
      nivel: Nivel.desdeNumero(_campo<int>(raiz, 'nivel')),
      creada: DateTime.parse(_campo<String>(raiz, 'creada')),
      guardada: DateTime.parse(_campo<String>(raiz, 'guardada')),
      puntuacion: _campo<int>(raiz, 'puntuacion'),
      racha: _campo<int>(raiz, 'racha'),
      fallos: _campo<int>(raiz, 'fallos'),
      segundos: _campo<int>(raiz, 'segundos'),
      terminada: _campo<bool>(raiz, 'terminada'),
      ganada: _campo<bool>(raiz, 'ganada'),
      tablero: _campo<List<dynamic>>(raiz, 'tablero').map((e) => e as int).toList(),
      descubiertas: _campo<List<dynamic>>(raiz, 'descubiertas').map((e) => e as bool).toList(),
      configuracion: Configuracion(
        sonido: _campo<bool>(c, 'sonido'),
        vibracion: _campo<bool>(c, 'vibracion'),
        vistaPrevia: _campo<int>(c, 'vistaPrevia'),
        paleta: _campo<String>(c, 'paleta'),
      ),
      historial: [
        for (final m in _campo<List<dynamic>>(raiz, 'historial'))
          Movimiento(
            segundo: (m as Map)['segundo'] as int,
            a: m['a'] as int,
            b: m['b'] as int,
            acierto: m['acierto'] as bool,
            puntos: m['puntos'] as int,
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ XML

  static String aXml(Partida p) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element('partida', attributes: {'formato': _firma, 'version': '$_version'}, nest: () {
      b.element('id', nest: p.id);
      b.element('nombre', nest: p.nombre);
      b.element('etiqueta', nest: p.etiqueta);
      b.element('nivel', nest: '${p.nivel.numero}');
      b.element('creada', nest: p.creada.toIso8601String());
      b.element('guardada', nest: p.guardada.toIso8601String());
      b.element('estado', attributes: {
        'puntuacion': '${p.puntuacion}',
        'racha': '${p.racha}',
        'fallos': '${p.fallos}',
        'segundos': '${p.segundos}',
        'terminada': '${p.terminada}',
        'ganada': '${p.ganada}',
      });
      b.element('tablero', nest: p.tablero.join(','));
      b.element('descubiertas', nest: p.descubiertas.map((d) => d ? '1' : '0').join(','));
      b.element('configuracion', nest: () {
        b.element('sonido', nest: '${p.configuracion.sonido}');
        b.element('vibracion', nest: '${p.configuracion.vibracion}');
        b.element('vistaPrevia', nest: '${p.configuracion.vistaPrevia}');
        b.element('paleta', nest: p.configuracion.paleta);
      });
      b.element('historial', attributes: {'total': '${p.historial.length}'}, nest: () {
        for (final m in p.historial) {
          b.element('movimiento', attributes: {
            'segundo': '${m.segundo}',
            'a': '${m.a}',
            'b': '${m.b}',
            'acierto': '${m.acierto}',
            'puntos': '${m.puntos}',
          });
        }
      });
    });
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static String _texto(XmlElement padre, String nombre) {
    final e = padre.getElement(nombre);
    if (e == null) throw FormatException('Falta el elemento <$nombre>');
    return e.innerText.trim();
  }

  static String _atributo(XmlElement e, String nombre) {
    final v = e.getAttribute(nombre);
    if (v == null) throw FormatException('Falta el atributo "$nombre" en <${e.name.local}>');
    return v;
  }

  static int _entero(String v, String campo) =>
      int.tryParse(v.trim()) ?? (throw FormatException('"$campo" no es un número: "$v"'));

  static bool _booleano(String v, String campo) => switch (v.trim()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => throw FormatException('"$campo" no es verdadero/falso: "$v"'),
      };

  static List<int> _listaEnteros(String v, String campo) =>
      v.trim().isEmpty ? <int>[] : v.split(',').map((x) => _entero(x, campo)).toList();

  static Partida desdeXml(String texto) {
    final raiz = XmlDocument.parse(texto).rootElement;
    if (raiz.name.local != 'partida' || raiz.getAttribute('formato') != _firma) {
      throw const FormatException('No es una partida de Memoria ESCOM');
    }
    final estado = raiz.getElement('estado') ?? (throw const FormatException('Falta el elemento <estado>'));
    final conf = raiz.getElement('configuracion') ?? (throw const FormatException('Falta <configuracion>'));
    final hist = raiz.getElement('historial') ?? (throw const FormatException('Falta <historial>'));
    return Partida(
      id: _texto(raiz, 'id'),
      nombre: _texto(raiz, 'nombre'),
      etiqueta: raiz.getElement('etiqueta')?.innerText.trim() ?? '',
      nivel: Nivel.desdeNumero(_entero(_texto(raiz, 'nivel'), 'nivel')),
      creada: DateTime.parse(_texto(raiz, 'creada')),
      guardada: DateTime.parse(_texto(raiz, 'guardada')),
      puntuacion: _entero(_atributo(estado, 'puntuacion'), 'puntuacion'),
      racha: _entero(_atributo(estado, 'racha'), 'racha'),
      fallos: _entero(_atributo(estado, 'fallos'), 'fallos'),
      segundos: _entero(_atributo(estado, 'segundos'), 'segundos'),
      terminada: _booleano(_atributo(estado, 'terminada'), 'terminada'),
      ganada: _booleano(_atributo(estado, 'ganada'), 'ganada'),
      tablero: _listaEnteros(_texto(raiz, 'tablero'), 'tablero'),
      descubiertas: _listaEnteros(_texto(raiz, 'descubiertas'), 'descubiertas').map((x) => x == 1).toList(),
      configuracion: Configuracion(
        sonido: _booleano(_texto(conf, 'sonido'), 'sonido'),
        vibracion: _booleano(_texto(conf, 'vibracion'), 'vibracion'),
        vistaPrevia: _entero(_texto(conf, 'vistaPrevia'), 'vistaPrevia'),
        paleta: _texto(conf, 'paleta'),
      ),
      historial: [
        for (final m in hist.findElements('movimiento'))
          Movimiento(
            segundo: _entero(_atributo(m, 'segundo'), 'segundo'),
            a: _entero(_atributo(m, 'a'), 'a'),
            b: _entero(_atributo(m, 'b'), 'b'),
            acierto: _booleano(_atributo(m, 'acierto'), 'acierto'),
            puntos: _entero(_atributo(m, 'puntos'), 'puntos'),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ TXT
  //
  // Formato propio, legible por humanos:
  //   clave=valor            (una por línea)
  //   [historial]
  //   segundo;a;b;acierto;puntos

  static String _limpiar(String s) => s.replaceAll(RegExp(r'[\r\n]+'), ' ');

  static String aTxt(Partida p) {
    final s = StringBuffer()
      ..writeln('# Partida de Memoria ESCOM')
      ..writeln('formato=$_firma')
      ..writeln('version=$_version')
      ..writeln('id=${p.id}')
      ..writeln('nombre=${_limpiar(p.nombre)}')
      ..writeln('etiqueta=${_limpiar(p.etiqueta)}')
      ..writeln('nivel=${p.nivel.numero}')
      ..writeln('creada=${p.creada.toIso8601String()}')
      ..writeln('guardada=${p.guardada.toIso8601String()}')
      ..writeln('puntuacion=${p.puntuacion}')
      ..writeln('racha=${p.racha}')
      ..writeln('fallos=${p.fallos}')
      ..writeln('segundos=${p.segundos}')
      ..writeln('terminada=${p.terminada}')
      ..writeln('ganada=${p.ganada}')
      ..writeln('tablero=${p.tablero.join(',')}')
      ..writeln('descubiertas=${p.descubiertas.map((d) => d ? '1' : '0').join(',')}')
      ..writeln('config.sonido=${p.configuracion.sonido}')
      ..writeln('config.vibracion=${p.configuracion.vibracion}')
      ..writeln('config.vistaPrevia=${p.configuracion.vistaPrevia}')
      ..writeln('config.paleta=${p.configuracion.paleta}')
      ..writeln('[historial]');
    for (final m in p.historial) {
      s.writeln('${m.segundo};${m.a};${m.b};${m.acierto};${m.puntos}');
    }
    return s.toString();
  }

  static Partida desdeTxt(String texto) {
    final datos = <String, String>{};
    final movimientos = <Movimiento>[];
    var enHistorial = false;
    var numLinea = 0;
    for (final cruda in const LineSplitter().convert(texto)) {
      numLinea++;
      final linea = cruda.trim();
      if (linea.isEmpty || linea.startsWith('#')) continue;
      if (linea == '[historial]') {
        enHistorial = true;
        continue;
      }
      if (enHistorial) {
        final p = linea.split(';');
        if (p.length != 5) throw FormatException('Movimiento inválido en la línea $numLinea');
        movimientos.add(Movimiento(
          segundo: _entero(p[0], 'segundo'),
          a: _entero(p[1], 'a'),
          b: _entero(p[2], 'b'),
          acierto: _booleano(p[3], 'acierto'),
          puntos: _entero(p[4], 'puntos'),
        ));
      } else {
        final i = linea.indexOf('=');
        if (i <= 0) throw FormatException('Línea $numLinea sin formato clave=valor');
        datos[linea.substring(0, i).trim()] = linea.substring(i + 1);
      }
    }
    if (!enHistorial) throw const FormatException('Falta la sección [historial]: el archivo está incompleto');
    String req(String k) => datos[k] ?? (throw FormatException('Falta la clave "$k"'));
    if (req('formato') != _firma) throw const FormatException('No es una partida de Memoria ESCOM');

    return Partida(
      id: req('id'),
      nombre: req('nombre'),
      etiqueta: datos['etiqueta'] ?? '',
      nivel: Nivel.desdeNumero(_entero(req('nivel'), 'nivel')),
      creada: DateTime.parse(req('creada')),
      guardada: DateTime.parse(req('guardada')),
      puntuacion: _entero(req('puntuacion'), 'puntuacion'),
      racha: _entero(req('racha'), 'racha'),
      fallos: _entero(req('fallos'), 'fallos'),
      segundos: _entero(req('segundos'), 'segundos'),
      terminada: _booleano(req('terminada'), 'terminada'),
      ganada: _booleano(req('ganada'), 'ganada'),
      tablero: _listaEnteros(req('tablero'), 'tablero'),
      descubiertas: _listaEnteros(req('descubiertas'), 'descubiertas').map((x) => x == 1).toList(),
      configuracion: Configuracion(
        sonido: _booleano(req('config.sonido'), 'config.sonido'),
        vibracion: _booleano(req('config.vibracion'), 'config.vibracion'),
        vistaPrevia: _entero(req('config.vistaPrevia'), 'config.vistaPrevia'),
        paleta: req('config.paleta'),
      ),
      historial: movimientos,
    );
  }
}
