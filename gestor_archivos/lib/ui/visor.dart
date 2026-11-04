import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../core/errores.dart';
import '../data/archivos.dart';
import '../data/entrada.dart';
import '../data/preferencias.dart';
import '../data/tipos.dart';
import 'acciones.dart';
import 'resaltado.dart';

/// Pantalla completa para ver un archivo (teléfonos / pantallas angostas).
class PantallaVisor extends StatelessWidget {
  const PantallaVisor({super.key, required this.entrada});

  final Entrada entrada;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entrada.nombre, overflow: TextOverflow.ellipsis),
        actions: accionesVisor(context, entrada),
      ),
      body: ContenidoArchivo(key: ValueKey(entrada.id), entrada: entrada),
    );
  }
}

/// Panel lateral del visor (tabletas / modo horizontal).
class PanelVisor extends StatelessWidget {
  const PanelVisor({super.key, required this.entrada, required this.onCerrar});

  final Entrada entrada;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(iconoDe(entrada)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entrada.nombre,
                    overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ),
              ...accionesVisor(context, entrada),
              IconButton(tooltip: 'Cerrar', icon: const Icon(Icons.close), onPressed: onCerrar),
            ],
          ),
        ),
        Expanded(child: ContenidoArchivo(key: ValueKey(entrada.id), entrada: entrada)),
      ],
    );
  }
}

List<Widget> accionesVisor(BuildContext context, Entrada e) => [
      ListenableBuilder(
        listenable: preferencias,
        builder: (context, _) {
          final fav = preferencias.esFavorito(e);
          return IconButton(
            tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
            icon: Icon(fav ? Icons.star : Icons.star_border),
            onPressed: () => preferencias.alternarFavorito(e),
          );
        },
      ),
      IconButton(tooltip: 'Detalles', icon: const Icon(Icons.info_outline), onPressed: () => mostrarDetalles(context, e)),
      PopupMenuButton<int>(
        onSelected: (v) {
          switch (v) {
            case 0:
              compartirArchivo(context, e);
            case 1:
              abrirConOtraApp(context, e);
            case 2:
              exportarArchivo(context, e);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.share), title: Text('Compartir'))),
          PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Abrir con…'))),
          PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.save_alt), title: Text('Exportar copia…'))),
        ],
      ),
    ];

class _Cargado {
  _Cargado({required this.tipo, required this.archivo, this.texto, this.aviso});
  final TipoVista tipo;
  final File archivo;
  final String? texto;
  final String? aviso;
}

/// Carga el archivo y elige el visor adecuado según su tipo.
class ContenidoArchivo extends StatefulWidget {
  const ContenidoArchivo({super.key, required this.entrada});

  final Entrada entrada;

  @override
  State<ContenidoArchivo> createState() => _ContenidoArchivoState();
}

class _ContenidoArchivoState extends State<ContenidoArchivo> {
  static const _limiteTexto = 2 * 1024 * 1024; // 2 MB
  late Future<_Cargado> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<_Cargado> _cargar() async {
    final tipo = tipoDe(widget.entrada);
    final archivo = await Archivos.archivoLegible(widget.entrada);
    if (tipo == TipoVista.imagen || tipo == TipoVista.noSoportado) {
      return _Cargado(tipo: tipo, archivo: archivo);
    }

    // Lectura de texto: tolera UTF-8 inválido y limita archivos enormes.
    final tamano = await archivo.length();
    String? aviso;
    List<int> bytes;
    if (tamano > _limiteTexto) {
      final raf = await archivo.open();
      bytes = await raf.read(_limiteTexto);
      await raf.close();
      aviso = 'Archivo grande: se muestran solo los primeros 2 MB.';
    } else {
      bytes = await archivo.readAsBytes();
    }
    var texto = utf8.decode(bytes, allowMalformed: true);

    if (tipo == TipoVista.json && aviso == null) {
      try {
        texto = const JsonEncoder.withIndent('  ').convert(jsonDecode(texto));
      } on FormatException catch (e) {
        aviso = 'JSON inválido (${e.message}). Se muestra el contenido original.';
      }
    } else if (tipo == TipoVista.xml && aviso == null) {
      try {
        texto = XmlDocument.parse(texto).toXmlString(pretty: true, indent: '  ');
      } catch (e) {
        aviso = 'XML inválido. Se muestra el contenido original.';
      }
    }
    return _Cargado(tipo: tipo, archivo: archivo, texto: texto, aviso: aviso);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Cargado>(
      future: _futuro,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return _error(s.error!);
        final c = s.data!;
        final Widget cuerpo = switch (c.tipo) {
          TipoVista.imagen => VisorImagen(archivo: c.archivo),
          TipoVista.json => CodigoResaltado(texto: c.texto!, lenguaje: Lenguaje.json),
          TipoVista.xml => CodigoResaltado(texto: c.texto!, lenguaje: Lenguaje.xml),
          TipoVista.texto => CodigoResaltado(texto: c.texto!, lenguaje: Lenguaje.texto),
          TipoVista.noSoportado => _noSoportado(),
        };
        if (c.aviso == null) return cuerpo;
        return Column(children: [
          MaterialBanner(
            content: Text(c.aviso!),
            leading: const Icon(Icons.warning_amber_rounded),
            actions: const [SizedBox.shrink()],
          ),
          Expanded(child: cuerpo),
        ]);
      },
    );
  }

  Widget _noSoportado() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(iconoDe(widget.entrada), size: 64),
            const SizedBox(height: 12),
            const Text('Este formato no se puede mostrar en la app.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => dialogoNoSoportado(context, widget.entrada),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Opciones'),
            ),
          ]),
        ),
      );

  Widget _error(Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text('No se pudo leer el archivo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(mensajeError(e), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              OutlinedButton(
                onPressed: () => setState(() => _futuro = _cargar()),
                child: const Text('Reintentar'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await preferencias.olvidar(widget.entrada);
                  if (mounted) mostrarMensaje(context, 'Se quitó de recientes y favoritos.');
                },
                child: const Text('Quitar de recientes/favoritos'),
              ),
            ]),
          ]),
        ),
      );
}

/// Visor de imágenes con zoom (pellizcar / doble toque) y rotación.
class VisorImagen extends StatefulWidget {
  const VisorImagen({super.key, required this.archivo});

  final File archivo;

  @override
  State<VisorImagen> createState() => _VisorImagenState();
}

class _VisorImagenState extends State<VisorImagen> {
  final _transformacion = TransformationController();
  int _giros = 0;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final m = _transformacion.value.clone()..scale(factor, factor);
    _transformacion.value = m;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: () => _transformacion.value = Matrix4.identity(),
            child: InteractiveViewer(
              transformationController: _transformacion,
              minScale: 0.5,
              maxScale: 8,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _giros,
                  child: Image.file(
                    widget.archivo,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('La imagen está dañada o el formato no es compatible.'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Card(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'Girar a la izquierda', icon: const Icon(Icons.rotate_left),
                  onPressed: () => setState(() => _giros = (_giros + 3) % 4)),
              IconButton(tooltip: 'Girar a la derecha', icon: const Icon(Icons.rotate_right),
                  onPressed: () => setState(() => _giros = (_giros + 1) % 4)),
              IconButton(tooltip: 'Alejar', icon: const Icon(Icons.zoom_out), onPressed: () => _zoom(0.8)),
              IconButton(tooltip: 'Acercar', icon: const Icon(Icons.zoom_in), onPressed: () => _zoom(1.25)),
              IconButton(tooltip: 'Restablecer', icon: const Icon(Icons.fit_screen),
                  onPressed: () => setState(() {
                        _giros = 0;
                        _transformacion.value = Matrix4.identity();
                      })),
            ]),
          ),
        ),
      ],
    );
  }
}
