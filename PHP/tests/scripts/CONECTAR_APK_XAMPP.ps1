# Dorada Motors: instala PHP actualizado en XAMPP sin borrar datos existentes.
# Ejecutar desde la raiz: powershell -NoProfile -ExecutionPolicy Bypass -File ".\PHP\tests\scripts\CONECTAR_APK_XAMPP.ps1"
$ErrorActionPreference = "Stop"
$phpRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$origen = Join-Path $phpRoot "dorada_api"
$htdocs = @("C:\xampp\htdocs", "D:\xampp\htdocs") |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if (-not $htdocs) {
    throw "XAMPP no se encuentra en C:\xampp o D:\xampp."
}
if (-not (Test-Path -LiteralPath (Join-Path $origen "conexion_estado.php"))) {
    throw "Actualiza la rama main con git pull: falta conexion_estado.php."
}
$destino = Join-Path $htdocs "dorada_api"
New-Item -ItemType Directory -Force -Path $destino | Out-Null

Write-Host "[1/3] Actualizando backend PHP en XAMPP..." -ForegroundColor Cyan
Get-ChildItem -LiteralPath $origen -File -Force -Recurse | ForEach-Object {
    $relativo = $_.FullName.Substring($origen.Length + 1)
    # Conserva la configuracion local y las fotos subidas por el administrador.
    if ($relativo -match '^data\\' -and $relativo -ne 'data\.htaccess') { return }
    if ($relativo -match '^uploads\\') { return }
    $archivoDestino = Join-Path $destino $relativo
    New-Item -ItemType Directory -Force -Path (Split-Path $archivoDestino -Parent) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $archivoDestino -Force
}
Write-Host "PHP actualizado. No se borro la base de datos." -ForegroundColor Green

Write-Host "[2/3] Verificando API y tablas MySQL de Dorada Motors..." -ForegroundColor Cyan
try {
    $respuesta = Invoke-RestMethod -Uri "http://localhost/dorada_api/conexion_estado.php" -Method Get -TimeoutSec 20
} catch {
    throw "La API no responde. Enciende Apache y MySQL en XAMPP. Detalle: $($_.Exception.Message)"
}
if ($respuesta.estado -ne $true -or $respuesta.api -ne "dorada_motors" -or [int]$respuesta.tablas_verificadas -lt 10) {
    throw "La API no esta conectada a la base MySQL esperada."
}
Write-Host "Conectado: PHP, MySQL y $($respuesta.tablas_verificadas) tablas verificadas." -ForegroundColor Green

Write-Host "[3/3] Direccion para conectar el Samsung..." -ForegroundColor Cyan
$interfaces = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue |
    Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address })
foreach ($interfaz in $interfaces) {
    $ip = $interfaz.IPv4Address.IPAddress
    Write-Host "$($interfaz.InterfaceAlias): http://$ip/dorada_api" -ForegroundColor Green
}
if ($interfaces.Count -eq 0) {
    Write-Warning "No se detecto IP de la red. Ejecuta ipconfig y busca IPv4 de Wi-Fi."
}
Write-Host "Samsung: Configurar conexion con PHP > escribir IP > Probar conexion." -ForegroundColor Yellow
Write-Host "Si no conecta, usa la misma Wi-Fi y permite Apache en el Firewall." -ForegroundColor Yellow
