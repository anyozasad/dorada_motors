import '../models/producto.dart';

/// Verifica el carrito contra la última lectura de MySQL antes de confirmar.
class CheckoutValidator {
  static String? verificar({
    required Map<int, int> carrito,
    required List<Producto> productosMostrados,
    required List<dynamic> catalogoServidor,
  }) {
    if (carrito.isEmpty) return 'El carrito está vacío.';

    final productosPorId = <int, Producto>{
      for (final producto in productosMostrados) producto.id: producto,
    };
    final estadoServidor = <int, Map<String, dynamic>>{};
    for (final raw in catalogoServidor) {
      if (raw is! Map) continue;
      final producto = Map<String, dynamic>.from(raw);
      final id = int.tryParse(producto['id_producto']?.toString() ?? '') ?? 0;
      if (id > 0) estadoServidor[id] = producto;
    }

    for (final entry in carrito.entries) {
      final mostrado = productosPorId[entry.key];
      if (entry.key <= 0 || entry.value <= 0 || mostrado == null) {
        return 'El carrito contiene un artículo inválido. Regresa al catálogo.';
      }
      final actual = estadoServidor[entry.key];
      if (actual == null) {
        return 'El producto ${mostrado.nombre} ya no está disponible. '
            'Actualiza el catálogo antes de continuar.';
      }
      final stock = int.tryParse(actual['stock']?.toString() ?? '') ?? 0;
      if (stock < entry.value) {
        return 'Stock actualizado de ${mostrado.nombre}: '
            'solo quedan $stock unidades. Ajusta tu carrito.';
      }
      final precioBase =
          double.tryParse(actual['precio']?.toString() ?? '') ?? -1.0;
      if (precioBase < 0) {
        return 'No se pudo confirmar el precio de ${mostrado.nombre}. '
            'Actualiza el catálogo.';
      }
      final precioOferta =
          double.tryParse(actual['precio_oferta']?.toString() ?? '');
      final precioActual = precioOferta != null &&
              precioOferta > 0 &&
              precioOferta < precioBase
          ? precioOferta
          : precioBase;
      if ((precioActual - mostrado.precioFinal).abs() >= 0.01) {
        return 'El precio de ${mostrado.nombre} cambió a '
            'S/ ${precioActual.toStringAsFixed(2)}. '
            'Actualiza el catálogo y revisa el total.';
      }
    }
    return null;
  }
}
