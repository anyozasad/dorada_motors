# Dorada Motors - inicio de demostración Flutter + PHP + MySQL (Windows)
# Ejecutar desde PowerShell: powershell -ExecutionPolicy Bypass -File .\INICIAR_DEMO.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    throw "No se encontró pubspec.yaml. Ejecuta el script dentro del repositorio Dorada Motors."
}

$htdocsPosibles = @(
    "C:\xampp\htdocs",
    "D:\xampp\htdocs"
)
$htdocs = $htdocsPosibles | Where-Object { Test-Path $_ -PathType Container } | Select-Object -First 1
if (-not $htdocs) {
    throw "No se encontró XAMPP. Instálalo o copia dorada_api a la carpeta htdocs de tu Apache."
}

$apiLocal = Join-Path $root "dorada_api"
$apiDestino = Join-Path $htdocs "dorada_api"
if (-not (Test-Path $apiDestino)) {
    New-Item -ItemType Directory -Path $apiDestino -Force | Out-Null
}
Write-Host "[1/5] Actualizando PHP, esquema e imágenes del dashboard..." -ForegroundColor Cyan
Copy-Item -Path (Join-Path $apiLocal "*") -Destination $apiDestino -Force -Recurse

$phpExe = Join-Path (Split-Path $htdocs -Parent) "php\php.exe"
if (Test-Path $phpExe) {
    Write-Host "[2/5] Comprobando sintaxis PHP..." -ForegroundColor Cyan
    Get-ChildItem -Path $apiDestino -Filter "*.php" -Recurse | ForEach-Object {
        & $phpExe -l $_.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Error PHP: $($_.FullName)" }
    }
    Write-Host "Sintaxis PHP sin errores." -ForegroundColor Green
} else {
    Write-Warning "No se encontró php.exe para revisar sintaxis; compruébala en tu instalación."
}

Write-Host "[3/5] Comprobando acceso a la API..." -ForegroundColor Cyan
try {
    $res = Invoke-WebRequest "http://localhost/dorada_api/productos.php" -UseBasicParsing -TimeoutSec 15
    if ($res.StatusCode -ne 200) { throw "HTTP $($res.StatusCode)" }
    Write-Host "API disponible. Abriendo acceso administrativo." -ForegroundColor Green
    Start-Process "http://localhost/dorada_api/admin_login.php"
} catch {
    throw "La API no responde: enciende Apache y MySQL en XAMPP y comprueba http://localhost/dorada_api/productos.php. $($_.Exception.Message)"
}

Write-Host "[4/5] Instalando dependencias Flutter..." -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "Falló flutter pub get. Si Windows indica error de symlink, abre ms-settings:developers y activa el Modo de desarrollador."
}

Write-Host "Comprobando Flutter (análisis)..." -ForegroundColor Cyan
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw "Flutter detectó errores de análisis. Revisa la salida anterior." }

Write-Host "Comprobando Flutter (pruebas)..." -ForegroundColor Cyan
& flutter test
if ($LASTEXITCODE -ne 0) { throw "No pasaron todas las pruebas de Flutter." }

Write-Host "[5/5] Ejecutando Flutter Web en Chrome..." -ForegroundColor Green
& flutter run -d chrome --web-port 8080
if ($LASTEXITCODE -ne 0) {
    throw "Flutter no pudo iniciar. Ejecuta flutter analyze para revisar el error."
}
