import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../data/repositorio.dart';
import '../data/serializacion.dart';
import 'resaltado.dart';

/// Muestra el contenido real del archivo de guardado con resaltado de sintaxis.
class PantallaVerArchivo extends StatelessWidget {
  const PantallaVerArchivo({super.key, required this.resumen});

  final ResumenPartida resumen;

  Future<String> _leer() async {
    final bytes = await resumen.archivo.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    final lenguaje = switch (resumen.formato) {
      FormatoGuardado.json => Lenguaje.json,
      FormatoGuardado.xml => Lenguaje.xml,
      FormatoGuardado.txt => Lenguaje.texto,
    };
    return Scaffold(
      appBar: AppBar(title: Text(resumen.nombreArchivo)),
      body: Column(children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('${resumen.formato.etiqueta} · ${tamanoLegible(resumen.tamano)}'),
          subtitle: Text('Modificado: ${fechaLegible(resumen.modificado)}\n${resumen.archivo.path}'),
          isThreeLine: true,
        ),
        if (!resumen.valida)
          MaterialBanner(
            leading: const Icon(Icons.error_outline),
            content: Text('Archivo dañado: ${resumen.error}'),
            actions: const [SizedBox.shrink()],
          ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<String>(
            future: _leer(),
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (s.hasError) return Center(child: Text(mensajeError(s.error!)));
              final texto = s.data!;
              if (texto.isEmpty) return const Center(child: Text('(archivo vacío)'));
              return CodigoResaltado(texto: texto, lenguaje: lenguaje);
            },
          ),
        ),
      ]),
    );
  }
}
