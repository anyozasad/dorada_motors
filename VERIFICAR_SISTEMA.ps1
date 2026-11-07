# DORADA MOTORS - VERIFICACION FINAL DEL SISTEMA
# Ejecutar con Apache y MySQL encendidos en XAMPP.
# No modifica datos reales; verificar_bd.php usa una transaccion que se revierte.

$ErrorActionPreference = "Continue"
$Proyecto = "C:\Users\CESAR\Desktop\dorada_motors"
$Backend = Join-Path $Proyecto "dorada_api"
$Php = "C:\xampp\php\php.exe"
$BaseUrl = "http://localhost/dorada_api"

$Errores = New-Object System.Collections.Generic.List[string]
$Correctos = New-Object System.Collections.Generic.List[string]

function OK([string]$mensaje) {
    $Correctos.Add($mensaje)
    Write-Host "[OK] $mensaje" -ForegroundColor Green
}

function FAIL([string]$mensaje) {
    $Errores.Add($mensaje)
    Write-Host "[ERROR] $mensaje" -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " DORADA MOTORS - VERIFICACION FINAL" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path $Proyecto)) {
    FAIL "No existe el proyecto: $Proyecto"
    exit 1
}

if (!(Test-Path $Backend)) {
    FAIL "No existe el backend: $Backend"
    exit 1
}

# 1. PHP
Write-Host "1. Revisando sintaxis PHP..." -ForegroundColor Yellow
if (!(Test-Path $Php)) {
    FAIL "No se encontro PHP de XAMPP en $Php"
} else {
    $phpFiles = Get-ChildItem $Backend -Filter "*.php" -File
    foreach ($file in $phpFiles) {
        $salida = & $Php -l $file.FullName 2>&1
        if ($LASTEXITCODE -eq 0) {
            OK "PHP: $($file.Name)"
        } else {
            FAIL "PHP $($file.Name): $salida"
        }
    }
}

# 2. Backend y base de datos
Write-Host ""
Write-Host "2. Revisando Apache, API y MySQL..." -ForegroundColor Yellow
try {
    $db = Invoke-RestMethod "$BaseUrl/verificar_bd.php" -TimeoutSec 10
    if ($db.estado -eq $true -and
        $db.conexion_mysql -eq $true -and
        $db.base_datos -eq "dorada_motors" -and
        [int]$db.tablas_encontradas -eq 13 -and
        $db.escritura -eq $true) {
        OK "PHP conectado a MySQL dorada_motors con 13 tablas y escritura"
    } else {
        FAIL "La verificacion de base de datos no paso: $($db.mensaje)"
    }
} catch {
    FAIL "No responde verificar_bd.php. Revisa Apache y MySQL: $($_.Exception.Message)"
}

$endpoints = @(
    "productos.php",
    "usuarios.php",
    "pedidos.php",
    "dashboard_api.php"
)

foreach ($endpoint in $endpoints) {
    try {
        $resp = Invoke-WebRequest "$BaseUrl/$endpoint" -UseBasicParsing -TimeoutSec 10
        if ($resp.StatusCode -eq 200) {
            $null = $resp.Content | ConvertFrom-Json
            OK "API JSON: $endpoint"
        } else {
            FAIL "API $endpoint devolvio HTTP $($resp.StatusCode)"
        }
    } catch {
        FAIL "API $endpoint: $($_.Exception.Message)"
    }
}

try {
    $dash = Invoke-WebRequest "$BaseUrl/dashboard.php" -UseBasicParsing -TimeoutSec 10
    if ($dash.StatusCode -eq 200 -and $dash.Content -match "Panel v3\.0") {
        OK "Dashboard PHP v3.0 carga correctamente"
    } else {
        FAIL "Dashboard no cargo la version final esperada"
    }
} catch {
    FAIL "Dashboard PHP: $($_.Exception.Message)"
}

# 3. Flutter
Write-Host ""
Write-Host "3. Revisando Flutter..." -ForegroundColor Yellow
Push-Location $Proyecto

try {
    & flutter pub get
    if ($LASTEXITCODE -eq 0) {
        OK "flutter pub get"
    } else {
        FAIL "flutter pub get"
    }

    & flutter analyze
    if ($LASTEXITCODE -eq 0) {
        OK "flutter analyze sin errores"
    } else {
        FAIL "flutter analyze encontro problemas"
    }

    & flutter test
    if ($LASTEXITCODE -eq 0) {
        OK "flutter test"
    } else {
        FAIL "flutter test encontro fallas"
    }
} catch {
    FAIL "No se pudo ejecutar Flutter: $($_.Exception.Message)"
} finally {
    Pop-Location
}

# 4. Archivos esenciales
Write-Host ""
Write-Host "4. Revisando archivos esenciales..." -ForegroundColor Yellow
$archivos = @(
    "lib\main.dart",
    "lib\services\api_service.dart",
    "lib\screens\main_shell.dart",
    "lib\screens\checkout_screen.dart",
    "lib\screens\orders_screen.dart",
    "dorada_api\dashboard.php",
    "dorada_api\conexion.php",
    "dorada_api\productos.php",
    "dorada_api\usuarios.php",
    "dorada_api\pedidos.php",
    "dorada_api\pagos.php",
    "dorada_api\direcciones.php",
    "dorada_api\dashboard_api.php",
    "dorada_api\dorada_motors.sql"
)

foreach ($archivo in $archivos) {
    $ruta = Join-Path $Proyecto $archivo
    if (Test-Path $ruta) {
        OK "Archivo: $archivo"
    } else {
        FAIL "Falta archivo: $archivo"
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " RESULTADO" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Correctos: $($Correctos.Count)" -ForegroundColor Green
Write-Host "Errores:   $($Errores.Count)" -ForegroundColor $(if ($Errores.Count -eq 0) {"Green"} else {"Red"})

if ($Errores.Count -eq 0) {
    Write-Host ""
    Write-Host "SISTEMA APROBADO PARA LA PRUEBA FINAL." -ForegroundColor Green
    Write-Host "Dashboard + PHP API + MySQL + Flutter pasaron las verificaciones automaticas." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "FALTAN CORREGIR ESTOS PUNTOS:" -ForegroundColor Red
foreach ($errorItem in $Errores) {
    Write-Host " - $errorItem" -ForegroundColor Red
}
exit 1
