# PREPARAR ENTREGA - EXAMEN INDICADOR II
# Dorada Motors
# Ejecutar en PowerShell con XAMPP/MySQL encendido.

$ErrorActionPreference = "Stop"

$Proyecto = "C:\Users\CESAR\Desktop\dorada_motors"
$Backend = Join-Path $Proyecto "dorada_api"
$Desktop = [Environment]::GetFolderPath("Desktop")
$Entrega = Join-Path $Desktop "PROYECTO"
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

# 4) ZIP limpio del proyecto web + API + SQL
$TempBackend = Join-Path $env:TEMP "Dorada_Motors_WEB_API_ENTREGA"
if (Test-Path $TempBackend) {
    Remove-Item $TempBackend -Recurse -Force
}
New-Item -ItemType Directory -Path $TempBackend | Out-Null

Get-ChildItem $Backend -Force | Where-Object {
    $_.Name -notin @("
} | ForEach-Object {
    Copy-Item $_.FullName $TempBackend -Recurse -Force
}

$WebZip = Join-Path $Entrega "Dorada_Motors_WEB_API.zip"
Compress-Archive -Path "$TempBackend\*" -DestinationPath $WebZip -Force

# 5) Preparar copia limpia del proyecto Flutter
$TempFlutter = Join-Path $env:TEMP "Dorada_Motors_FLUTTER_ENTREGA"
if (Test-Path $TempFlutter) {
    Remove-Item $TempFlutter -Recurse -Force
}
New-Item -ItemType Directory -Path $TempFlutter | Out-Null

$ExcluirDirectorios = @(
    ".git",
    ".github",
    ".vscode",
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

Remove-Item (Join-Path $TempFlutter "dorada_motors.iml") -Force -ErrorAction SilentlyContinue

$FlutterZip = Join-Path $Entrega "Dorada_Motors_FLUTTER.zip"
Compress-Archive -Path "$TempFlutter\*" -DestinationPath $FlutterZip -Force


# 7) Crear ZIP final para entregar al profesor
$ZipFinal = Join-Path $Desktop "PROYECTO.zip"
if (Test-Path $ZipFinal) {
    Remove-Item $ZipFinal -Force
}
Compress-Archive -Path $Entrega -DestinationPath $ZipFinal -Force

# 8) Validaciones
Write-Host ""
Write-Host "=== LISTO ===" -ForegroundColor Green
Write-Host "Carpeta de entrega: $Entrega" -ForegroundColor Green
Write-Host "ZIP final: $ZipFinal" -ForegroundColor Green
Get-ChildItem $Entrega | Select-Object Name, Length | Format-Table -AutoSize

Write-Host ""
Write-Host "Abriendo carpeta de entrega..." -ForegroundColor Cyan
Start-Process $Entrega
