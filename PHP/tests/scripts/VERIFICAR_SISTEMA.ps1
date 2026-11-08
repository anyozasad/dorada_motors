# DORADA MOTORS - VERIFICACIÓN FUNCIONAL LOCAL
# Requiere XAMPP encendido. Ejecutar desde la carpeta del proyecto.
# Las pruebas de MySQL de PRUEBA_INTEGRACION.php revierten sus registros.
$ErrorActionPreference = 'Continue'
$Proyecto = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Flutter = Join-Path (Split-Path -Parent $Proyecto) 'Flutter'
$Backend = Join-Path $Proyecto 'dorada_api'
$BaseUrl = 'http://localhost/dorada_api'
$Php = @('C:\xampp\php\php.exe', 'D:\xampp\php\php.exe') |
  Where-Object { Test-Path $_ } |
  Select-Object -First 1

$Correctos = New-Object 'System.Collections.Generic.List[string]'
$Errores = New-Object 'System.Collections.Generic.List[string]'

function OK([string]$mensaje) {
  $Correctos.Add($mensaje)
  Write-Host "[OK] $mensaje" -ForegroundColor Green
}
function FAIL([string]$mensaje) {
  $Errores.Add($mensaje)
  Write-Host "[ERROR] $mensaje" -ForegroundColor Red
}

Write-Host '--- DORADA MOTORS: REVISIÓN DE FUNCIONES REALES ---' -ForegroundColor Cyan
if (!(Test-Path (Join-Path $Flutter 'pubspec.yaml'))) {
  FAIL 'Ejecuta el archivo desde la carpeta raíz del repositorio Flutter.'
}
if (!(Test-Path $Backend)) {
  FAIL 'No se encontró dorada_api.'
}

# 1: PHP y conexión pública.
if (!$Php) {
  FAIL 'No se encontró XAMPP PHP en C:\xampp o D:\xampp.'
} else {
  $archivos = Get-ChildItem $Backend -Filter '*.php' -Recurse -File
  foreach ($archivo in $archivos) {
    $null = & $Php -l $archivo.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { FAIL "Sintaxis PHP: $($archivo.Name)" }
  }
  if (($Errores | Where-Object { $_ -like 'Sintaxis PHP:*' }).Count -eq 0) {
    OK "Sintaxis de $($archivos.Count) archivos PHP"
  }
}

foreach ($archivo in @('productos.php','categorias.php','marcas.php','config_publica.php')) {
  try {
    $respuesta = Invoke-WebRequest "$BaseUrl/$archivo" -UseBasicParsing -TimeoutSec 15
    $null = $respuesta.Content | ConvertFrom-Json
    if ($respuesta.StatusCode -eq 200) {
      OK "Ruta pública JSON: $archivo"
    } else {
      FAIL "Ruta pública $archivo devolvió HTTP $($respuesta.StatusCode)"
    }
  } catch {
    FAIL "API ${archivo}: $($_.Exception.Message)"
  }
}

# Seguridad de instalación: Apache no debe publicar el esquema SQL ni archivos internos.
# Este control se ejecuta contra XAMPP; el servidor integrado php -S no interpreta .htaccess.
foreach ($rutaPrivada in @('dorada_motors.sql','data/config_empresa.json')) {
  $codigo = 0
  try {
    $r = Invoke-WebRequest "$BaseUrl/$rutaPrivada" -UseBasicParsing -TimeoutSec 15
    $codigo = [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $codigo = [int]$_.Exception.Response.StatusCode
    }
  }
  if ($codigo -in @(403,404)) {
    OK "Apache protege: $rutaPrivada (HTTP $codigo)"
  } else {
    FAIL "Archivo expuesto o sin respuesta: $rutaPrivada (HTTP $codigo); revisa .htaccess / AllowOverride."
  }
}

# 2: Las rutas privadas deben denegar consultas sin sesión.
foreach ($archivo in @('cuenta.php','soporte.php','pedidos.php')) {
  $estado = 0
  try {
    $resp = Invoke-WebRequest "$BaseUrl/$archivo" -UseBasicParsing -TimeoutSec 15
    $estado = [int]$resp.StatusCode
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $estado = [int]$_.Exception.Response.StatusCode
    }
  }
  if ($estado -eq 401) {
    OK "Seguridad: $archivo exige iniciar sesión"
  } else {
    FAIL "Seguridad: $archivo respondió HTTP $estado; se esperaba 401"
  }
}

try {
  $login = Invoke-WebRequest "$BaseUrl/admin_login.php" -UseBasicParsing -TimeoutSec 15
  if ($login.StatusCode -eq 200 -and $login.Content -match 'csrf_token') {
    OK 'Acceso administrativo con CSRF'
  } else {
    FAIL 'No se pudo verificar el acceso administrativo'
  }
} catch {
  FAIL "Panel PHP: $($_.Exception.Message)"
}

# 3: Escritura y relaciones: transacción que se revierte.
if ($Php -and (Test-Path (Join-Path $Proyecto 'tests\PRUEBA_INTEGRACION.php'))) {
  $salida = & $Php (Join-Path $Proyecto 'tests\PRUEBA_INTEGRACION.php') 2>&1
  if ($LASTEXITCODE -eq 0 -and ($salida -join "`n") -match 'INTEGRACION_OK') {
    OK 'Transacciones MySQL: clientes, productos, proveedores, compras, pedidos, stock y comprobantes'
  } else {
    FAIL "Prueba MySQL: $($salida -join ' | ')"
  }
} else {
  FAIL 'No se puede ejecutar la prueba transaccional local.'
}

# 4: La lista de 150 es un control estructural, no prueba 150 acciones.
if ($Php -and (Test-Path (Join-Path $Proyecto 'tests\VALIDAR_DASHBOARD_150.php'))) {
  $salida = & $Php (Join-Path $Proyecto 'tests\VALIDAR_DASHBOARD_150.php') 2>&1
  if ($LASTEXITCODE -eq 0 -and ($salida -join "`n") -match 'REQUERIMIENTOS_DASHBOARD: 150/150') {
    OK 'Los 150 puntos están enumerados y sus elementos estructurales están presentes'
  } else {
    FAIL "Control estructural: $($salida -join ' | ')"
  }
}

# 5: Flutter: análisis, tests y compilación Web para presentación.
Push-Location $Flutter
try {
  foreach ($comando in @('pub get','analyze','test','build web --release')) {
    $argumentos = $comando.Split(' ')
    & flutter @argumentos
    if ($LASTEXITCODE -eq 0) {
      OK "Flutter $comando"
    } else {
      FAIL "Flutter $comando"
    }
  }
} catch {
  FAIL "Flutter no pudo ejecutarse: $($_.Exception.Message)"
} finally {
  Pop-Location
}

Write-Host ''
Write-Host "Verificaciones aprobadas: $($Correctos.Count); fallidas: $($Errores.Count)" -ForegroundColor Cyan
Write-Host 'Las operaciones completas PHP + MySQL también se prueban en GitHub Actions.' -ForegroundColor Cyan
Write-Host 'La lista de 150 puntos necesita además prueba funcional/manual con el profesor.' -ForegroundColor Yellow

if ($Errores.Count -gt 0) {
  foreach ($errorItem in $Errores) { Write-Host " - $errorItem" -ForegroundColor Red }
  exit 1
}
Write-Host 'PASARON las verificaciones automáticas locales ejecutadas.' -ForegroundColor Green
exit 0
