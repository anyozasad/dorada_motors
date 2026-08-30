import 'package:dorada_motors/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Muestra la pantalla de acceso de Dorada Motors', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DoradaMotorsApp());
    await tester.pumpAndSettle();

    expect(find.text('DORADA MOTORS'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Continuar como invitado'), findsOneWidget);
  });
}
