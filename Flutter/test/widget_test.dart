import 'package:flutter/material.dart';
import 'package:dorada_motors/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dorada_motors/models/producto.dart';
import 'package:dorada_motors/theme/app_theme.dart';
import 'package:dorada_motors/widgets/product_card.dart';
import 'package:dorada_motors/screens/main_shell.dart';

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

  testWidgets('Las tarjetas de repuestos caben en un celular estrecho',
      (tester) async {
    const producto = Producto(
      id: 101,
      nombre: 'Kit de transmisión reforzado para motocicleta y motokar',
      descripcion: 'Repuesto original',
      marca: 'REPUESTOS DORADA MOTORS',
      categoria: 'Transmisión',
      tipoVehiculo: 'Motocicleta y motokar',
      compatibilidad: '125cc, 150cc y 200cc',
      precio: 150,
      precioOferta: 125,
      stock: 6,
      imagen: 'assets/imagenes/01_kit_transmision_dtiex.png',
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 146,
            height: 340,
            child: ProductCard(
              product: producto,
              favorite: false,
              onTap: () {},
              onFavorite: () {},
              onAddCart: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Kit de transmisión'), findsOneWidget);
    expect(find.text('S/ 125.00'), findsOneWidget);
  });

  testWidgets('La portada y navegación se adaptan a 320 píxeles',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: MainShell(
        isGuest: true,
        onLoginRequested: () {},
        onLogout: () {},
        onProfileUpdated: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 850));
    expect(tester.takeException(), isNull);
    expect(find.text('DORADA MOTORS'), findsOneWidget);
    expect(find.text('Ver catálogo'), findsOneWidget);

    // Revisar también la pantalla real de catálogo a tamaño de teléfono.
    await tester.tap(find.text('Productos'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Solo disponibles'), findsOneWidget);
    expect(find.text('Orden: Relevancia'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Solo disponibles'));
    await tester.pump();
    expect(find.text('Limpiar filtros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
