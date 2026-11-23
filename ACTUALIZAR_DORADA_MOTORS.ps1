# Dorada Motors. Actualizador de la rama main y del dashboard PHP / APK.
# Preserva cambios no publicados, bases MySQL, fotografias y datos del celular.
param(
  [switch]$SoloCodigo,
  [switch]$SinCompilarApk,
  [switch]$EjecutarPruebas
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Raiz = $PSScriptRoot
$UbicacionOriginal = Get-Location
function Verificar([string]$nombre) {
  if ($LASTEXITCODE -ne 0) { throw ('Error al ejecutar ' + $nombre) }
}
function Paso([string]$mensaje) {
  Write-Host ''
  Write-Host ('=== ' + $mensaje + ' ===') -ForegroundColor Cyan
}

if (!(Test-Path (Join-Path $Raiz 'Flutter\pubspec.yaml')) -or
    !(Test-Path (Join-Path $Raiz 'PHP\dorada_api\dashboard.php'))) {
  throw 'Coloca este archivo en la carpeta principal dorada_motors.'
}

try {
  Set-Location $Raiz
  Paso '1. Actualizar codigo del repositorio'
  if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'No se detecto Git en PowerShell.'
  }
  $Rama = (& git branch --show-current).Trim()
  Verificar 'git branch'
  if ($Rama -ne 'main') {
    throw 'No estas en main. No se cambiara de rama ni se borrara tu trabajo.'
  }
  $Cambios = @(& git status --porcelain --untracked-files=no)
  Verificar 'git status'
  if ($Cambios.Count -gt 0) {
    Write-Host ($Cambios -join [Environment]::NewLine) -ForegroundColor Yellow
    throw 'Tienes cambios locales sin guardar. No se hizo pull para protegerlos.'
  }
  & git pull --ff-only origin main
  Verificar 'git pull --ff-only origin main'
  if ($SoloCodigo) {
    Write-Host 'El codigo de Flutter y PHP esta actualizado.' -ForegroundColor Green
    exit 0
  }

  Paso '2. Copiar PHP a XAMPP sin borrar datos propios'
  $XamppRoots = @('C:\xampp\htdocs','D:\xampp\htdocs')
  $Htdocs = @($XamppRoots | Where-Object { Test-Path $_ } | Select-Object -First 1)
  if ($Htdocs.Count -gt 0) {
    $Origen = Join-Path $Raiz 'PHP\dorada_api'
    $Destino = Join-Path $Htdocs[0] 'dorada_api'
    New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    foreach ($Entrada in @(Get-ChildItem -LiteralPath $Origen -Force)) {
      if ($Entrada.Name -eq '.env') { continue }
      if ($Entrada.Name -eq 'data' -and $Entrada.PSIsContainer) {
        $Datos = Join-Path $Destino 'data'
        New-Item -ItemType Directory -Path $Datos -Force | Out-Null
        foreach ($Archivo in @(Get-ChildItem -LiteralPath $Entrada.FullName -Force)) {
          if ($Archivo.Name -eq 'config_empresa.json') { continue }
          Copy-Item -LiteralPath $Archivo.FullName -Destination $Datos -Recurse -Force
        }
        continue
      }
      Copy-Item -LiteralPath $Entrada.FullName -Destination $Destino -Recurse -Force
    }
    Write-Host ('Dashboard actualizado: ' + $Destino) -ForegroundColor Green
    Write-Host 'Se conservaron MySQL, imagenes uploads y configuracion local.'
  } else {
    Write-Host 'No se detecto XAMPP en C: o D:. Se omite el despliegue PHP.' -ForegroundColor Yellow
  }

  Paso '3. Compilar APK actualizado'
  if ($SinCompilarApk) {
    Write-Host 'Compilacion APK omitida por -SinCompilarApk.' -ForegroundColor Yellow
    exit 0
  }
  if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'Flutter no esta en PATH. Codigo y PHP estan actualizados.' -ForegroundColor Yellow
    Write-Host 'Puedes obtener el APK ya compilado en GitHub Actions > Flutter CI.'
    exit 0
  }
  Set-Location (Join-Path $Raiz 'Flutter')
  & flutter pub get
  Verificar 'flutter pub get'
  & flutter analyze
  Verificar 'flutter analyze'
  if ($EjecutarPruebas) {
    & flutter test
    Verificar 'flutter test'
  }
  & flutter build apk --release
  Verificar 'flutter build apk --release'
  $Apk = Join-Path (Get-Location) 'build\app\outputs\flutter-apk\app-release.apk'
  if (!(Test-Path $Apk) -or (Get-Item $Apk).Length -lt 10000000) {
    throw 'Falta el APK Android esperado o esta incompleto.'
  }
  $Escritorio = [Environment]::GetFolderPath('Desktop')
  if ($Escritorio -and (Test-Path $Escritorio)) {
    $Salida = Join-Path $Escritorio 'DORADA_MOTORS_LOCAL_ACTUALIZADO.apk'
    Copy-Item -LiteralPath $Apk -Destination $Salida -Force
  } else {
    $Salida = $Apk
  }
  Write-Host ('APK listo: ' + $Salida) -ForegroundColor Green
  Write-Host 'El modo local usa SQLite sin laptop. No sincroniza solo con MySQL.' -ForegroundColor Yellow
} finally {
  Set-Location $UbicacionOriginal
}
