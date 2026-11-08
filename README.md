# Dorada Motors — Flutter + PHP + MySQL

Aplicación móvil y web para la venta y administración de repuestos de motocicletas y motokar. El proyecto mantiene la interfaz Flutter y el dashboard PHP, conectados mediante una API que consulta MySQL en XAMPP.

## Estructura

- `lib/`: aplicación Flutter (acceso, registro, catálogo, filtros, favoritos, carrito, checkout e historial).
- `dorada_api/`: backend PHP, API JSON, dashboard de administración y esquema MySQL.
- `assets/imagenes/`: imágenes de productos disponibles sin internet dentro de Flutter.
- `dorada_api/assets/imagenes/`: copia de las imágenes locales para mostrar el catálogo en PHP.
- `test/`: pruebas automatizadas Flutter.
- `INICIAR_DEMO.ps1`: preparación de PHP/XAMPP y ejecución de Flutter para la evaluación.

## Ejecutar en Windows con XAMPP

1. Iniciar **Apache** y **MySQL** en XAMPP.
2. Desde la carpeta principal del repositorio, ejecutar en PowerShell:

```powershell
git pull origin main
powershell -ExecutionPolicy Bypass -File .\INICIAR_DEMO.ps1
```

El script copia `dorada_api/` a `C:\xampp\htdocs\dorada_api\`, revisa sintaxis PHP si encuentra `php.exe`, comprueba la API e inicia Flutter en Chrome en `http://localhost:8080`.

Si XAMPP está instalado en otra ruta, copia `dorada_api/` a su carpeta `htdocs` y ejecuta:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080
```

**Primera instalación:** la API prepara automáticamente la base de datos `dorada_motors` y sus 17 tablas cuando se usan sus rutas. Si el catálogo está vacío, `dorada_motors.sql` incorpora 19 productos de demostración con imágenes locales. No sustituye ni borra productos que ya estén registrados.

**URLs de prueba:**
- Dashboard protegido: http://localhost/dorada_api/admin_login.php
- API pública de catálogo: http://localhost/dorada_api/productos.php
- Flutter web: http://localhost:8080
- Base de datos (XAMPP): http://localhost/phpmyadmin/

## Flujo para demostrar al profesor

1. En el dashboard PHP, registrar o editar un producto, precio o stock.
2. En Flutter, abrir el catálogo o pulsar **Reintentar** para actualizarlo y verificar que el producto aparece.
3. Registrar un cliente e iniciar sesión en Flutter.
4. Agregar un repuesto al carrito y completar el pedido con recogida o delivery.
5. Verificar el pedido y los movimientos de stock en el dashboard y phpMyAdmin.
6. Abrir **Mis pedidos** en Flutter, consultar su estado y realizar el cierre de sesión.

Flutter obtiene los productos de MySQL a través de `ApiService`. El backend comprueba el stock de cada pedido dentro de una transacción, calcula el total en el servidor y guarda el pago con estado **Pendiente**. Seleccionar Yape o Plin no equivale a confirmar un cobro real.

## Autenticación y permisos

- El login y el registro de clientes emiten tokens aleatorios con una duración de 7 días.
- MySQL guarda el **hash** de cada token, no su texto original.
- Pedidos, direcciones, carrito y favoritos exigen identidad de cliente; no se puede acceder pasando el ID de otra cuenta.
- El dashboard PHP usa sesión administrativa, roles, tokens CSRF y validaciones.
- Las operaciones de escritura de catálogo por API exigen rol autorizado y CSRF.
- Las sesiones del cliente pueden cerrarse desde Flutter.

Estas protecciones corresponden a una **demostración local**. Para operar en internet se necesita HTTPS, un despliegue protegido, supervisión de acceso, copias de seguridad y una revisión de seguridad completa. Los comprobantes del dashboard no son una integración certificada con SUNAT.

## Configuración de API y móvil

De forma predeterminada:
- Flutter Web / Chrome en la misma PC: `http://localhost/dorada_api`
- Emulador Android: `http://10.0.2.2/dorada_api`

Para otro dispositivo conectado a la misma red, proporcionar la IP local de la PC con el backend:

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://IP_DE_TU_PC/dorada_api
```

La dirección anterior es un ejemplo; sustituye `IP_DE_TU_PC` por la IP real. El firewall y Apache deben permitir el acceso desde ese dispositivo. No utilizar HTTP sin TLS para cuentas reales fuera del entorno local.

## Verificaciones

```powershell
flutter pub get
flutter analyze
flutter test
```

Para revisar PHP con XAMPP:

```powershell
Get-ChildItem .\dorada_api -Filter *.php -Recurse | ForEach-Object { & C:\xampp\php\php.exe -l $_.FullName }
php VALIDAR_DASHBOARD_150.php
```

GitHub Actions ejecuta la sintaxis de PHP y el análisis/pruebas de Flutter automáticamente. Su resultado actual se puede consultar en **Actions** del repositorio: https://github.com/anyozasad/dorada_motors/actions

## Archivos clave

- `lib/main.dart`: arranque Flutter.
- `lib/services/api_service.dart`: conexión HTTP.
- `lib/services/local_store.dart`: preferencias y respaldo local.
- `dorada_api/conexion.php`: conexión y preparación MySQL.
- `dorada_api/cliente_auth.php`: autenticación de clientes.
- `dorada_api/dashboard.php`: panel administrativo.
- `dorada_api/dorada_motors.sql`: esquema y ejemplos para una instalación vacía.
- `dorada_api/LEEME_PROFESOR.txt`: guía de evaluación.

> La ejecución real depende de que Apache, MySQL y Flutter estén instalados y configurados en la computadora donde se presentará el proyecto.
