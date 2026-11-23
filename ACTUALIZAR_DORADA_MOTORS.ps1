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

  Paso '2. Verificar PHP y actualizar las copias reales de XAMPP'
  $XamppRoots = @('C:\xampp\htdocs','D:\xampp\htdocs')
  if ($env:XAMPP_HOME) { $XamppRoots += (Join-Path $env:XAMPP_HOME 'htdocs') }
  $Raices = @($XamppRoots | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique)
  if ($Raices.Count -eq 0) {
    throw 'Se actualizo GitHub, pero no hay XAMPP en C: ni D:. Tu localhost NO se actualizo. Configura XAMPP_HOME si esta instalado en otra ruta.'
  }

  $Origen = Join-Path $Raiz 'PHP\dorada_api'
  $ArchivoFuente = Join-Path $Origen 'dashboard.php'
  $ShaFuente = (Get-FileHash -LiteralPath $ArchivoFuente -Algorithm SHA256).Hash
  $VersionPanel = [regex]::Match(
    (Get-Content -LiteralPath $ArchivoFuente -Raw), 'Panel v[0-9]+(?:\.[0-9]+)*'
  ).Value

  # Evitar reemplazar PHP si el codigo no pasa la sintaxis.
  $PhpVerificado = $false
  foreach ($Htdocs in $Raices) {
    $PhpExe = Join-Path (Split-Path $Htdocs -Parent) 'php\php.exe'
    if (Test-Path -LiteralPath $PhpExe) {
      Paso 'Comprobar sintaxis PHP'
      foreach ($PhpFile in @(Get-ChildItem -LiteralPath $Origen -Recurse -Filter '*.php' -File)) {
        & $PhpExe -l $PhpFile.FullName | Out-Null
        Verificar ('PHP: ' + $PhpFile.Name)
      }
      $PhpVerificado = $true
      break
    }
  }
  if (!$PhpVerificado) {
    Write-Host 'No se encontro php.exe; falta validar sintaxis en esta laptop.' -ForegroundColor Yellow
  }

  # Localiza instalaciones en htdocs, incluidas las de proyectos con PHP/dorada_api.
  $Instalaciones = New-Object 'System.Collections.Generic.List[string]'
  foreach ($Htdocs in $Raices) {
    $Candidatos = New-Object 'System.Collections.Generic.List[string]'
    foreach ($Relativa in @('dorada_api','PHP\dorada_api','dorada_motors\PHP\dorada_api','dorada_motors\dorada_api')) {
      $Candidatos.Add((Join-Path $Htdocs $Relativa))
    }
    foreach ($Carpeta in @(Get-ChildItem -LiteralPath $Htdocs -Directory -ErrorAction SilentlyContinue)) {
      foreach ($Relativa in @('PHP\dorada_api','dorada_api')) {
        $Candidatos.Add((Join-Path $Carpeta.FullName $Relativa))
      }
    }
    foreach ($Candidato in $Candidatos) {
      $DashboardLocal = Join-Path $Candidato 'dashboard.php'
      if (!(Test-Path -LiteralPath $DashboardLocal)) { continue }
      $Cabecera = (Get-Content -LiteralPath $DashboardLocal -TotalCount 10 -ErrorAction SilentlyContinue) -join ' '
      if ($Cabecera -notmatch 'auth_admin\.php|empresa_config\.php') { continue }
      if (!$Instalaciones.Contains($Candidato)) { $Instalaciones.Add($Candidato) }
    }
  }

  if ($Instalaciones.Count -eq 0) {
    $Instalaciones.Add((Join-Path $Raices[0] 'dorada_api'))
    Write-Host 'No existia un dashboard instalado. Se creara en /dorada_api.' -ForegroundColor Yellow
  }
  Write-Host ('Copias activas del dashboard encontradas: ' + $Instalaciones.Count) -ForegroundColor Cyan

  foreach ($Destino in $Instalaciones) {
    New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    $OrigenNormalizado = [System.IO.Path]::GetFullPath($Origen).TrimEnd('\')
    $DestinoNormalizado = [System.IO.Path]::GetFullPath($Destino).TrimEnd('\')

    if ($OrigenNormalizado -ine $DestinoNormalizado) {
      foreach ($Entrada in @(Get-ChildItem -LiteralPath $Origen -Force)) {
        if ($Entrada.Name -eq '.env') { continue }
        if ($Entrada.Name -eq 'uploads' -and $Entrada.PSIsContainer) {
          # Preservar imagenes subidas por el usuario.
          if (!(Test-Path -LiteralPath (Join-Path $Destino 'uploads'))) {
            Copy-Item -LiteralPath $Entrada.FullName -Destination $Destino -Recurse -Force
          }
          continue
        }
        if ($Entrada.Name -eq 'data' -and $Entrada.PSIsContainer) {
          $DatosDestino = Join-Path $Destino 'data'
          New-Item -ItemType Directory -Path $DatosDestino -Force | Out-Null
          foreach ($Archivo in @(Get-ChildItem -LiteralPath $Entrada.FullName -Force)) {
            if ($Archivo.Name -in @('config_empresa.json','auditoria.jsonl')) { continue }
            $RutaDestino = Join-Path $DatosDestino $Archivo.Name
            if (!(Test-Path -LiteralPath $RutaDestino)) {
              Copy-Item -LiteralPath $Archivo.FullName -Destination $DatosDestino -Recurse -Force
            }
          }
          continue
        }
        Copy-Item -LiteralPath $Entrada.FullName -Destination $Destino -Recurse -Force
      }
    }

    $ShaInstalado = (Get-FileHash -LiteralPath (Join-Path $Destino 'dashboard.php') -Algorithm SHA256).Hash
    if ($ShaInstalado -ne $ShaFuente) {
      throw ('FALLO: la copia abierta en XAMPP no se actualizo: ' + $Destino)
    }
    Write-Host ('OK DASHBOARD: ' + $Destino + ' / ' + $VersionPanel + ' / git ' + $CommitActual) -ForegroundColor Green
    foreach ($Htdocs in $Raices) {
      $BaseWeb = [System.IO.Path]::GetFullPath($Htdocs).TrimEnd('\') + '\'
      if ($DestinoNormalizado.StartsWith($BaseWeb,[System.StringComparison]::OrdinalIgnoreCase)) {
        $RutaWeb = $DestinoNormalizado.Substring($BaseWeb.Length).Replace('\','/')
        Write-Host ('ABRE ESTA DIRECCION: http://localhost/' + $RutaWeb + '/admin_login.php') -ForegroundColor Cyan
        break
      }
    }
  }
  Write-Host 'Archivo PHP actualizado, hash SHA256 verificado. MySQL, fotos y configuracion local preservados.' -ForegroundColor Green
  Write-Host 'Si la pagina se ve igual, abre la URL impresa arriba y pulsa Ctrl+F5.' -ForegroundColor Yellow

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
