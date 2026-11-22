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

  test('Dos cambios simultáneos no se pisan en el carrito SQLite', () async {
    const scope = 'test:carrito:simultaneo52';
    await Future.wait([
      OfflineDatabase.cambiarEntradaMapa(
        scope: scope, nombre: 'carrito_pendiente',
        clave: '15', valor: 2,
      ),
      OfflineDatabase.cambiarEntradaMapa(
        scope: scope, nombre: 'carrito_pendiente',
        clave: '29', valor: 4,
      ),
    ]);
    final carrito = await OfflineDatabase.leer(scope, 'carrito_pendiente');
    expect((carrito as Map)['15'], 2);
    expect(carrito['29'], 4);
    await OfflineDatabase.limpiarScope(scope);
  });

  test('Respuesta vieja de MySQL no elimina edición posterior', () async {
    const scope = 'test:carrito:version53';
    const nombre = 'carrito_pendiente';
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: nombre, clave: '7', valor: 2,
    );
    // El envío de 2 unidades está en curso y el usuario cambia a 5.
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: nombre, clave: '7', valor: 5,
    );
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: nombre, clave: '7',
      confirmar: true, valorEsperado: 2,
    );
    final pendiente = await OfflineDatabase.leer(scope, nombre);
    expect((pendiente as Map)['7'], 5);
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: nombre, clave: '7',
      confirmar: true, valorEsperado: 5,
    );
    expect((await OfflineDatabase.leer(scope, nombre) as Map)
        .containsKey('7'), isFalse);
    await OfflineDatabase.limpiarScope(scope);
  });

  test('No se mezclan favoritos y carrito al sincronizar', () async {
    const scope = 'test:cliente:carritoFavoritos54';
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: 'favoritos_pendientes',
      clave: '3', valor: true,
    );
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: 'carrito_pendiente',
      clave: '3', valor: 1,
    );
    await OfflineDatabase.cambiarEntradaMapa(
      scope: scope, nombre: 'carrito_pendiente',
      clave: '3', confirmar: true, valorEsperado: 1,
    );
    expect((await OfflineDatabase.leer(scope, 'favoritos_pendientes')
        as Map)['3'], isTrue);
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
