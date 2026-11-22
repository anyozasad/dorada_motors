import 'package:flutter_test/flutter_test.dart';
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

  test('Un ACK antiguo NO borra la nueva edición de perfil', () async {
    const scope = 'test:conflicto:usuario40';
    const clave = 'perfil_unico_usuario40';
    await OfflineDatabase.encolar(
      clave: clave, scope: scope, accion: 'perfil',
      datos: {'nombres': 'Ana', 'telefono': '900000001'},
    );
    final primera = (await OfflineDatabase.pendientes(scope)).single;
    // Mientras se envía la primera versión, el cliente corrige el teléfono.
    await OfflineDatabase.encolar(
      clave: clave, scope: scope, accion: 'perfil',
      datos: {'nombres': 'Ana', 'telefono': '900000002'},
    );
    expect(await OfflineDatabase.confirmarVersion(
      clave, primera['payload'] as String,
    ), isFalse);
    final despues = await OfflineDatabase.pendientes(scope);
    expect(despues, hasLength(1));
    expect((despues.single['datos'] as Map)['telefono'], '900000002');
    // Un error tardío de la primera versión tampoco bloquea la nueva.
    await OfflineDatabase.registrarErrorVersion(
      clave, primera['payload'] as String, 'Datos rechazados',
    );
    expect((await OfflineDatabase.pendientes(scope)).single['estado'],
        'pendiente');
    expect(await OfflineDatabase.confirmarVersion(
      clave, despues.single['payload'] as String,
    ), isTrue);
    expect(await OfflineDatabase.contarPendientes(scope), 0);
    await OfflineDatabase.limpiarScope(scope);
  });

  test('Operaciones de distintas cuentas nunca se mezclan', () async {
    await OfflineDatabase.encolar(
      clave: 'cuenta_41', scope: 'servidorA:usuario41', accion: 'soporte',
      datos: {'mensaje': 'Privado de 41'},
    );
    await OfflineDatabase.encolar(
      clave: 'cuenta_42', scope: 'servidorA:usuario42', accion: 'soporte',
      datos: {'mensaje': 'Privado de 42'},
    );
    await OfflineDatabase.limpiarScope('servidorA:usuario41');
    expect(await OfflineDatabase.pendientes('servidorA:usuario41'), isEmpty);
    final segundo = await OfflineDatabase.pendientes('servidorA:usuario42');
    expect(segundo, hasLength(1));
    expect((segundo.single['datos'] as Map)['mensaje'], 'Privado de 42');
    await OfflineDatabase.limpiarScope('servidorA:usuario42');
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
