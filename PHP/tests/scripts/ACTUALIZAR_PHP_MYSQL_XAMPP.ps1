# Dorada Motors: actualizar y probar SOLO PHP/MySQL de XAMPP (no Flutter).
# No borra tablas ni registros. Hace respaldo antes de las migraciones.
param([switch]$SinGit)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$Origen = Join-Path $Raiz 'PHP\dorada_api'
if (!(Test-Path (Join-Path $Origen 'dashboard.php'))) {
    throw 'No se encontro PHP\dorada_api\dashboard.php en el proyecto.'
}
$Xampp = @('C:\xampp','D:\xampp') | Where-Object {
    Test-Path (Join-Path $_ 'htdocs')
} | Select-Object -First 1
if (!$Xampp) { throw 'No se encontro XAMPP en C: o D:.' }
$Php = Join-Path $Xampp 'php\php.exe'
$Mysql = Join-Path $Xampp 'mysql\bin\mysql.exe'
$Dump = Join-Path $Xampp 'mysql\bin\mysqldump.exe'
foreach ($Exe in @($Php,$Mysql,$Dump)) {
    if (!(Test-Path $Exe)) { throw ('Falta ' + $Exe) }
}
$DbName = if ($env:DB_NAME) { $env:DB_NAME } else { 'dorada_motors' }
$DbUser = if ($env:DB_USER) { $env:DB_USER } else { 'root' }
$DbHost = if ($env:DB_HOST) { $env:DB_HOST } else { '127.0.0.1' }
$DbPort = if ($env:DB_PORT) { $env:DB_PORT } else { '3306' }
if ($DbName -notmatch '^[a-zA-Z0-9_]{1,64}$' -or $DbPort -notmatch '^[0-9]{1,5}$') {
    throw 'Revisa DB_NAME o DB_PORT.'
}
$Destino = Join-Path $Xampp 'htdocs\dorada_api'
$Respaldos = Join-Path $Xampp 'respaldo_dorada_motors'
$Marca = Get-Date -Format 'yyyyMMdd_HHmmss'
$Anterior = Get-Location
$ClaveMysqlAnterior = $env:MYSQL_PWD
try {
    Set-Location $Raiz
    Write-Host '[1/6] Actualizar GitHub (solo despliegue PHP)' -ForegroundColor Cyan
    if (!$SinGit) {
        if (!(Get-Command git -ErrorAction SilentlyContinue)) {
            throw 'Falta Git. Puedes usar -SinGit para copiar los archivos descargados.'
        }
        $Rama = (& git branch --show-current).Trim()
        if ($LASTEXITCODE -ne 0 -or $Rama -ne 'main') {
            throw 'Debes estar en la rama main. No se cambio ninguna rama.'
        }
        $Cambios = @(& git status --porcelain --untracked-files=no)
        if ($LASTEXITCODE -ne 0 -or $Cambios.Count -gt 0) {
            throw 'Hay cambios locales sin guardar. No se borraron ni sobrescribieron.'
        }
        & git pull --ff-only origin main
        if ($LASTEXITCODE -ne 0) { throw 'Git pull fallo. No se modifico XAMPP.' }
    }
    Write-Host '[2/6] Validar sintaxis PHP' -ForegroundColor Cyan
    $Archivos = @(Get-ChildItem -LiteralPath $Origen -Filter '*.php' -File -Recurse)
    foreach ($Archivo in $Archivos) {
        $null = & $Php -l $Archivo.FullName
        if ($LASTEXITCODE -ne 0) { throw ('Error PHP: ' + $Archivo.FullName) }
    }
    Write-Host ('PHP sin errores: ' + $Archivos.Count + ' archivos') -ForegroundColor Green

    Write-Host '[3/6] Respaldar base de datos antes de actualizar' -ForegroundColor Cyan
    $env:MYSQL_PWD = if ($env:DB_PASS) { $env:DB_PASS } else { '' }
    $Existe = @(& $Mysql -h $DbHost -P $DbPort -u $DbUser --batch --skip-column-names -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DbName'")
    if ($LASTEXITCODE -ne 0) { throw 'MySQL no responde. Activa MySQL en XAMPP y revisa las credenciales.' }
    New-Item -ItemType Directory -Path $Respaldos -Force | Out-Null
    if ($Existe.Count -gt 0 -and $Existe[0] -eq $DbName) {
        $SqlBackup = Join-Path $Respaldos ('bd_' + $Marca + '.sql')
        $SqlError = Join-Path $Respaldos ('bd_' + $Marca + '.err.txt')
        $Opciones = @('-h',$DbHost,'-P',$DbPort,'-u',$DbUser,
          '--single-transaction','--quick','--routines','--triggers',
          '--default-character-set=utf8mb4','--databases',$DbName)
        $Proceso = Start-Process -FilePath $Dump -ArgumentList $Opciones -PassThru -Wait -NoNewWindow -RedirectStandardOutput $SqlBackup -RedirectStandardError $SqlError
        if ($Proceso.ExitCode -ne 0 -or !(Test-Path $SqlBackup) -or
            (Get-Item $SqlBackup).Length -lt 500) {
            throw ('El respaldo MySQL fallo. No se cambiaron archivos. Revisa ' + $SqlError)
        }
        Write-Host ('MySQL respaldado: ' + $SqlBackup) -ForegroundColor Green
    } else {
        Write-Host 'La base no existe; la API creara sus tablas al primer acceso.'
    }

    Write-Host '[4/6] Respaldar y copiar PHP al servidor XAMPP' -ForegroundColor Cyan
    if (Test-Path $Destino) {
        $PhpBackup = Join-Path $Respaldos ('php_' + $Marca)
        Copy-Item -LiteralPath $Destino -Destination $PhpBackup -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    foreach ($Entrada in @(Get-ChildItem -LiteralPath $Origen -Force)) {
        if ($Entrada.Name -eq '.env' -or $Entrada.Name -eq 'uploads') { continue }
        if ($Entrada.Name -eq 'data' -and $Entrada.PSIsContainer) {
            $Carpeta = Join-Path $Destino 'data'
            New-Item -ItemType Directory -Path $Carpeta -Force | Out-Null
            $Regla = Join-Path $Entrada.FullName '.htaccess'
            if (Test-Path $Regla) {
                Copy-Item -LiteralPath $Regla -Destination $Carpeta -Force
            }
            continue
        }
        Copy-Item -LiteralPath $Entrada.FullName -Destination $Destino -Recurse -Force
    }

    Write-Host '[5/6] Probar ventas, compras, usuarios, pagos y stock en MySQL' -ForegroundColor Cyan
    $Prueba = Join-Path $Raiz 'PHP\tests\PRUEBA_INTEGRACION.php'
    $Salida = @(& $Php $Prueba 2>&1)
    if ($LASTEXITCODE -ne 0 -or ($Salida -join [Environment]::NewLine) -notmatch 'INTEGRACION_OK') {
        Write-Host ($Salida -join [Environment]::NewLine) -ForegroundColor Red
        throw 'Fallo la prueba transaccional MySQL. Revisa el error anterior.'
    }
    Write-Host 'Prueba MySQL OK: los cambios temporales fueron revertidos.' -ForegroundColor Green

    Write-Host '[6/6] Verificar acceso HTTP por Apache' -ForegroundColor Cyan
    $Api = Invoke-RestMethod 'http://localhost/dorada_api/conexion_estado.php' -Method Get -TimeoutSec 20
    if ($Api.estado -ne $true -or $Api.tablas_verificadas -lt 18) {
        throw 'No se verificaron las 18 tablas y las columnas desde Apache.'
    }
    $Login = Invoke-WebRequest 'http://localhost/dorada_api/admin_login.php' -UseBasicParsing -TimeoutSec 20
    if ($Login.StatusCode -ne 200) { throw 'El login administrativo no responde.' }
    Write-Host 'PHP + MySQL FUNCIONANDO en esta computadora.' -ForegroundColor Green
    Write-Host 'Panel: http://localhost/dorada_api/admin_login.php'
    Write-Host 'Diagnostico (requiere acceso admin): http://localhost/dorada_api/verificar_bd.php'
    Write-Host ('Respaldos fuera de htdocs: ' + $Respaldos)
} finally {
    $env:MYSQL_PWD = $ClaveMysqlAnterior
    Set-Location $Anterior
}
