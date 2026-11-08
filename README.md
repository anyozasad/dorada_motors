# Dorada Motors — Flutter + PHP + MySQL

Proyecto de compra y administración de repuestos de motocicletas y motokar. **Dos carpetas principales**:

- **[Flutter/](Flutter/)** — aplicación móvil/web, Android, iOS, lib, assets, pubspec.yaml y pruebas.
- **[PHP/](PHP/)** — dashboard, API (en PHP/dorada_api), SQL, pruebas e instrucciones de entrega.

La carpeta técnica `.github/` conserva las pruebas automáticas de GitHub. No es otro proyecto. No elimines las subcarpetas de Flutter: son necesarias para compilar.

## Iniciar desde PowerShell
Enciende **Apache** y **MySQL** en XAMPP. Desde la raíz del repositorio:

```powershell
git pull origin main
powershell -ExecutionPolicy Bypass -File .\PHP\INICIAR_DEMO.ps1
```

El script copia **PHP/dorada_api** a **C:\xampp\htdocs\dorada_api** e inicia Flutter desde la carpeta correcta.

- Dashboard PHP: http://localhost/dorada_api/admin_login.php
- Flutter Web: http://localhost:8080
- phpMyAdmin: http://localhost/phpmyadmin

Para iniciar Flutter por separado: `cd Flutter`, luego `flutter pub get` y `flutter run -d chrome --web-port 8080`.

## Indicador IV: una sola entrega
Desde la raíz:

```powershell
powershell -ExecutionPolicy Bypass -File .\PHP\PREPARAR_ENTREGA_INDICADOR_IV.ps1
```

Genera `INDICADOR_IV_DORADA_MOTORS.zip` en el Escritorio, con **solo Flutter y PHP**, sin ZIP anidados ni datos privados de clientes.

Para verificar funciones:

```powershell
powershell -ExecutionPolicy Bypass -File .\PHP\VERIFICAR_SISTEMA.ps1
```

La matriz de requisitos está en [PHP/MATRIZ_VALIDACION_FUNCIONAL_150.md](PHP/MATRIZ_VALIDACION_FUNCIONAL_150.md). Revisa resultados de Flutter, PHP/MySQL y navegador en [Actions](https://github.com/anyozasad/dorada_motors/actions).

Nota: los comprobantes son de demostración y los pagos digitales se confirman manualmente, no por una pasarela bancaria.
