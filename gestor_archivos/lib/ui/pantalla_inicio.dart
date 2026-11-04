import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/entrada.dart';
import '../data/preferencias.dart';
import '../data/tipos.dart';
import 'acciones.dart';
import 'ajustes.dart';
import 'explorador.dart';
import 'listas.dart';
import 'visor.dart';

/// Pantalla principal responsiva.
///  - Angosta (teléfono vertical): NavigationBar inferior y visor a pantalla completa.
///  - Amplia (tableta / horizontal): NavigationRail lateral y visor en un panel a la derecha.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  static const _anchoAmplio = 840.0;
  final _explorador = GlobalKey<ExploradorState>();
  int _seccion = 0;
  Entrada? _seleccionado;
  bool _amplio = false;

  static const _destinos = [
    (Icons.folder_outlined, Icons.folder, 'Explorar'),
    (Icons.history, Icons.history, 'Recientes'),
    (Icons.star_border, Icons.star, 'Favoritos'),
    (Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  void _abrir(Entrada e) {
    if (!e.esCarpeta) preferencias.agregarReciente(e);
    if (tipoDe(e) == TipoVista.noSoportado) {
      dialogoNoSoportado(context, e);
      return;
    }
    if (_amplio) {
      setState(() => _seleccionado = e);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaVisor(entrada: e)));
    }
  }

  void _abrirCarpeta(Entrada c) {
    setState(() => _seccion = 0);
    _explorador.currentState?.abrirCarpeta(c, reiniciar: true);
  }

  void _atras() {
    if (_seccion == 0 && (_explorador.currentState?.regresar() ?? false)) return;
    if (_seccion != 0) {
      setState(() => _seccion = 0);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, restricciones) {
      _amplio = restricciones.maxWidth >= _anchoAmplio;
      final contenido = IndexedStack(
        index: _seccion,
        children: [
          Explorador(key: _explorador, onAbrirArchivo: _abrir),
          ListaRecientes(onAbrir: _abrir),
          ListaFavoritos(onAbrir: _abrir, onAbrirCarpeta: _abrirCarpeta),
          const PantallaAjustes(),
        ],
      );

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _atras();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_seccion == 0 ? 'Gestor de archivos ESCOM' : _destinos[_seccion].$3),
          ),
          body: _amplio ? _cuerpoAmplio(contenido) : contenido,
          bottomNavigationBar: _amplio
              ? null
              : NavigationBar(
                  selectedIndex: _seccion,
                  onDestinationSelected: (i) => setState(() => _seccion = i),
                  destinations: [
                    for (final d in _destinos)
                      NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
                  ],
                ),
        ),
      );
    });
  }

  Widget _cuerpoAmplio(Widget contenido) {
    final conPanel = _seccion != 3;
    return Row(children: [
      NavigationRail(
        selectedIndex: _seccion,
        onDestinationSelected: (i) => setState(() => _seccion = i),
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (final d in _destinos)
            NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
        ],
      ),
      const VerticalDivider(width: 1),
      Expanded(flex: 5, child: contenido),
      if (conPanel) ...[
        const VerticalDivider(width: 1),
        Expanded(
          flex: 6,
          child: _seleccionado == null
              ? const Center(child: Text('Selecciona un archivo para verlo aquí'))
              : PanelVisor(
                  entrada: _seleccionado!,
                  onCerrar: () => setState(() => _seleccionado = null),
                ),
        ),
      ],
    ]);
  }
}
