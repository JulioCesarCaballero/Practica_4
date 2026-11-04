import 'package:flutter/material.dart';

enum Lenguaje { json, xml, texto }

/// Resaltado de sintaxis simple para JSON y XML, sin dependencias externas.
/// Divide el texto con expresiones regulares y asigna un color a cada token.
class CodigoResaltado extends StatelessWidget {
  const CodigoResaltado({super.key, required this.texto, required this.lenguaje});

  final String texto;
  final Lenguaje lenguaje;

  /// Arriba de este tamaño se muestra sin colores para no congelar la UI.
  static const limiteResaltado = 200 * 1024;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.35,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final spans = texto.length > limiteResaltado
        ? [TextSpan(text: texto)]
        : switch (lenguaje) {
            Lenguaje.json => _json(texto, _Colores(oscuro)),
            Lenguaje.xml => _xml(texto, _Colores(oscuro)),
            Lenguaje.texto => [TextSpan(text: texto)],
          };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText.rich(TextSpan(style: base, children: spans)),
      ),
    );
  }

  static final _reJson = RegExp(
    r'("(?:\\.|[^"\\])*")(\s*:)?|\b(true|false|null)\b|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|([{}\[\],])',
  );

  static List<TextSpan> _json(String t, _Colores c) {
    final r = <TextSpan>[];
    var ultimo = 0;
    for (final m in _reJson.allMatches(t)) {
      if (m.start > ultimo) r.add(TextSpan(text: t.substring(ultimo, m.start)));
      if (m.group(1) != null) {
        final esClave = m.group(2) != null;
        r.add(TextSpan(
          text: m.group(1),
          style: TextStyle(color: esClave ? c.clave : c.cadena, fontWeight: esClave ? FontWeight.w600 : null),
        ));
        if (esClave) r.add(TextSpan(text: m.group(2), style: TextStyle(color: c.puntuacion)));
      } else if (m.group(3) != null) {
        r.add(TextSpan(text: m.group(3), style: TextStyle(color: c.palabra, fontWeight: FontWeight.w600)));
      } else if (m.group(4) != null) {
        r.add(TextSpan(text: m.group(4), style: TextStyle(color: c.numero)));
      } else {
        r.add(TextSpan(text: m.group(5), style: TextStyle(color: c.puntuacion)));
      }
      ultimo = m.end;
    }
    if (ultimo < t.length) r.add(TextSpan(text: t.substring(ultimo)));
    return r;
  }

  static final _reXml = RegExp(
    r"""(<!--[\s\S]*?-->)|(<\?[\s\S]*?\?>)|(<!\[CDATA\[[\s\S]*?\]\]>)|(</?)([\w:.\-]+)|([\w:.\-]+)(=)("[^"]*"|'[^']*')|(/?>)""",
  );

  static List<TextSpan> _xml(String t, _Colores c) {
    final r = <TextSpan>[];
    var ultimo = 0;
    for (final m in _reXml.allMatches(t)) {
      if (m.start > ultimo) r.add(TextSpan(text: t.substring(ultimo, m.start)));
      if (m.group(1) != null) {
        r.add(TextSpan(text: m.group(1), style: TextStyle(color: c.comentario, fontStyle: FontStyle.italic)));
      } else if (m.group(2) != null) {
        r.add(TextSpan(text: m.group(2), style: TextStyle(color: c.palabra)));
      } else if (m.group(3) != null) {
        r.add(TextSpan(text: m.group(3), style: TextStyle(color: c.cadena)));
      } else if (m.group(4) != null) {
        r.add(TextSpan(text: m.group(4), style: TextStyle(color: c.puntuacion)));
        r.add(TextSpan(text: m.group(5), style: TextStyle(color: c.clave, fontWeight: FontWeight.w600)));
      } else if (m.group(6) != null) {
        r.add(TextSpan(text: m.group(6), style: TextStyle(color: c.numero)));
        r.add(TextSpan(text: m.group(7), style: TextStyle(color: c.puntuacion)));
        r.add(TextSpan(text: m.group(8), style: TextStyle(color: c.cadena)));
      } else {
        r.add(TextSpan(text: m.group(9), style: TextStyle(color: c.puntuacion)));
      }
      ultimo = m.end;
    }
    if (ultimo < t.length) r.add(TextSpan(text: t.substring(ultimo)));
    return r;
  }
}

class _Colores {
  _Colores(bool oscuro)
      : clave = oscuro ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5),
        cadena = oscuro ? const Color(0xFFCE9178) : const Color(0xFFA31515),
        numero = oscuro ? const Color(0xFFB5CEA8) : const Color(0xFF098658),
        palabra = oscuro ? const Color(0xFF569CD6) : const Color(0xFF0000FF),
        comentario = oscuro ? const Color(0xFF6A9955) : const Color(0xFF008000),
        puntuacion = oscuro ? const Color(0xFFD4D4D4) : const Color(0xFF555555);

  final Color clave, cadena, numero, palabra, comentario, puntuacion;
}
