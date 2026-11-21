# Dorada Motors — Compilar UN APK instalable para telefono Android.
# No genera ZIP del proyecto ni copia datos personales.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$flutterDir = Join-Path $repo 'Flutter'
$pubspec = Join-Path $flutterDir 'pubspec.yaml'
if (!(Test-Path -LiteralPath $pubspec)) {
  throw "No se encontro Flutter/pubspec.yaml en: $flutterDir"
}
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "No se encontro Flutter en PowerShell. Comprueba flutter doctor y configura el PATH."
}
$desktop = [Environment]::GetFolderPath('Desktop')
$target = Join-Path $desktop 'DORADA_MOTORS_CELULAR.apk'
Push-Location $flutterDir
try {
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Fallo flutter pub get.' }
  & flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'Hay errores de Flutter analyze.' }
  & flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas Flutter.' }
  & flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion del APK Android.' }
  $apk = Join-Path $flutterDir 'build\app\outputs\flutter-apk\app-release.apk'
  if (!(Test-Path -LiteralPath $apk) -or (Get-Item $apk).Length -lt 100000) {
    throw 'Flutter no creo app-release.apk correctamente.'
  }
  Copy-Item -LiteralPath $apk -Destination $target -Force
} finally {
  Pop-Location
}
Write-Host ''
Write-Host 'APK PARA CELULAR PREPARADO' -ForegroundColor Green
Write-Host "Archivo: $target" -ForegroundColor Cyan
Write-Host 'Es una compilacion de demostracion firmada con la clave de desarrollo; no es una publicacion Play Store.' -ForegroundColor Yellow
Write-Host 'Conecta celular y PC a la misma red Wi-Fi, enciende Apache y MySQL en XAMPP.' -ForegroundColor Yellow
Write-Host 'En el telefono: Configurar conexion con PHP > http://IP_DE_LA_PC/dorada_api.' -ForegroundColor Cyan
$red = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
  Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address }
foreach ($interfaz in $red) {
  Write-Host ("IP de PC (" + $interfaz.InterfaceAlias + "): " + $interfaz.IPv4Address.IPAddress) -ForegroundColor Cyan
}
$adb = Get-Command adb -ErrorAction SilentlyContinue
if (!$adb) {
  $rutaAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
  if (Test-Path $rutaAdb) { $adb = @{ Source = $rutaAdb } }
}
if ($adb) {
  $devices = @(& $adb.Source devices)
  $conectados = @($devices | Where-Object { $_ -match '^\S+\s+device$' })
  if ($conectados.Count -eq 1) {
    Write-Host 'Se detecto un unico Android autorizado por USB. Instalando...' -ForegroundColor Cyan
    & $adb.Source install -r $target
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "La instalacion USB no finalizo. Puedes transferir el APK manualmente al telefono."
    }
  }
}
Write-Host 'Tambien puedes enviar el APK a tu telefono y abrirlo desde Mis archivos.' -ForegroundColor Green
