import 'package:dorada_motors/screens/admin_offline_login_screen.dart';
import 'package:dorada_motors/screens/local_customer_screen.dart';
import 'package:dorada_motors/services/admin_offline_repository.dart';
import 'package:dorada_motors/services/offline_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cliente local presenta entrada y registro en pantalla de 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: LocalCustomerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tienda local · sin laptop'), findsOneWidget);
    expect(find.text('Compra sin internet'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Nombres'), findsOneWidget);
    expect(find.text('Apellidos'), findsOneWidget);
    expect(find.text('Crear cuenta y entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Acceso administrador local sin IP no desborda en 320px',
      (tester) async {
    await OfflineDatabase.limpiarScope(AdminOfflineRepository.scope);
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(home: AdminOfflineLoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Administrador sin laptop'), findsOneWidget);
    expect(find.text('Crear acceso local'), findsOneWidget);
    expect(find.text('Crear acceso y abrir dashboard'), findsOneWidget);
    expect(find.textContaining('192.168'), findsNothing);
    expect(tester.takeException(), isNull);
    await OfflineDatabase.limpiarScope(AdminOfflineRepository.scope);
  });
}
