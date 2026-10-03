# PREPARAR ENTREGA - EXAMEN INDICADOR II
# Dorada Motors
# Ejecutar en PowerShell con XAMPP/MySQL encendido.

$ErrorActionPreference = "Stop"

$Proyecto = "C:\Users\CESAR\Desktop\dorada_motors"
$Backend = Join-Path $Proyecto "dorada_api"
$Desktop = [Environment]::GetFolderPath("Desktop")
$Entrega = Join-Path $Desktop "ENTREGA_INDICADOR_II_DORADA_MOTORS"
$Dump = "C:\xampp\mysql\bin\mysqldump.exe"
$Htdocs = "C:\xampp\htdocs\dorada_api"

Write-Host "=== DORADA MOTORS - PREPARANDO ENTREGA ===" -ForegroundColor Cyan

if (!(Test-Path $Proyecto)) { throw "No se encontró el proyecto en $Proyecto" }
if (!(Test-Path $Backend)) { throw "No se encontró dorada_api en $Backend" }
if (!(Test-Path $Dump)) { throw "No se encontró mysqldump.exe en XAMPP." }

# 1) Crear carpeta de entrega
if (Test-Path $Entrega) {
    Remove-Item $Entrega -Recurse -Force
}
New-Item -ItemType Directory -Path $Entrega | Out-Null

# 2) Exportar base de datos real
$SqlBackend = Join-Path $Backend "dorada_motors.sql"
Write-Host "Exportando base de datos dorada_motors..." -ForegroundColor Yellow
& $Dump -u root --default-character-set=utf8mb4 --routines --events --triggers dorada_motors |
    Set-Content $SqlBackend -Encoding UTF8

if (!(Test-Path $SqlBackend) -or (Get-Item $SqlBackend).Length -lt 100) {
    throw "No se pudo generar dorada_motors.sql. Verifica que MySQL esté encendido."
}

Copy-Item $SqlBackend (Join-Path $Entrega "Dorada_Motors_BD.sql") -Force

# 3) Copiar backend actualizado a XAMPP
if (!(Test-Path $Htdocs)) {
    New-Item -ItemType Directory -Path $Htdocs | Out-Null
}
Copy-Item "$Backend\*" $Htdocs -Recurse -Force

# 4) ZIP del proyecto web + API + SQL
$WebZip = Join-Path $Entrega "Dorada_Motors_WEB_API.zip"
Compress-Archive -Path $Backend -DestinationPath $WebZip -Force

# 5) Preparar copia limpia del proyecto Flutter
$TempFlutter = Join-Path $env:TEMP "Dorada_Motors_FLUTTER_ENTREGA"
if (Test-Path $TempFlutter) {
    Remove-Item $TempFlutter -Recurse -Force
}
New-Item -ItemType Directory -Path $TempFlutter | Out-Null

$ExcluirDirectorios = @(
    ".git",
    ".dart_tool",
    "build",
    ".idea",
    "dorada_api"
)

$ArgsRobocopy = @(
    $Proyecto,
    $TempFlutter,
    "/E",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/NP"
)

foreach ($dir in $ExcluirDirectorios) {
    $ArgsRobocopy += "/XD"
    $ArgsRobocopy += (Join-Path $Proyecto $dir)
}

& robocopy @ArgsRobocopy | Out-Null
if ($LASTEXITCODE -gt 7) {
    throw "Error al copiar el proyecto Flutter."
}

$FlutterZip = Join-Path $Entrega "Dorada_Motors_FLUTTER.zip"
Compress-Archive -Path "$TempFlutter\*" -DestinationPath $FlutterZip -Force

# 6) Instrucciones para el profesor
$Instrucciones = @"
DORADA MOTORS - EXAMEN INDICADOR II

ARCHIVOS:
1. Dorada_Motors_BD.sql
   Base de datos MySQL.

2. Dorada_Motors_WEB_API.zip
   Proyecto web PHP, dashboard y API REST/JSON.

3. Dorada_Motors_FLUTTER.zip
   Aplicación Flutter que consulta la API PHP.

FLUJO:
Flutter -> HTTP/JSON -> PHP API -> MySQL dorada_motors

ENDPOINTS PRINCIPALES:
- /dorada_api/productos.php
- /dorada_api/login.php
- /dorada_api/usuarios.php
- /dorada_api/pedidos.php
- /dorada_api/dashboard_api.php

PARA EJECUTAR EL PROYECTO WEB:
1. Descomprimir dorada_api en C:\xampp\htdocs\
2. Encender Apache y MySQL en XAMPP.
3. Importar Dorada_Motors_BD.sql en phpMyAdmin.
4. Abrir:
   http://localhost/dorada_api/dashboard.php

PARA EJECUTAR FLUTTER WEB:
1. Descomprimir Dorada_Motors_FLUTTER.zip.
2. Abrir PowerShell en la carpeta.
3. Ejecutar:
   flutter pub get
   flutter run -d chrome --web-port 8080

API EN FLUTTER WEB:
http://localhost/dorada_api

EVIDENCIA DE INTEGRACIÓN:
- Registrar un producto en el dashboard PHP.
- Verificarlo en MySQL tabla producto.
- Abrir Flutter y revisar el catálogo.
- Flutter consulta productos.php y muestra los datos recibidos desde PHP/MySQL.
"@

Set-Content (Join-Path $Entrega "LEEME_PROFESOR.txt") $Instrucciones -Encoding UTF8

# 7) Validaciones
Write-Host ""
Write-Host "=== LISTO ===" -ForegroundColor Green
Write-Host "Carpeta de entrega: $Entrega" -ForegroundColor Green
Get-ChildItem $Entrega | Select-Object Name, Length | Format-Table -AutoSize

Write-Host ""
Write-Host "Abriendo carpeta de entrega..." -ForegroundColor Cyan
Start-Process $Entrega
