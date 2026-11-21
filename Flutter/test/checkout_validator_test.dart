import 'package:dorada_motors/models/producto.dart';
import 'package:dorada_motors/services/checkout_validator.dart';
import 'package:flutter_test/flutter_test.dart';

const producto = Producto(
  id: 12,
  nombre: 'Kit transmisión DTiex',
  descripcion: 'Repuesto',
  marca: 'DTiex',
  categoria: 'Transmisión',
  tipoVehiculo: 'Motocicleta',
  compatibilidad: '125cc',
  precio: 80,
  precioOferta: 70,
  stock: 5,
  imagen: '',
);

Map<String, dynamic> servidor({
  int stock = 5,
  double precio = 80,
  double? precioOferta = 70,
}) => {
  'id_producto': 12,
  'stock': stock,
  'precio': precio,
  'precio_oferta': precioOferta,
};

String? comprobar(Map<int, int> cart, List<dynamic> items) =>
    CheckoutValidator.verificar(
      carrito: cart,
      productosMostrados: [producto],
      catalogoServidor: items,
    );

void main() {
  test('Compra válida con precio y existencias actualizadas', () {
    expect(comprobar({12: 2}, [servidor()]), isNull);
  });

  test('No permite comprar más unidades que las actuales de MySQL', () {
    expect(comprobar({12: 4}, [servidor(stock: 2)]), contains('solo quedan 2'));
  });

  test('No permite comprar un producto eliminado del catálogo', () {
    expect(comprobar({12: 1}, []), contains('ya no está disponible'));
  });

  test('Recalcula precio de oferta con las reglas usadas en PHP', () {
    expect(
      comprobar({12: 1}, [servidor(precioOferta: 65)]),
      contains('S/ 65.00'),
    );
    expect(
      comprobar({12: 1}, [servidor(precioOferta: 95)]),
      contains('S/ 80.00'),
    );
  });

  test('Rechaza productos con precio inválido, cantidades cero y carrito vacío', () {
    expect(comprobar({12: 1}, [servidor(precio: -4, precioOferta: null)]),
        contains('No se pudo confirmar el precio'));
    expect(comprobar({12: 0}, [servidor()]), contains('artículo inválido'));
    expect(comprobar({}, [servidor()]), contains('carrito está vacío'));
  });

  test('Valida todas las líneas, no solo el primer producto', () {
    expect(
      CheckoutValidator.verificar(
        carrito: {12: 1, 14: 1},
        productosMostrados: [
          producto,
          const Producto(
            id: 14, nombre: 'Pastillas freno',
            descripcion: '', marca: 'BJR', categoria: 'Frenos',
            tipoVehiculo: 'Motocicleta', compatibilidad: '150cc',
            precio: 20, stock: 5, imagen: '',
          ),
        ],
        catalogoServidor: [servidor()],
      ),
      contains('Pastillas freno ya no está disponible'),
    );
  });
}
