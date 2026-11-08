class Producto {
  final int id;
  final String nombre;
  final String descripcion;
  final String marca;
  final String categoria;
  final String tipoVehiculo;
  final String compatibilidad;
  final double precio;
  final double? precioOferta;
  final int stock;
  final String imagen;

  const Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.marca,
    required this.categoria,
    required this.tipoVehiculo,
    required this.compatibilidad,
    required this.precio,
    this.precioOferta,
    required this.stock,
    required this.imagen,
  });

  double get precioFinal => precioOferta ?? precio;
  bool get disponible => stock > 0;
}
