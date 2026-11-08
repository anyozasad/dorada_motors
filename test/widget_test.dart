import 'package:flutter/material.dart';
import 'package:dorada_motors/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Muestra la pantalla de acceso de Dorada Motors', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DoradaMotorsApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Continuar como invitado'), findsOneWidget);
  });

  testWidgets('El formulario Flutter valida nombre, correo y contraseña', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DoradaMotorsApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Únete a Dorada Motors'), findsOneWidget);
    await tester.ensureVisible(find.text('Crear mi cuenta'));
    await tester.tap(find.text('Crear mi cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres.'), findsOneWidget);
  });

  testWidgets('Se puede configurar el servidor PHP antes de iniciar sesión', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DoradaMotorsApp());
    await tester.pumpAndSettle();

    final enlace = find.text('Configurar conexión con PHP');
    await tester.ensureVisible(enlace);
    await tester.tap(enlace);
    await tester.pumpAndSettle();

    expect(find.text('Conectar con Dorada Motors'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'no-es-una-direccion-valida');
    await tester.tap(find.text('Probar conexión'));
    await tester.pumpAndSettle();

    expect(find.text('Usa una URL válida terminada en /dorada_api.'), findsOneWidget);
  });
}
