class PedidoItem {
  final int productoId;
  final String nombre;
  final int cantidad;
  final double precio;

  const PedidoItem({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });

  double get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'nombre': nombre,
        'cantidad': cantidad,
        'precio': precio,
      };

  factory PedidoItem.fromJson(Map<String, dynamic> json) => PedidoItem(
        productoId: json['productoId'] as int,
        nombre: json['nombre'] as String,
        cantidad: json['cantidad'] as int,
        precio: (json['precio'] as num).toDouble(),
      );
}

class Pedido {
  final String id;
  final DateTime fecha;
  final String estado;
  final String metodoPago;
  final String tipoEntrega;
  final String direccion;
  final String telefono;
  final double total;
  final List<PedidoItem> items;

  const Pedido({
    required this.id,
    required this.fecha,
    required this.estado,
    required this.metodoPago,
    required this.tipoEntrega,
    required this.direccion,
    required this.telefono,
    required this.total,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fecha': fecha.toIso8601String(),
        'estado': estado,
        'metodoPago': metodoPago,
        'tipoEntrega': tipoEntrega,
        'direccion': direccion,
        'telefono': telefono,
        'total': total,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Pedido.fromJson(Map<String, dynamic> json) => Pedido(
        id: json['id'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        estado: json['estado'] as String,
        metodoPago: json['metodoPago'] as String,
        tipoEntrega: json['tipoEntrega'] as String,
        direccion: json['direccion'] as String,
        telefono: json['telefono'] as String,
        total: (json['total'] as num).toDouble(),
        items: (json['items'] as List<dynamic>)
            .map((e) => PedidoItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
