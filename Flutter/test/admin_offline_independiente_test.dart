import 'package:flutter_test/flutter_test.dart';
import 'package:dorada_motors/services/admin_offline_repository.dart';
import 'package:dorada_motors/services/offline_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dashboard administrador guarda en SQLite sin laptop, conserva stock '
      'y protege el acceso', () async {
    const scope = 'admin-independiente-v1';
    await OfflineDatabase.limpiarScope(scope);
    try {
      expect(await AdminOfflineRepository.estaConfigurado(), false);
      await AdminOfflineRepository.crearAcceso('ClaveLocal2026!');
      expect(await AdminOfflineRepository.estaConfigurado(), true);
      expect(await AdminOfflineRepository.comprobarAcceso('OtraClave'), false);
      expect(await AdminOfflineRepository.comprobarAcceso('ClaveLocal2026!'), true);
      await expectLater(AdminOfflineRepository.crearAcceso('OtraClaveNueva'),
          throwsStateError);

      final catalogo = await AdminOfflineRepository.consultar('productos');
      final articulos = catalogo['items'] as List;
      expect(articulos.length, greaterThan(10));
      final producto = Map<String,dynamic>.from(articulos.first as Map);
      final idProducto = producto['id_producto'];
      final stockOriginal = (producto['stock'] as num).toInt();
      final precio = (producto['precio'] as num).toDouble();
      expect(stockOriginal, greaterThan(4));

      await AdminOfflineRepository.operar({
        'accion': 'cliente_guardar', 'id_usuario': 0,
        'nombres': 'Cliente', 'apellidos': 'Local',
        'correo': 'cliente-local@example.test', 'telefono': '987654321',
      });
      final clientes = (await AdminOfflineRepository.consultar('clientes'))
          ['items'] as List;
      expect(clientes, hasLength(1));
      final idCliente = (clientes.single as Map)['id_usuario'];
      await AdminOfflineRepository.operar({
        'accion': 'proveedor_guardar', 'id_proveedor': 0,
        'razon_social': 'Mayorista local', 'estado': 'Activo',
      });
      final proveedores =
          (await AdminOfflineRepository.consultar('proveedores'))['items']
          as List;
      final idProveedor = (proveedores.single as Map)['id_proveedor'];

      final venta = await AdminOfflineRepository.operar({
        'accion': 'pedido_manual', 'id_usuario': idCliente,
        'tipo_entrega': 'Recojo en tienda', 'metodo_pago': 'Efectivo',
        'items': [
          {'id_producto': idProducto, 'cantidad': 2},
        ],
      });
      expect(venta['estado'], true);
      final idPedido = venta['id_pedido'];
      var actualizado = (await AdminOfflineRepository.consultar('productos'))
          ['items'] as List;
      expect((actualizado.first as Map)['stock'], stockOriginal - 2);
      final detalle = await AdminOfflineRepository.consultar('pedido_detalle',
          id: idPedido);
      expect((detalle['lineas'] as List).length, 1);
      expect((detalle['pagos'] as List).single['estado_pago'], 'Pendiente');
      await expectLater(AdminOfflineRepository.operar({
        'accion': 'pedido_manual', 'id_usuario': idCliente,
        'tipo_entrega': 'Recojo en tienda', 'metodo_pago': 'Efectivo',
        'items': [{'id_producto': idProducto, 'cantidad': stockOriginal + 10}],
      }), throwsStateError);
      actualizado = (await AdminOfflineRepository.consultar('productos'))
          ['items'] as List;
      expect((actualizado.first as Map)['stock'], stockOriginal - 2);

      await AdminOfflineRepository.operar({
        'accion': 'pago_manual', 'id_pedido': idPedido,
        'monto': 5, 'metodo_pago': 'Yape', 'estado_pago': 'Pagado',
      });
      expect((await AdminOfflineRepository.consultar('pedido_detalle',
          id: idPedido))['pedido']['estado_pedido'],
          'Pendiente');
      await expectLater(AdminOfflineRepository.operar({
        'accion': 'pago_manual', 'id_pedido': idPedido,
        'monto': (venta['total'] as num).toDouble(),
        'metodo_pago': 'Plin', 'estado_pago': 'Pagado',
      }), throwsStateError);
      await AdminOfflineRepository.operar({
        'accion': 'pago_manual', 'id_pedido': idPedido,
        'monto': (venta['total'] as num).toDouble() - 5,
        'metodo_pago': 'Efectivo', 'estado_pago': 'Pagado',
      });
      expect((await AdminOfflineRepository.consultar('pedido_detalle',
          id: idPedido))['pedido']['estado_pedido'],
          'Pagado');
      await expectLater(AdminOfflineRepository.operar({
        'accion': 'pedido_cancelar', 'id_pedido': idPedido,
      }), throwsStateError);

      final compra = await AdminOfflineRepository.operar({
        'accion': 'compra_registrar', 'id_proveedor': idProveedor,
        'items': [{'id_producto': idProducto, 'cantidad': 3,
            'precio_compra': (precio / 2).toStringAsFixed(2)}],
      });
      actualizado = (await AdminOfflineRepository.consultar('productos'))
          ['items'] as List;
      expect((actualizado.first as Map)['stock'], stockOriginal + 1);
      await AdminOfflineRepository.operar({
        'accion': 'compra_estado', 'id_compra': compra['id_compra'],
        'estado': 'Anulado',
      });
      actualizado = (await AdminOfflineRepository.consultar('productos'))
          ['items'] as List;
      expect((actualizado.first as Map)['stock'], stockOriginal - 2);

      final kardex = (await AdminOfflineRepository.consultar('inventario'))
          ['items'] as List;
      expect(kardex.length, greaterThanOrEqualTo(3));
      await OfflineDatabase.cerrarPruebas();
      final despues = (await AdminOfflineRepository.consultar('productos'))
          ['items'] as List;
      expect((despues.first as Map)['stock'], stockOriginal - 2);
      expect((await AdminOfflineRepository.consultar('clientes'))
          ['items'], hasLength(1));
      expect(await AdminOfflineRepository.comprobarAcceso('ClaveLocal2026!'), true);
    } finally {
      await OfflineDatabase.limpiarScope(scope);
    }
  });
  test('Cliente offline comparte catálogo, ventas, pagos y stock con '
      'dashboard admin SQLite del mismo celular', () async {
    const scope = AdminOfflineRepository.scope;
    await OfflineDatabase.limpiarScope(scope);
    try {
      final productos = (await AdminOfflineRepository.consultar('productos'))
          ['items'] as List;
      expect(productos, isNotEmpty);
      final prod = Map<String,dynamic>.from(productos.first as Map);
      final idProd = prod['id_producto'];
      final stockInicial = int.parse(prod['stock'].toString());
      final cliente = await AdminOfflineRepository.registrarComprador(
        nombres: 'Sandra', apellidos: 'Prueba',
        correo: 'sandra-local@example.test', telefono: '987654321',
        contrasena: 'TiendaLocal_2026',
      );
      expect(await AdminOfflineRepository.autenticarComprador(
        'SANDRA-LOCAL@example.test','TiendaLocal_2026'),cliente);
      expect(await AdminOfflineRepository.autenticarComprador(
        'sandra-local@example.test','ClaveIncorrecta'),isNull);
      await expectLater(AdminOfflineRepository.registrarComprador(
        nombres: 'Duplicada', apellidos: 'Prueba',
        correo: 'sandra-local@example.test',telefono: '',
        contrasena: 'ClaveDuplicada!'),throwsStateError);
      final otro = await AdminOfflineRepository.registrarComprador(
        nombres:'Carlos',apellidos:'Cliente',
        correo:'carlos-local@example.test',telefono:'',
        contrasena:'OtraClave!2026',
      );
      final direccion = await AdminOfflineRepository.operar({
        'accion':'direccion_guardar', 'id_usuario':cliente,
        'id_direccion':0,
        'departamento':'Ucayali','provincia':'Coronel Portillo',
        'distrito':'Callería','direccion_detalle':'Jr. Local 125',
        'referencia':'Frente a la tienda',
      });
      expect(int.parse(direccion['id_direccion'].toString()),
          greaterThan(0));

      final compra = await AdminOfflineRepository.operar({
        'accion':'pedido_manual', 'id_usuario':cliente,
        'tipo_entrega':'Delivery',
        'id_direccion':direccion['id_direccion'],
        'metodo_pago':'Efectivo',
        'items':[{'id_producto':idProd,'cantidad':1}],
      });
      final idPedido = compra['id_pedido'] as int;
      expect((await AdminOfflineRepository.consultar(
        'mis_pedidos',id:cliente))['items'],hasLength(1));
      expect((await AdminOfflineRepository.consultar(
        'mis_pedidos',id:otro))['items'],isEmpty);
      expect((await AdminOfflineRepository.consultar(
        'pedidos'))['items'],hasLength(1));
      final despues = (await AdminOfflineRepository.consultar(
        'productos'))['items'] as List;
      expect((despues.first as Map)['stock'],stockInicial-1);

      final detalle = await AdminOfflineRepository.consultar(
        'pedido_detalle',id:idPedido);
      expect((detalle['lineas'] as List),hasLength(1));
      expect((detalle['pagos'] as List).single['estado_pago'],'Pendiente');

      final idPago = (detalle['pagos'] as List).single['id_pago'];
      await AdminOfflineRepository.operar({
        'accion':'pago_confirmar','id_pago':idPago,
      });
      expect((await AdminOfflineRepository.consultar(
        'mis_pedidos',id:cliente))['items'][0]['estado_pedido'],'Pagado');
      await OfflineDatabase.cerrarPruebas();
      expect(await AdminOfflineRepository.autenticarComprador(
        'sandra-local@example.test','TiendaLocal_2026'),cliente);
      expect((await AdminOfflineRepository.consultar(
        'mis_pedidos',id:cliente))['items'],hasLength(1));
      expect((await AdminOfflineRepository.consultar(
        'productos'))['items'][0]['stock'],stockInicial-1);
    } finally {
      await OfflineDatabase.limpiarScope(scope);
    }
  });

}
