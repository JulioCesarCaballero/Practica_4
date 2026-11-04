import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../data/entrada.dart';
import '../data/preferencias.dart';
import '../data/tipos.dart';
import 'acciones.dart';

/// Historial de archivos recientes (persistente).
class ListaRecientes extends StatelessWidget {
  const ListaRecientes({super.key, required this.onAbrir});

  final void Function(Entrada) onAbrir;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferencias,
      builder: (context, _) {
        final lista = preferencias.recientes;
        if (lista.isEmpty) {
          return const _Vacio(icono: Icons.history, texto: 'Todavía no has abierto archivos');
        }
        return Column(children: [
          ListTile(
            title: Text('${lista.length} archivo(s) reciente(s)'),
            trailing: TextButton.icon(
              onPressed: () async {
                if (await confirmar(context, 'Limpiar historial', 'Se borrará la lista de recientes.',
                    accion: 'Limpiar')) {
                  await preferencias.limpiarRecientes();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Limpiar'),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final e = lista[i];
                return Dismissible(
                  key: ValueKey('r_${e.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => preferencias.quitarReciente(e),
                  child: ListTile(
                    leading: Icon(iconoDe(e)),
                    title: Text(e.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(e.origen == Origen.saf ? 'Documento autorizado' : 'Almacenamiento de la app'),
                    onTap: () => onAbrir(e),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

/// Favoritos persistentes (archivos y carpetas).
class ListaFavoritos extends StatelessWidget {
  const ListaFavoritos({super.key, required this.onAbrir, required this.onAbrirCarpeta});

  final void Function(Entrada) onAbrir;
  final void Function(Entrada) onAbrirCarpeta;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferencias,
      builder: (context, _) {
        final lista = preferencias.favoritos;
        if (lista.isEmpty) {
          return const _Vacio(
            icono: Icons.star_border,
            texto: 'Sin favoritos.\nUsa el menú ⋮ de un archivo o carpeta para agregarlo.',
          );
        }
        return ListView.builder(
          itemCount: lista.length,
          itemBuilder: (context, i) {
            final e = lista[i];
            return ListTile(
              leading: Icon(iconoDe(e), color: e.esCarpeta ? Theme.of(context).colorScheme.primary : null),
              title: Text(e.nombre),
              subtitle: Text(e.esCarpeta ? 'Carpeta' : tamanoLegible(e.tamano)),
              onTap: () => e.esCarpeta ? onAbrirCarpeta(e) : onAbrir(e),
              trailing: IconButton(
                tooltip: 'Quitar de favoritos',
                icon: const Icon(Icons.star),
                onPressed: () => preferencias.alternarFavorito(e),
              ),
            );
          },
        );
      },
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center),
        ]),
      );
}
