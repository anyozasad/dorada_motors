# Dorada Motors — Flutter + PHP + MySQL

Proyecto de compra y administración de repuestos de motocicletas y motokar. **Dos carpetas principales**:

- **[Flutter/](Flutter/)** — aplicación móvil/web, Android, iOS, lib, assets, pubspec.yaml y pruebas.
- **[PHP/](PHP/)** — dashboard, API (en PHP/dorada_api), SQL, pruebas e instrucciones de entrega.

La carpeta técnica `.github/` conserva las pruebas automáticas de GitHub. No es otro proyecto. No elimines las subcarpetas de Flutter: son necesarias para compilar.

## Archivos del proyecto
En `PHP/` solo verás **dos carpetas**: `dorada_api/` (dashboard PHP, API y MySQL) y `tests/` (pruebas, scripts y documentos del Indicador IV). Los scripts se conservan en `PHP/tests/scripts/` porque se necesitan para iniciar, verificar y entregar el proyecto.

## Actualizar desde GitHub con un solo archivo

El código de la rama **main** se actualiza directamente en este repositorio. Si estás trabajando en
la laptop, usa [ACTUALIZAR_DORADA_MOTORS.ps1](ACTUALIZAR_DORADA_MOTORS.ps1),
ubicado en la raíz. El script comprueba que no perderás cambios locales,
ejecuta `git pull --ff-only`, copia PHP a XAMPP **sin eliminar la base de datos
ni los archivos subidos**, y compila el APK cuando Flutter está instalado.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ACTUALIZAR_DORADA_MOTORS.ps1 -EjecutarPruebas
```

El APK resultante se copia al Escritorio como `DORADA_MOTORS_LOCAL_ACTUALIZADO.apk`.
Si Flutter no está instalado, descarga el APK ya compilado desde
[GitHub Actions → Flutter CI](https://github.com/anyozasad/dorada_motors/actions/workflows/flutter.yml).
También puedes usar `-SoloCodigo` o `-SinCompilarApk` sin alterar datos locales.

**Importante:** ninguna actualización desde GitHub puede entrar a una laptop apagada o
modificar sus archivos por sí sola; el script debe ejecutarse en ella.

## Dos modalidades diferentes dentro del APK

- **Administrador sin laptop + tienda del cliente sin internet:** ambas pantallas usan
  **la misma SQLite privada del mismo dispositivo Android**. El administrador
  puede dar de alta un cliente con contraseña local, actualizar repuestos,
  ventas, compras, pagos, stock, Kardex y comprobantes de **demostración**.
  El cliente puede entrar con esa cuenta, consultar precios, registrar pedidos
  y ver el estado. Los cobros Yape/Plin **se verifican manualmente**.
- **Administrador / tienda con PHP + MySQL:** usa el panel PHP y la API del servidor.
  El celular necesita conectividad al servidor (red local con XAMPP encendido,
  o servidor remoto disponible). La SQLite local y esa MySQL son **bases separadas**,
  sin sincronización automática de pedidos, pagos, stock ni usuarios entre ambas.

No desinstales una aplicación que contenga datos reales sin antes tener un
respaldo. El APK de Android se firma con clave de desarrollo para la presentación;
las pruebas automáticas no reemplazan la validación en el Samsung físico.
La lista de 150 requisitos es una **matriz de revisión**, no una certificación
de funcionamiento de los 150 puntos.

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

## Offline-first: SQLite en Android + MySQL al recuperar conexión

El APK de Android guarda **copias de catálogo, pedidos anteriores y operaciones
pendientes en SQLite**, dentro del almacenamiento privado de la aplicación.
Las fotos de los repuestos iniciales están incluidas en el APK y las imágenes
nuevas de PHP se mantienen en caché tras descargarlas.

- **Sin internet ni Wi-Fi:** navegación, búsqueda, carrito, favoritos y el último
  catálogo descargado funcionan en el celular. Direcciones, perfil y consultas
  se guardan localmente como operaciones pendientes.
- **Pedidos offline:** el cliente puede guardar un borrador de compra con
  productos, cantidades, dirección y medio de pago. En «Mis pedidos» debe
  pulsar «Confirmar y enviar» después de recuperar conexión. El servidor
  comprueba de nuevo precios, tarifa de entrega y stock. Si no coinciden, el
  borrador permanece sin registrar y el cliente debe revisar los cambios.
- **Al reconectar:** abrir/reanudar la app o utilizar «Sincronizar» en el perfil
  envía los cambios pendientes a MySQL. Los identificadores de operación
  evitan duplicar direcciones, consultas y pedidos cuando se reintenta la red.
- **Registro inicial, autenticación nueva, recuperación de contraseña, pagos
  confirmados y stock real** requieren comunicación con PHP/MySQL. Sin red
  no se puede escribir instantáneamente en la base MySQL de otra computadora.
- **Dashboard en la PC:** el panel PHP y MySQL pueden ejecutarse en localhost
  sin acceso a internet público si XAMPP está encendido. Para sincronizar con
  el celular, ambos deben tener un enlace de red local o internet disponible.

Comprobar el modo offline: conectar una vez la app al servidor, iniciar sesión,
abrir catálogo y fotos, luego activar modo avión. Modificar carrito/favoritos,
guardar dirección y borrador de pedido; cerrar y abrir la app. Al reconectar,
sincronizar desde el perfil y revisar los registros en PHP/MySQL. Los borradores
de pedido requieren confirmación separada del cliente.

## Indicador IV — avance funcional en desarrollo
No se genera ni publica ZIP automáticamente mientras se corrigen y prueban las funciones. La entrega se preparará solamente cuando se solicite expresamente.

El trabajo actual se concentra en login Flutter y sesiones MySQL, catálogo, carrito, pedidos, pagos, movimientos de stock, dashboard PHP, navegación y reportes. GitHub Actions ejecuta pruebas de PHP, Flutter y navegación del panel.

Para verificar funciones:

```powershell
powershell -ExecutionPolicy Bypass -File .\PHP\tests\scripts\VERIFICAR_SISTEMA.ps1
```

La matriz de requisitos está en [MATRIZ_VALIDACION_FUNCIONAL_150.md](PHP/tests/documentacion/MATRIZ_VALIDACION_FUNCIONAL_150.md), y las pruebas técnicas en [PHP/tests/](PHP/tests/). Revisa resultados de Flutter, PHP/MySQL y navegador en [Actions](https://github.com/anyozasad/dorada_motors/actions).

Nota: los comprobantes son de demostración y los pagos digitales se confirman manualmente, no por una pasarela bancaria.
