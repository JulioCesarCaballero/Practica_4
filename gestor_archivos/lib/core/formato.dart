/// Utilidades de formato para mostrar metadatos.
String tamanoLegible(int? bytes) {
  if (bytes == null) return 'No disponible';
  const unidades = ['B', 'KB', 'MB', 'GB', 'TB'];
  double valor = bytes.toDouble();
  var i = 0;
  while (valor >= 1024 && i < unidades.length - 1) {
    valor /= 1024;
    i++;
  }
  return i == 0 ? '$bytes B' : '${valor.toStringAsFixed(1)} ${unidades[i]}';
}

String _dos(int n) => n.toString().padLeft(2, '0');

String fechaLegible(DateTime? fecha) {
  if (fecha == null) return 'No disponible';
  final f = fecha.toLocal();
  return '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';
}
