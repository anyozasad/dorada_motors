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

## Indicador IV — avance funcional en desarrollo
No se genera ni publica ZIP automáticamente mientras se corrigen y prueban las funciones. La entrega se preparará solamente cuando se solicite expresamente.

El trabajo actual se concentra en login Flutter y sesiones MySQL, catálogo, carrito, pedidos, pagos, movimientos de stock, dashboard PHP, navegación y reportes. GitHub Actions ejecuta pruebas de PHP, Flutter y navegación del panel.

Para verificar funciones:

```powershell
powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\VERIFICAR_SISTEMA.ps1
```

La matriz de requisitos está en [MATRIZ_VALIDACION_FUNCIONAL_150.md](PHP/tests/documentacion/MATRIZ_VALIDACION_FUNCIONAL_150.md), y las pruebas técnicas en [PHP/tests/](PHP/tests/). Revisa resultados de Flutter, PHP/MySQL y navegador en [Actions](https://github.com/anyozasad/dorada_motors/actions).

Nota: los comprobantes son de demostración y los pagos digitales se confirman manualmente, no por una pasarela bancaria.
