import 'package:dorada_motors/theme/app_theme.dart';
import 'package:dorada_motors/widgets/pedido_estado_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Color?> colorPara(WidgetTester tester, String estado) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PedidoEstadoBadge(estado: estado))),
    );
    final badge = find.byType(PedidoEstadoBadge);
    final container = tester.widget<Container>(
      find.descendant(of: badge, matching: find.byType(Container)).first,
    );
    return (container.decoration as BoxDecoration).color;
  }

  testWidgets('Cancelado es rojo, no se muestra como pago exitoso', (tester) async {
    expect(await colorPara(tester, 'Cancelado'), const Color(0xFFFFE9E7));
    expect(find.text('Cancelado'), findsOneWidget);
  });

  testWidgets('Pendiente es distinto de completado', (tester) async {
    expect(await colorPara(tester, 'Pendiente'), AppColors.goldSoft);
    expect(await colorPara(tester, 'Completado'), const Color(0xFFE8F7EF));
  });

  testWidgets('Enviado refleja progreso sin presentarse como cancelado', (tester) async {
    expect(await colorPara(tester, 'Enviado'), const Color(0xFFE8F2FF));
  });
}
