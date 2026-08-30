# Dorada Motors

Aplicación Flutter de **ADN Import's** para consultar y comprar repuestos de motocicletas y motokar.

## Funciones implementadas

- Inicio de sesión y registro local.
- Modo invitado para consultar productos.
- Catálogo con imagen, marca, categoría, precio, oferta, stock y compatibilidad.
- Búsqueda por producto, marca y descripción.
- Filtros por categoría, marca y tipo de vehículo.
- Detalle de producto.
- Favoritos persistentes.
- Carrito persistente con control de cantidades y validación de stock.
- Checkout con recojo en tienda o delivery.
- Métodos de pago: Yape, Plin, efectivo y transferencia.
- Registro local de pedidos e historial de compras.
- Perfil de cliente y cierre de sesión.
- Navegación inferior: Inicio, Productos, Favoritos y Perfil.

## Estructura principal

```text
lib/
├── data/
│   └── productos_data.dart
├── models/
│   ├── pedido.dart
│   └── producto.dart
├── screens/
│   ├── checkout_screen.dart
│   ├── login_screen.dart
│   ├── main_shell.dart
│   ├── orders_screen.dart
│   └── register_screen.dart
├── services/
│   └── local_store.dart
├── widgets/
│   └── product_card.dart
└── main.dart
```

## Ejecutar el proyecto

```bash
flutter pub get
flutter run
```

Para ejecutar en Chrome:

```bash
flutter run -d chrome --web-port 8080
```

Para ejecutar pruebas:

```bash
flutter test
```

## Estado del proyecto

La versión actual funciona de manera local con `shared_preferences`. La estructura quedó preparada para reemplazar el almacenamiento local por una API y base de datos en una siguiente etapa.

> Nota: el registro local es apropiado para demostración académica y pruebas funcionales. Para producción, la autenticación, usuarios, inventario, pedidos y pagos deben gestionarse desde un backend seguro.
