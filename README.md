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

El script copia `dorada_api/` a `C:\xampp\htdocs\dorada_api\`, revisa sintaxis PHP si encuentra `php.exe`, comprueba la API, ejecuta `flutter analyze` y `flutter test` e inicia Flutter en Chrome en `http://localhost:8080`.

Si XAMPP está instalado en otra ruta, copia `dorada_api/` a su carpeta `htdocs` y ejecuta:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080
```

**Primera instalación:** la API prepara automáticamente la base de datos `dorada_motors` y sus 18 tablas cuando se usan sus rutas. Si la base de datos es nueva y el catálogo está vacío, `dorada_motors.sql` incorpora 19 productos de demostración con imágenes locales. No sustituye ni borra productos ya registrados. Si la base fue creada antes de incorporar el catálogo de ejemplo y sigue vacía, ejecuta una vez `dorada_motors.sql` en phpMyAdmin.

**URLs de prueba:**
- Dashboard protegido: http://localhost/dorada_api/admin_login.php
- API pública de catálogo: http://localhost/dorada_api/productos.php
- Flutter web: http://localhost:8080
- Base de datos (XAMPP): http://localhost/phpmyadmin/

## Flujo para demostrar al profesor

1. En el dashboard PHP, registrar o editar un producto, precio o stock.
2. En Flutter, abrir el catálogo o pulsar **Reintentar** para actualizarlo y verificar que el producto aparece.
3. Crear una cuenta de cliente, editar el perfil y cambiar la contraseña desde Flutter. Verificar la opción «¿Olvidaste tu contraseña?» y su atención en soporte. El primer acceso al panel PHP permite crear el administrador inicial.
4. Agregar un producto a **Favoritos** y al **Carrito** y comprobar ambos datos en MySQL. Desde **Ayuda y soporte**, enviar una consulta y responderla en la nueva sección del panel PHP.
5. Completar un pedido con recojo o delivery, elegir una dirección guardada en MySQL y verificar la tarifa de entrega configurada en PHP.
6. Verificar en PHP el pedido, el pago pendiente y los movimientos de stock. Confirmar el pago desde el dashboard.
7. Emitir e imprimir un comprobante de demostración, y revisar en Flutter **Mis pedidos** y sus estados.
8. Probar en PHP la cancelación de un pedido pendiente y comprobar que se repone el inventario.

Flutter obtiene los productos, favoritos y carrito de MySQL a través de `ApiService` cuando el cliente ha iniciado sesión; en modo invitado el carrito es local. El backend comprueba el stock de cada pedido dentro de una transacción, calcula el total en el servidor, vacía el carrito persistido y guarda el pago con estado **Pendiente**. Seleccionar Yape o Plin no equivale a confirmar un cobro real.

## Autenticación y permisos

- El login y el registro de clientes emiten tokens aleatorios con una duración de 7 días.
- MySQL guarda el **hash** de cada token, no su texto original.
- Pedidos, direcciones, carrito y favoritos exigen identidad de cliente; no se puede acceder pasando el ID de otra cuenta.
- El dashboard PHP usa sesión administrativa, roles, tokens CSRF y validaciones.
- Las operaciones de escritura de catálogo por API exigen rol autorizado y CSRF.
- Las sesiones del cliente pueden cerrarse desde Flutter.
- La recuperación de contraseña es **asistida**: genera un caso para administración, exige verificación de identidad fuera de la aplicación, permite al administrador establecer una clave temporal y revoca las sesiones antiguas. No afirma enviar correos automáticos.

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

GitHub Actions ejecuta la sintaxis de PHP, el análisis y las pruebas Flutter, y una **integración real con MySQL temporal** que comprueba registro, autenticación, permisos, carrito, favoritos, compras, pagos, stock, cancelaciones, CRUD administrativo y comprobantes. Su resultado actual se puede consultar en **Actions** del repositorio: https://github.com/anyozasad/dorada_motors/actions

## Preparar el ZIP para entregar

Desde la carpeta principal de `dorada_motors` en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\PREPARAR_ENTREGA_INDICADOR_II.ps1
```

El script crea `ENTREGA_DORADA_MOTORS.zip` en el **Escritorio**, con `Dorada_Motors_PROYECTO_COMPLETO.zip`, esquema SQL de instalación y guía/matriz de requisitos. Incluye Flutter, PHP, carrito, favoritos, soporte e imágenes; no exporta clientes, contraseñas, pedidos reales ni registros privados de auditoría.

Para generar además paquetes separados de Flutter y web PHP:

```powershell
powershell -ExecutionPolicy Bypass -File .\PREPARAR_ENTREGA_INDICADOR_II.ps1 -PaquetesSeparados
```

Antes de presentar, ejecutar con Apache y MySQL de XAMPP encendidos:

```powershell
powershell -ExecutionPolicy Bypass -File .\VERIFICAR_SISTEMA.ps1
```

Este último es un control técnico; la matriz debe completarse con evidencias funcionales de las operaciones que revisará el profesor.

## Archivos clave

- `lib/main.dart`: arranque Flutter.
- `lib/services/api_service.dart`: conexión HTTP.
- `lib/services/local_store.dart`: preferencias y respaldo local.
- `dorada_api/conexion.php`: conexión y preparación MySQL.
- `dorada_api/cliente_auth.php`: autenticación de clientes.
- `dorada_api/cuenta.php`: edición de cuenta y cambio de contraseña.
- `dorada_api/soporte.php`: envío y seguimiento de solicitudes del cliente.
- `dorada_api/recuperacion.php`: solicitud de recuperación desde el login sin revelar cuentas existentes.
- `dorada_api/dashboard.php`: panel administrativo.
- `dorada_api/config_publica.php`: tarifa de entrega compartida con Flutter.
- `dorada_api/carrito.php` y `dorada_api/favoritos.php`: datos persistidos en MySQL por cliente.
- `tests/integration_smoke.py`: pruebas de integración real contra PHP y MySQL (clientes, soporte, pedidos, inventario, compras y otros flujos).
- `MATRIZ_VALIDACION_FUNCIONAL_150.md`: matriz de los 150 requisitos del panel para verificar cada punto con el profesor.
- `VERIFICAR_SISTEMA.ps1`: verificación local de XAMPP, API pública/privada, PHP y Flutter.
- `dorada_api/dorada_motors.sql`: esquema y ejemplos para una instalación vacía.
- `dorada_api/LEEME_PROFESOR.txt`: guía de evaluación.

> La ejecución real depende de que Apache, MySQL y Flutter estén instalados y configurados en la computadora donde se presentará el proyecto. La matriz enumera los 150 requisitos; las pruebas automáticas no certifican por sí solas los 150 casos de uso.
