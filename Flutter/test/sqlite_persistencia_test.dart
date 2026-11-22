import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dorada_motors/services/offline_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('SQLite conserva catálogo y perfil tras reabrir la base de datos',
      () async {
    const scope = 'test:servidorA:cliente9';
    await OfflineDatabase.guardar(scope, 'catalogo', [
      {'id': 1, 'nombre': 'Faro LED'},
    ]);
    expect((await OfflineDatabase.leer(scope, 'catalogo') as List).length, 1);
    await OfflineDatabase.cerrarPruebas();
    final otraLectura = await OfflineDatabase.leer(scope, 'catalogo');
    expect((otraLectura as List).first['nombre'], 'Faro LED');
    expect(await OfflineDatabase.leer('test:servidorB:cliente9', 'catalogo'),
        isNull);
    await OfflineDatabase.limpiarScope(scope);
  });

  test('SQLite mantiene última operación al editar stock local', () async {
    const scope = 'test:carrito:usuario20';
    await OfflineDatabase.encolar(
      clave: 'carrito_15', scope: scope, accion: 'carrito',
      datos: {'id_producto': 15, 'cantidad': 2},
    );
    await OfflineDatabase.encolar(
      clave: 'carrito_15', scope: scope, accion: 'carrito',
      datos: {'id_producto': 15, 'cantidad': 5},
    );
    final pending = await OfflineDatabase.pendientes(scope);
    expect(pending, hasLength(1));
    expect((pending.single['datos'] as Map)['cantidad'], 5);
    await OfflineDatabase.cerrarPruebas();
    expect(await OfflineDatabase.contarPendientes(scope), 1);
    await OfflineDatabase.confirmar('carrito_15');
    expect(await OfflineDatabase.contarPendientes(scope), 0);
    await OfflineDatabase.limpiarScope(scope);
  });

  test('SQLite mantiene errores y borradores sin perder el contenido', () async {
    const scope = 'test:pedidos:cliente30';
    await OfflineDatabase.encolar(
      clave: 'pedido_abc', scope: scope, accion: 'pedido_borrador',
      datos: {'items': [{'id_producto': 4, 'cantidad': 2}],
              'total_esperado': 420},
    );
    await OfflineDatabase.registrarError('pedido_abc', 'Sin Wi-Fi');
    final pendientes = await OfflineDatabase.pendientes(scope);
    expect(pendientes, hasLength(1));
    expect(pendientes.first['estado'], 'error');
    expect((pendientes.first['datos'] as Map)['total_esperado'], 420);
    await OfflineDatabase.limpiarScope(scope);
  });
}
