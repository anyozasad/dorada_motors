# Dorada Motors — Flutter + PHP + MySQL

Proyecto de compra y administración de repuestos de motocicletas y motokar. **Dos carpetas principales**:

- **[Flutter/](Flutter/)** — aplicación móvil/web, Android, iOS, lib, assets, pubspec.yaml y pruebas.
- **[PHP/](PHP/)** — dashboard, API (en PHP/dorada_api), SQL, pruebas e instrucciones de entrega.

La carpeta técnica `.github/` conserva las pruebas automáticas de GitHub. No es otro proyecto. No elimines las subcarpetas de Flutter: son necesarias para compilar.

## Archivos del proyecto
En `PHP/` solo verás **dos carpetas**: `dorada_api/` (dashboard PHP, API y MySQL) y `tests/` (pruebas, scripts y documentos del Indicador IV). Los scripts se conservan en `PHP/tests/scripts/` porque se necesitan para iniciar, verificar y entregar el proyecto.

## Iniciar desde PowerShell
Enciende **Apache** y **MySQL** en XAMPP. Desde la raíz del repositorio:

```powershell
git pull origin main
powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\INICIAR_DEMO.ps1
```

El script copia **PHP/dorada_api** a **C:\xampp\htdocs\dorada_api** e inicia Flutter desde la carpeta correcta.

- Dashboard PHP: http://localhost/dorada_api/admin_login.php
- Flutter Web: http://localhost:8080
- phpMyAdmin: http://localhost/phpmyadmin

Para iniciar Flutter por separado: `cd Flutter`, luego `flutter pub get` y `flutter run -d chrome --web-port 8080`.

## APK Android en un celular real (Indicador IV)
El profesor solicita mostrar la aplicación **instalada en un teléfono**, grabar un video **de hasta 10 minutos** y subir **video + APK**. No se necesita ejecutar Flutter desde un emulador.

**Opción 1, directamente en tu computadora (sin ZIP):**
```powershell
cd "$HOME\Desktop\dorada_motors"
git pull --ff-only origin main
powershell -NoProfile -ExecutionPolicy Bypass -File .\PHP\tests\scripts\COMPILAR_APK_CELULAR.ps1
```
Esto ejecuta análisis/pruebas Flutter, compila la variante de demostración y copia `DORADA_MOTORS_CELULAR.apk` al Escritorio. Si hay **un solo teléfono Android conectado por USB con depuración USB autorizada**, también intenta instalarlo. En otros casos, transfiere el APK al celular, abre «Mis archivos» e instálalo cuando Android lo permita.

**Opción 2, sin SDK Android local:** en [GitHub Actions → Flutter CI](https://github.com/anyozasad/dorada_motors/actions/workflows/flutter.yml), abre una ejecución de `main` y descarga el artefacto `Dorada-Motors-APK-Para-Celular`. GitHub entrega un ZIP que contiene **únicamente el APK** (no el proyecto); extrae `app-release.apk` y transfiérelo a tu celular.

**Conexión celular–XAMPP:**
1. Enciende Apache y MySQL en XAMPP; verifica `http://localhost/dorada_api/productos.php` desde Chrome de la PC.
2. Conecta teléfono y PC al **mismo Wi-Fi**. En PowerShell ejecuta `ipconfig` y busca la IPv4 del adaptador Wi-Fi (ejemplo `192.168.1.15`).
3. En Chrome del **teléfono**, abre `http://192.168.1.15/dorada_api/productos.php` sustituyendo por la IP real. Debe devolver datos JSON.
4. Abre el APK → login → **Configurar conexión con PHP** y guarda `http://192.168.1.15/dorada_api`; comprueba el mensaje de conexión exitosa.
5. Registra un cliente, consulta catálogo, añade un producto al carrito y confirma un pedido. En PC, abre `http://localhost/dorada_api/admin_login.php` y comprueba que ese pedido aparece en PHP/MySQL.

Si el teléfono no abre la URL, revisa que Windows Firewall permita a Apache recibir conexiones en la red privada y que ambos dispositivos estén en la misma red. `localhost` y `10.0.2.2` **no funcionan como dirección del servidor desde un teléfono físico**.

**Alcance:** el APK de presentación usa la configuración de firma de desarrollo del proyecto; no es una versión certificada de Google Play. Los comprobantes electrónicos no se emiten a SUNAT y Yape/Plin requieren confirmación administrativa. La aplicación no se ha probado físicamente en todos los teléfonos.

## Indicador IV — avance funcional en desarrollo
No se genera ni publica ZIP automáticamente mientras se corrigen y prueban las funciones. La entrega se preparará solamente cuando se solicite expresamente.

El trabajo actual se concentra en login Flutter y sesiones MySQL, catálogo, carrito, pedidos, pagos, movimientos de stock, dashboard PHP, navegación y reportes. GitHub Actions ejecuta pruebas de PHP, Flutter y navegación del panel.

Para verificar funciones:

```powershell
powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\VERIFICAR_SISTEMA.ps1
```

La matriz de requisitos está en [MATRIZ_VALIDACION_FUNCIONAL_150.md](PHP/tests/documentacion/MATRIZ_VALIDACION_FUNCIONAL_150.md), y las pruebas técnicas en [PHP/tests/](PHP/tests/). Revisa resultados de Flutter, PHP/MySQL y navegador en [Actions](https://github.com/anyozasad/dorada_motors/actions).

Nota: los comprobantes son de demostración y los pagos digitales se confirman manualmente, no por una pasarela bancaria.
