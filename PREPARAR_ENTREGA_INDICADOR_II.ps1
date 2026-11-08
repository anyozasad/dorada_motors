# DORADA MOTORS - EMPAQUETAR PROYECTO COMPLETO Y ENTREGABLES
# Uso:
# powershell -ExecutionPolicy Bypass -File .\PREPARAR_ENTREGA_INDICADOR_II.ps1
# Paquetes separados opcionales:
# powershell -ExecutionPolicy Bypass -File .\PREPARAR_ENTREGA_INDICADOR_II.ps1 -PaquetesSeparados
# Este script NO modifica el proyecto original ni exporta datos privados de clientes.

param(
  [switch]$PaquetesSeparados
)

$ErrorActionPreference = 'Stop'
$Proyecto = $PSScriptRoot
$Desktop = [Environment]::GetFolderPath('Desktop')
$Entrega = Join-Path $Desktop 'ENTREGA_DORADA_MOTORS'
$ZipFinal = Join-Path $Desktop 'ENTREGA_DORADA_MOTORS.zip'
$Temporal = Join-Path $env:TEMP 'DORADA_MOTORS_ENTREGA_TEMP'
$ProyectoTemporal = Join-Path $Temporal 'dorada_motors'

if (!(Test-Path (Join-Path $Proyecto 'pubspec.yaml')) -or
    !(Test-Path (Join-Path $Proyecto 'dorada_api\dashboard.php'))) {
  throw 'No se encontró el proyecto completo Flutter + PHP. Ejecuta el script desde la carpeta del repositorio.'
}

Write-Host 'Preparando entrega Dorada Motors...' -ForegroundColor Cyan
if (Test-Path $Temporal) { Remove-Item $Temporal -Recurse -Force }
if (Test-Path $Entrega) { Remove-Item $Entrega -Recurse -Force }
if (Test-Path $ZipFinal) { Remove-Item $ZipFinal -Force }
New-Item -ItemType Directory -Path $ProyectoTemporal -Force | Out-Null
New-Item -ItemType Directory -Path $Entrega -Force | Out-Null

# Copiar solamente archivos fuente, assets, API, SQL y pruebas.
$argumentos = @(
  $Proyecto, $ProyectoTemporal, '/E', '/NFL', '/NDL',
  '/NJH', '/NJS', '/NP', '/XD',
  (Join-Path $Proyecto '.git'),
  (Join-Path $Proyecto '.dart_tool'),
  (Join-Path $Proyecto 'build'),
  (Join-Path $Proyecto '.idea'),
  (Join-Path $Proyecto '.vscode'),
  '/XF', '*.zip', '*.iml', '.env', '*.log'
)
& robocopy @argumentos | Out-Null
if ($LASTEXITCODE -gt 7) { throw 'No se pudo copiar el código fuente del proyecto.' }

# Excluir secretos, sesiones locales, auditoría y clientes reales.
$Privados = @(
  'dorada_api\data',
  'dorada_api\uploads\privado',
  'dorada_api\.env'
)
foreach ($relativa in $Privados) {
  $ruta = Join-Path $ProyectoTemporal $relativa
  if (Test-Path $ruta) { Remove-Item $ruta -Recurse -Force }
}

# Mantener la protección Apache de la carpeta operativa, sin copiar auditoría ni datos.
$DataDestino = Join-Path $ProyectoTemporal 'dorada_api\data'
New-Item -ItemType Directory -Path $DataDestino -Force | Out-Null
$ReglaPrivada = Join-Path $Proyecto 'dorada_api\data\.htaccess'
if (Test-Path $ReglaPrivada) {
  Copy-Item $ReglaPrivada (Join-Path $DataDestino '.htaccess') -Force
}

$SqlFuente = Join-Path $Proyecto 'dorada_api\dorada_motors.sql'
$SqlEntrega = Join-Path $Entrega 'Dorada_Motors_BD.sql'
Copy-Item $SqlFuente $SqlEntrega -Force

# Entrega principal: incluye Flutter, PHP, MySQL, imágenes locales y pruebas.
$ZipCompleto = Join-Path $Entrega 'Dorada_Motors_PROYECTO_COMPLETO.zip'
Compress-Archive -Path (Join-Path $ProyectoTemporal '*') -DestinationPath $ZipCompleto -CompressionLevel Optimal -Force

foreach ($recurso in @(
  'dorada_api\LEEME_PROFESOR.txt',
  'CONTROL_150_FUNCIONES.txt',
  'MATRIZ_VALIDACION_FUNCIONAL_150.md'
)) {
  $origen = Join-Path $ProyectoTemporal $recurso
  if (Test-Path $origen) {
    Copy-Item $origen (Join-Path $Entrega (Split-Path $recurso -Leaf)) -Force
  }
}

# Opcional: los paquetes separados que algunas evaluaciones solicitan.
if ($PaquetesSeparados) {
  $ZipWeb = Join-Path $Entrega 'Dorada_Motors_WEB_API.zip'
  $ZipFlutter = Join-Path $Entrega 'Dorada_Motors_FLUTTER.zip'

  $SoloBackend = Join-Path $Temporal 'solo_backend\dorada_api'
  New-Item -ItemType Directory -Path $SoloBackend -Force | Out-Null
  Copy-Item (Join-Path $ProyectoTemporal 'dorada_api\*') $SoloBackend -Recurse -Force
  Compress-Archive -Path (Join-Path $Temporal 'solo_backend\dorada_api') -DestinationPath $ZipWeb -Force

  $SoloFlutter = Join-Path $Temporal 'solo_flutter'
  New-Item -ItemType Directory -Path $SoloFlutter -Force | Out-Null
  foreach ($item in (Get-ChildItem $ProyectoTemporal -Force)) {
    if ($item.Name -ne 'dorada_api') {
      Copy-Item $item.FullName $SoloFlutter -Recurse -Force
    }
  }
  Compress-Archive -Path (Join-Path $SoloFlutter '*') -DestinationPath $ZipFlutter -Force
}

# Comprobar que existen los archivos de entrega y que contienen bytes.
foreach ($archivo in @($SqlEntrega,$ZipCompleto)) {
  if (!(Test-Path $archivo) -or (Get-Item $archivo).Length -le 100) {
    throw "El archivo está ausente o vacío: $archivo"
  }
}

Compress-Archive -Path $Entrega -DestinationPath $ZipFinal -CompressionLevel Optimal -Force
Write-Host ''
Write-Host 'ENTREGA CREADA CORRECTAMENTE' -ForegroundColor Green
Write-Host "Carpeta: $Entrega" -ForegroundColor Green
Write-Host "ZIP final: $ZipFinal" -ForegroundColor Green
Write-Host 'El ZIP completo incluye Flutter y el dashboard PHP con carrito, favoritos y soporte.' -ForegroundColor Cyan
Write-Host 'No se exportaron usuarios, contraseñas ni pedidos reales de MySQL.' -ForegroundColor Cyan
Get-ChildItem $Entrega | Select-Object Name,Length | Format-Table -AutoSize
