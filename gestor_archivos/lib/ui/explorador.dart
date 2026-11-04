import 'package:flutter/material.dart';

import '../core/errores.dart';
import '../core/formato.dart';
import '../data/archivos.dart';
import '../data/entrada.dart';
import '../data/preferencias.dart';
import '../data/tipos.dart';
import '../platform/saf_android.dart';
import 'acciones.dart';
import 'miniaturas.dart';
import 'selector_destino.dart';

enum _Accion { abrir, detalles, favorito, renombrar, copiar, mover, eliminar, compartir, exportar, importar }

/// Explorador de archivos con breadcrumbs.
///
/// Con la pila vacía muestra "Ubicaciones": el almacenamiento privado de la app
/// y las carpetas que el usuario autorizó con el selector del sistema (SAF).
class Explorador extends StatefulWidget {
  const Explorador({super.key, required this.onAbrirArchivo});

  final void Function(Entrada archivo) onAbrirArchivo;

  @override
  State<Explorador> createState() => ExploradorState();
}

class ExploradorState extends State<Explorador> {
  final List<Entrada> _pila = [];
  List<Entrada> _elementos = [];
  List<Entrada> _autorizadas = [];
  bool _cargando = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  // ------------------------------------------------------------------ navegación

  /// Abre una carpeta. Si [reiniciar] es true, la carpeta pasa a ser la raíz del breadcrumb.
  void abrirCarpeta(Entrada carpeta, {bool reiniciar = false}) {
    setState(() {
      if (reiniciar) _pila.clear();
      _pila.add(carpeta);
    });
    _recargar();
  }

  /// Regresa un nivel. Devuelve false si ya está en "Ubicaciones".
  bool regresar() {
    if (_pila.isEmpty) return false;
    setState(() => _pila.removeLast());
    _recargar();
    return true;
  }

  void _irA(int indice) {
    setState(() => _pila.removeRange(indice + 1, _pila.length));
    _recargar();
  }

  void _irAUbicaciones() {
    setState(_pila.clear);
    _recargar();
  }

  Future<void> _recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (_pila.isEmpty) {
        final lista = await SafAndroid.carpetasAutorizadas();
        if (!mounted) return;
        setState(() => _autorizadas = lista);
      } else {
        final lista = await Archivos.listar(_pila.last);
        if (!mounted) return;
        setState(() => _elementos = lista);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ------------------------------------------------------------------ SAF

  Future<bool> _explicar(String titulo, String texto) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined),
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _autorizarCarpeta() async {
    final ok = await _explicar(
      'Autorizar una carpeta',
      'Android abrirá su selector de archivos. Elige una carpeta y toca "Usar esta carpeta".\n\n'
          'La app solo podrá ver y modificar esa carpeta (y sus subcarpetas). '
          'No se pide acceso a todo el almacenamiento y puedes quitar el permiso cuando quieras.',
    );
    if (!ok || !mounted) return;
    try {
      final carpeta = await SafAndroid.elegirCarpeta();
      if (!mounted) return;
      if (carpeta == null) {
        mostrarMensaje(context, 'Selección cancelada: no se concedió ningún acceso.');
        return;
      }
      mostrarMensaje(context, 'Acceso concedido a "${carpeta.nombre}".');
      abrirCarpeta(carpeta, reiniciar: true);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
    }
  }

  Future<void> _abrirArchivoSuelto() async {
    final ok = await _explicar(
      'Abrir un archivo',
      'Android abrirá su selector para que elijas un archivo. '
          'La app solo tendrá acceso al archivo que elijas.',
    );
    if (!ok || !mounted) return;
    try {
      final archivo = await SafAndroid.elegirArchivo();
      if (!mounted) return;
      if (archivo == null) {
        mostrarMensaje(context, 'Selección cancelada.');
        return;
      }
      widget.onAbrirArchivo(archivo);
    } catch (e) {
      if (mounted) mostrarMensaje(context, mensajeError(e), error: true);
    }
  }

  Future<void> _quitarAcceso(Entrada carpeta) async {
    final ok = await confirmar(context, 'Quitar acceso',
        'La app ya no podrá ver "${carpeta.nombre}". Los archivos no se borran.',
        accion: 'Quitar acceso');
    if (!ok || !mounted) return;
    final hecho = await ejecutarConProgreso(context, () async {
      await SafAndroid.quitarAcceso(carpeta);
      await preferencias.olvidar(carpeta);
    }, exito: 'Acceso retirado.');
    if (hecho) _recargar();
  }

  // ------------------------------------------------------------------ acciones

  Future<void> _accion(_Accion a, Entrada e) async {
    switch (a) {
      case _Accion.abrir:
        _abrir(e);
      case _Accion.detalles:
        await mostrarDetalles(context, e);
      case _Accion.favorito:
        await preferencias.alternarFavorito(e);
        if (mounted) {
          mostrarMensaje(context, preferencias.esFavorito(e) ? 'Agregado a favoritos.' : 'Quitado de favoritos.');
        }
      case _Accion.compartir:
        await compartirArchivo(context, e);
      case _Accion.exportar:
        await exportarArchivo(context, e);
      case _Accion.importar:
        await _importar(e);
      case _Accion.renombrar:
        await _renombrar(e);
      case _Accion.copiar:
        await _copiarOMover(e, mover: false);
      case _Accion.mover:
        await _copiarOMover(e, mover: true);
      case _Accion.eliminar:
        await _eliminar(e);
    }
  }

  Future<void> _importar(Entrada e) async {
    String nombre = '';
    final ok = await ejecutarConProgreso(context, () async {
      nombre = await Archivos.importar(e);
    });
    if (ok && mounted) mostrarMensaje(context, 'Copiado al almacenamiento de la app como "$nombre".');
  }

  Future<void> _renombrar(Entrada e) async {
    if (e.origen == Origen.saf && !e.puedeRenombrar) {
      mostrarMensaje(context, 'Operación no permitida: el proveedor no permite renombrar.', error: true);
      return;
    }
    final nuevo = await pedirTexto(context, 'Renombrar', inicial: e.nombre);
    if (nuevo == null || nuevo.trim() == e.nombre || !mounted) return;
    final ok = await ejecutarConProgreso(context, () async {
      await Archivos.renombrar(e, nuevo);
      await preferencias.olvidar(e);
    }, exito: 'Renombrado a "${nuevo.trim()}".');
    if (ok) _recargar();
  }

  Future<void> _copiarOMover(Entrada e, {required bool mover}) async {
    if (mover && e.origen == Origen.saf && !e.puedeEliminar) {
      mostrarMensaje(context, 'Operación no permitida: el proveedor no permite mover este archivo.', error: true);
      return;
    }
    final destino = await elegirDestino(
        context, _pila, mover ? 'Mover "${e.nombre}" a…' : 'Copiar "${e.nombre}" a…');
    if (destino == null || !mounted) return;
    final padre = _pila.last;
    final ok = await ejecutarConProgreso(context, () async {
      if (mover) {
        await Archivos.mover(e, padre, destino);
        await preferencias.olvidar(e);
      } else {
        await Archivos.copiar(e, destino);
      }
    }, exito: mover ? 'Movido a "${destino.nombre}".' : 'Copiado a "${destino.nombre}".');
    if (ok) _recargar();
  }

  Future<void> _eliminar(Entrada e) async {
    if (e.origen == Origen.saf && !e.puedeEliminar) {
      mostrarMensaje(context, 'Operación no permitida: el proveedor no permite eliminar.', error: true);
      return;
    }
    final ok = await confirmar(
      context,
      '¿Eliminar "${e.nombre}"?',
      e.esCarpeta
          ? 'Se eliminará la carpeta y todo su contenido. Esta acción no se puede deshacer.'
          : 'Esta acción no se puede deshacer.',
    );
    if (!ok || !mounted) return;
    final hecho = await ejecutarConProgreso(context, () async {
      await Archivos.eliminar(e);
      await preferencias.olvidar(e);
    }, exito: 'Eliminado.');
    if (hecho) _recargar();
  }

  void _abrir(Entrada e) {
    if (e.esCarpeta) {
      abrirCarpeta(e);
    } else {
      widget.onAbrirArchivo(e);
    }
  }

  Future<void> _nuevo() async {
    final carpeta = _pila.last;
    if (carpeta.origen == Origen.saf && !carpeta.puedeCrear) {
      mostrarMensaje(context, 'Operación no permitida: esta carpeta no admite escritura.', error: true);
      return;
    }
    final opcion = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder),
            title: const Text('Nueva carpeta'),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            leading: const Icon(Icons.note_add),
            title: const Text('Nuevo archivo de texto'),
            onTap: () => Navigator.pop(ctx, 1),
          ),
        ]),
      ),
    );
    if (opcion == null || !mounted) return;
    if (opcion == 0) {
      final nombre = await pedirTexto(context, 'Nueva carpeta');
      if (nombre == null || !mounted) return;
      final ok = await ejecutarConProgreso(context, () => Archivos.crearCarpeta(carpeta, nombre),
          exito: 'Carpeta creada.');
      if (ok) _recargar();
    } else {
      final nombre = await pedirTexto(context, 'Nuevo archivo de texto', inicial: 'nota.txt');
      if (nombre == null || !mounted) return;
      final texto = await pedirTexto(context, 'Contenido', etiqueta: 'Texto', lineas: 6);
      if (texto == null || !mounted) return;
      final ok = await ejecutarConProgreso(context, () => Archivos.crearArchivoTexto(carpeta, nombre, texto),
          exito: 'Archivo creado.');
      if (ok) _recargar();
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _breadcrumbs(),
          if (_cargando) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
          Expanded(child: _pila.isEmpty ? _ubicaciones() : _listado()),
        ],
      ),
      floatingActionButton: _pila.isEmpty
          ? null
          : FloatingActionButton(
              tooltip: 'Crear',
              onPressed: _nuevo,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _breadcrumbs() {
    final esquema = Theme.of(context).colorScheme;
    final partes = <Widget>[
      ActionChip(
        avatar: const Icon(Icons.home_outlined, size: 18),
        label: const Text('Ubicaciones'),
        onPressed: _pila.isEmpty ? null : _irAUbicaciones,
      ),
    ];
    for (var i = 0; i < _pila.length; i++) {
      final ultimo = i == _pila.length - 1;
      partes.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right, size: 18),
      ));
      partes.add(ActionChip(
        label: Text(_pila[i].nombre, style: ultimo ? const TextStyle(fontWeight: FontWeight.bold) : null),
        backgroundColor: ultimo ? esquema.secondaryContainer : null,
        onPressed: ultimo ? null : () => _irA(i),
      ));
    }
    return Material(
      color: esquema.surfaceContainerLow,
      child: SizedBox(
        height: 52,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // mantiene visible la carpeta actual
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            if (_pila.isNotEmpty)
              IconButton(tooltip: 'Atrás', icon: const Icon(Icons.arrow_back), onPressed: regresar),
            ...partes,
          ]),
        ),
      ),
    );
  }

  Widget _ubicaciones() {
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android, size: 32),
              title: const Text('Almacenamiento de la app'),
              subtitle: const Text('Espacio privado. No requiere permisos.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => abrirCarpeta(Archivos.entradaRaizLocal, reiniciar: true),
            ),
          ),
          const SizedBox(height: 16),
          Text('Carpetas autorizadas', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Carpetas que elegiste con el selector de Android (Storage Access Framework).',
              style: t.bodySmall),
          const SizedBox(height: 8),
          if (_error != null)
            Card(child: ListTile(leading: const Icon(Icons.error_outline), title: Text(mensajeError(_error!)))),
          if (_autorizadas.isEmpty && _error == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.folder_off_outlined),
                title: Text('Aún no has autorizado ninguna carpeta'),
              ),
            ),
          for (final c in _autorizadas)
            Card(
              child: ListTile(
                leading: Icon(c.disponible ? Icons.folder_shared : Icons.folder_off,
                    color: c.disponible ? null : Theme.of(context).colorScheme.error),
                title: Text(c.nombre),
                subtitle: Text(c.disponible
                    ? (c.puedeCrear ? 'Lectura y escritura' : 'Solo lectura')
                    : 'No disponible: la carpeta se movió, se eliminó o el permiso fue revocado'),
                onTap: c.disponible ? () => abrirCarpeta(c, reiniciar: true) : null,
                trailing: IconButton(
                  tooltip: 'Quitar acceso',
                  icon: const Icon(Icons.link_off),
                  onPressed: () => _quitarAcceso(c),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _autorizarCarpeta,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Autorizar una carpeta…'),
            ),
            OutlinedButton.icon(
              onPressed: _abrirArchivoSuelto,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Abrir un archivo…'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _listado() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(mensajeError(_error!), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: _recargar, child: const Text('Reintentar')),
              OutlinedButton(onPressed: _irAUbicaciones, child: const Text('Ir a Ubicaciones')),
            ]),
          ]),
        ),
      );
    }
    if (_elementos.isEmpty && !_cargando) {
      return RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(children: const [
          SizedBox(height: 120),
          Icon(Icons.folder_open, size: 56),
          SizedBox(height: 8),
          Center(child: Text('Carpeta vacía')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListenableBuilder(
        listenable: preferencias,
        builder: (context, _) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: _elementos.length,
          itemBuilder: (context, i) => _fila(_elementos[i]),
        ),
      ),
    );
  }

  Widget _fila(Entrada e) {
    final fav = preferencias.esFavorito(e);
    final detalle = e.esCarpeta ? 'Carpeta' : tamanoLegible(e.tamano);
    return ListTile(
      leading: _icono(e),
      title: Text(e.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$detalle · ${fechaLegible(e.modificado)}'),
      onTap: () => _abrir(e),
      onLongPress: () => mostrarDetalles(context, e),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (fav) const Icon(Icons.star, size: 18),
        PopupMenuButton<_Accion>(
          onSelected: (a) => _accion(a, e),
          itemBuilder: (_) => [
            _item(_Accion.abrir, Icons.open_in_new, 'Abrir'),
            _item(_Accion.detalles, Icons.info_outline, 'Detalles'),
            _item(_Accion.favorito, fav ? Icons.star : Icons.star_border, fav ? 'Quitar de favoritos' : 'Favorito'),
            const PopupMenuDivider(),
            _item(_Accion.renombrar, Icons.drive_file_rename_outline, 'Renombrar',
                permitido: e.esLocal || e.puedeRenombrar),
            if (e.esLocal || !e.esCarpeta) _item(_Accion.copiar, Icons.copy, 'Copiar a…'),
            if (e.esLocal || !e.esCarpeta)
              _item(_Accion.mover, Icons.drive_file_move_outline, 'Mover a…', permitido: e.esLocal || e.puedeEliminar),
            _item(_Accion.eliminar, Icons.delete_outline, 'Eliminar', permitido: e.esLocal || e.puedeEliminar),
            if (!e.esCarpeta) ...[
              const PopupMenuDivider(),
              _item(_Accion.compartir, Icons.share, 'Compartir'),
              _item(_Accion.exportar, Icons.save_alt, 'Exportar copia…'),
              if (e.origen == Origen.saf) _item(_Accion.importar, Icons.download, 'Importar a la app'),
            ],
          ],
        ),
      ]),
    );
  }

  /// Los elementos no permitidos se muestran atenuados; al tocarlos se explica por qué.
  PopupMenuItem<_Accion> _item(_Accion a, IconData icono, String texto, {bool permitido = true}) {
    final color = permitido ? null : Theme.of(context).disabledColor;
    return PopupMenuItem<_Accion>(
      value: a,
      child: ListTile(
        dense: true,
        leading: Icon(icono, color: color),
        title: Text(permitido ? texto : '$texto (no permitido)', style: TextStyle(color: color)),
      ),
    );
  }

  Widget _icono(Entrada e) {
    if (!e.esCarpeta && e.esLocal && tipoDe(e) == TipoVista.imagen) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image(
          image: CacheMiniaturas.obtener(e.id, e.modificado),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44, child: Icon(Icons.broken_image)),
        ),
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: Icon(iconoDe(e), size: 30, color: e.esCarpeta ? Theme.of(context).colorScheme.primary : null),
    );
  }
}
