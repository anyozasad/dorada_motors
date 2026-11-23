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
  # Impedir actualizar otro repositorio por accidente.
  $OrigenGit = (& git remote get-url origin).Trim()
  Verificar 'git remote'
  if ($OrigenGit -notmatch '(?i)github\.com[:/]anyozasad/dorada_motors(?:\.git)?/?$') {
    throw ('Esta carpeta no corresponde a Dorada Motors. Git origin: ' + $OrigenGit)
  }
  $Rama = (& git branch --show-current).Trim()
  Verificar 'git branch'
  if ($Rama -ne 'main') {
    throw 'No estas en main. No se cambiara de rama ni se borrara tu trabajo.'
  }
  $Cambios = @(& git status --porcelain --untracked-files=no)
  Verificar 'git status'
  if ($Cambios.Count -gt 0) {
    # No sobrescribir trabajo del estudiante. Guardar cambios rastreados en Git
    # sin incluir fotos nuevas, .env, bases SQLite ni otros archivos sin seguimiento.
    $FechaRespaldo = Get-Date -Format 'yyyyMMdd_HHmmss'
    & git stash push -m ("respaldo_dorada_antes_de_actualizar_" + $FechaRespaldo)
    Verificar 'respaldo git stash'
    Write-Host 'Se protegieron tus modificaciones locales en git stash.' -ForegroundColor Yellow
  }
  & git pull --ff-only origin main
  Verificar 'git pull --ff-only origin main'
  $CommitActual = (& git rev-parse --short HEAD).Trim()
  Verificar 'git rev-parse'
  Write-Host ('Version de GitHub instalada: ' + $CommitActual) -ForegroundColor Green

  if ($SoloCodigo) {
    Write-Host 'El codigo de Flutter y PHP esta actualizado.' -ForegroundColor Green
    exit 0
  }

  Paso '2. Validar PHP y actualizar XAMPP sin borrar datos'
  $XamppRoots = @('C:\xampp\htdocs','D:\xampp\htdocs')
  $Raices = @($XamppRoots | Where-Object { Test-Path $_ })
  if ($Raices.Count -gt 0) {
    $Origen = Join-Path $Raiz 'PHP\dorada_api'
    $Sitios = New-Object 'System.Collections.Generic.List[string]'
    foreach ($Htdocs in $Raices) {
      $Existentes = @()
      foreach ($Relativa in @('dorada_api','dorada_motors\PHP\dorada_api','dorada_motors\dorada_api')) {
        $Ruta = Join-Path $Htdocs $Relativa
        if (Test-Path (Join-Path $Ruta 'dashboard.php')) {
          $Existentes += $Ruta
        }
      }
      if ($Existentes.Count -eq 0) {
        $Existentes += (Join-Path $Htdocs 'dorada_api')
      }
      foreach ($Sitio in $Existentes) { $Sitios.Add($Sitio) }
    }

    foreach ($Htdocs in $Raices) {
      $PhpExe = Join-Path (Split-Path $Htdocs -Parent) 'php\php.exe'
      if (Test-Path $PhpExe) {
        Paso 'Comprobar sintaxis de PHP antes de desplegar'
        foreach ($PhpFile in @(Get-ChildItem -LiteralPath $Origen -Recurse -Filter '*.php' -File)) {
          & $PhpExe -l $PhpFile.FullName | Out-Null
          Verificar ('PHP ' + $PhpFile.Name)
        }
        break
      }
    }

    foreach ($Destino in $Sitios) {
      New-Item -ItemType Directory -Path $Destino -Force | Out-Null
      foreach ($Entrada in @(Get-ChildItem -LiteralPath $Origen -Force)) {
        if ($Entrada.Name -eq '.env') { continue }
        if ($Entrada.Name -eq 'uploads' -and $Entrada.PSIsContainer) {
          # Conservar fotos que el administrador ya subio a su instalacion.
          $CarpetaFotos = Join-Path $Destino 'uploads'
          if (!(Test-Path $CarpetaFotos)) {
            Copy-Item -LiteralPath $Entrada.FullName -Destination $Destino -Recurse -Force
          }
          continue
        }
        if ($Entrada.Name -eq 'data' -and $Entrada.PSIsContainer) {
          $Datos = Join-Path $Destino 'data'
          New-Item -ItemType Directory -Path $Datos -Force | Out-Null
          foreach ($Archivo in @(Get-ChildItem -LiteralPath $Entrada.FullName -Force)) {
            if ($Archivo.Name -in @('config_empresa.json','auditoria.jsonl')) { continue }
            if (!(Test-Path (Join-Path $Datos $Archivo.Name))) {
              Copy-Item -LiteralPath $Archivo.FullName -Destination $Datos -Recurse -Force
            }
          }
          continue
        }
        Copy-Item -LiteralPath $Entrada.FullName -Destination $Destino -Recurse -Force
      }
      $FuenteSha = (Get-FileHash -LiteralPath (Join-Path $Origen 'dashboard.php') -Algorithm SHA256).Hash
      $CopiaSha = (Get-FileHash -LiteralPath (Join-Path $Destino 'dashboard.php') -Algorithm SHA256).Hash
      if ($FuenteSha -ne $CopiaSha) {
        throw ('El dashboard instalado no coincide con GitHub en ' + $Destino)
      }
      Write-Host ('Dashboard PHP actualizado y verificado: ' + $Destino) -ForegroundColor Green
    }
    Write-Host 'Se preservaron bases MySQL, fotos y configuraciones locales.' -ForegroundColor Green
    Write-Host 'Abre http://localhost/dorada_api/admin_login.php y pulsa Ctrl+F5.' -ForegroundColor Cyan
  } else {
    Write-Host 'XAMPP no existe en C:\xampp o D:\xampp. PHP queda actualizado solo en Git.' -ForegroundColor Yellow
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
