import 'package:path/path.dart' as p;

/// De dónde viene un archivo o carpeta.
enum Origen {
  /// Almacenamiento privado de la app (dart:io).
  local,

  /// Documento autorizado por el usuario con el selector del sistema (SAF en Android).
  saf,
}

/// Representa un archivo o una carpeta, sin importar su origen.
class Entrada {
  const Entrada({
    required this.id,
    required this.nombre,
    required this.esCarpeta,
    required this.origen,
    this.tamano,
    this.modificado,
    this.creado,
    this.mime,
    this.raiz,
    this.puedeEscribir = true,
    this.puedeEliminar = true,
    this.puedeRenombrar = true,
    this.puedeCrear = true,
    this.disponible = true,
  });

  /// Ruta absoluta (origen local) o URI del documento (origen SAF).
  final String id;
  final String nombre;
  final bool esCarpeta;
  final Origen origen;
  final int? tamano;
  final DateTime? modificado;

  /// Android no expone la fecha de creación; normalmente es null ("No disponible").
  final DateTime? creado;
  final String? mime;

  /// URI raíz de la carpeta autorizada a la que pertenece (solo SAF).
  final String? raiz;

  // Capacidades informadas por el proveedor de documentos.
  final bool puedeEscribir;
  final bool puedeEliminar;
  final bool puedeRenombrar;
  final bool puedeCrear;
  final bool disponible;

  bool get esLocal => origen == Origen.local;

  String get extension {
    final ext = p.extension(nombre).toLowerCase();
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  /// Construye una entrada a partir del mapa que devuelve el código Kotlin.
  factory Entrada.desdeSaf(Map<dynamic, dynamic> m) {
    final mod = m['modificado'];
    return Entrada(
      id: m['uri'] as String,
      nombre: (m['nombre'] as String?) ?? '(sin nombre)',
      esCarpeta: m['esCarpeta'] == true,
      origen: Origen.saf,
      tamano: (m['tamano'] as num?)?.toInt(),
      modificado: mod is num && mod > 0 ? DateTime.fromMillisecondsSinceEpoch(mod.toInt()) : null,
      mime: m['mime'] as String?,
      raiz: m['raiz'] as String?,
      puedeEscribir: m['puedeEscribir'] == true,
      puedeEliminar: m['puedeEliminar'] == true,
      puedeRenombrar: m['puedeRenombrar'] == true,
      puedeCrear: m['puedeCrear'] == true,
      disponible: m['disponible'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'esCarpeta': esCarpeta,
        'origen': origen.name,
        'tamano': tamano,
        'modificado': modificado?.millisecondsSinceEpoch,
        'mime': mime,
        'raiz': raiz,
        'puedeEscribir': puedeEscribir,
        'puedeEliminar': puedeEliminar,
        'puedeRenombrar': puedeRenombrar,
        'puedeCrear': puedeCrear,
      };

  factory Entrada.fromJson(Map<String, dynamic> j) => Entrada(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        esCarpeta: j['esCarpeta'] == true,
        origen: j['origen'] == 'saf' ? Origen.saf : Origen.local,
        tamano: (j['tamano'] as num?)?.toInt(),
        modificado: j['modificado'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((j['modificado'] as num).toInt()),
        mime: j['mime'] as String?,
        raiz: j['raiz'] as String?,
        puedeEscribir: j['puedeEscribir'] != false,
        puedeEliminar: j['puedeEliminar'] != false,
        puedeRenombrar: j['puedeRenombrar'] != false,
        puedeCrear: j['puedeCrear'] != false,
      );

  @override
  bool operator ==(Object other) => other is Entrada && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
