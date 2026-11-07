# DORADA MOTORS - PREPARAR ENTREGA DEL EXAMEN INDICADOR II
# Genera una carpeta PROYECTO y un PROYECTO.zip en el Escritorio.

$ErrorActionPreference = "Stop"

$Proyecto = "C:\Users\CESAR\Desktop\dorada_motors"
$Backend = Join-Path $Proyecto "dorada_api"
$Desktop = [Environment]::GetFolderPath("Desktop")
$Entrega = Join-Path $Desktop "PROYECTO"
$ZipFinal = Join-Path $Desktop "PROYECTO.zip"
$Dump = "C:\xampp\mysql\bin\mysqldump.exe"
$Htdocs = "C:\xampp\htdocs\dorada_api"

Write-Host ""
Write-Host "=== DORADA MOTORS - PREPARANDO ENTREGA ===" -ForegroundColor Cyan

if (!(Test-Path $Proyecto)) {
    throw "No se encontro el proyecto en: $Proyecto"
}

if (!(Test-Path $Backend)) {
    throw "No se encontro la carpeta dorada_api en: $Backend"
}

if (!(Test-Path $Dump)) {
    throw "No se encontro mysqldump.exe. Verifica XAMPP."
}

# 1. Limpiar entrega anterior
if (Test-Path $Entrega) {
    Remove-Item $Entrega -Recurse -Force
}

if (Test-Path $ZipFinal) {
    Remove-Item $ZipFinal -Force
}

New-Item -ItemType Directory -Path $Entrega | Out-Null

# 2. Recuperar configuracion empresarial guardada desde XAMPP
Write-Host "Sincronizando configuracion empresarial..." -ForegroundColor Yellow
$ConfigHtdocs = Join-Path $Htdocs "data\config_empresa.json"
$ConfigProyecto = Join-Path $Backend "data\config_empresa.json"
if (Test-Path $ConfigHtdocs) {
    $ConfigDirProyecto = Split-Path $ConfigProyecto -Parent
    if (!(Test-Path $ConfigDirProyecto)) {
        New-Item -ItemType Directory -Path $ConfigDirProyecto -Force | Out-Null
    }
    Copy-Item $ConfigHtdocs $ConfigProyecto -Force
}

# 3. Aplicar compatibilidad/estructura actual antes de exportar
Write-Host "Aplicando estructura actual de la base de datos..." -ForegroundColor Yellow
$PhpExe = "C:\xampp\php\php.exe"
if (!(Test-Path $PhpExe)) {
    throw "No se encontro PHP de XAMPP en $PhpExe"
}
& $PhpExe (Join-Path $Backend "sistema_bootstrap.php")
if ($LASTEXITCODE -ne 0) {
    throw "No se pudo actualizar la estructura de la base de datos."
}

# 3. Exportar la base de datos real
$SqlBackend = Join-Path $Backend "dorada_motors.sql"
$SqlEntrega = Join-Path $Entrega "Dorada_Motors_BD.sql"

Write-Host "Exportando base de datos dorada_motors..." -ForegroundColor Yellow

& $Dump -u root --default-character-set=utf8mb4 --routines --events --triggers dorada_motors |
    Set-Content -Path $SqlBackend -Encoding UTF8

if (!(Test-Path $SqlBackend)) {
    throw "No se pudo crear dorada_motors.sql."
}

if ((Get-Item $SqlBackend).Length -lt 100) {
    throw "El archivo SQL esta vacio o incompleto. Verifica que MySQL este encendido."
}

Copy-Item $SqlBackend $SqlEntrega -Force

$Control150 = Join-Path $Proyecto "CONTROL_150_FUNCIONES.txt"
if (Test-Path $Control150) {
    Copy-Item $Control150 (Join-Path $Entrega "REQUERIMIENTOS_FUNCIONALES_150.txt") -Force
}

# 3. Sincronizar backend con XAMPP
if (!(Test-Path $Htdocs)) {
    New-Item -ItemType Directory -Path $Htdocs | Out-Null
}

Copy-Item (Join-Path $Backend "*") $Htdocs -Recurse -Force

# 4. Crear ZIP limpio del proyecto web + API
# El ZIP incluye una carpeta raiz "dorada_api" para que el profesor
# solo la extraiga directamente dentro de C:\xampp\htdocs\
$TempBackend = Join-Path $env:TEMP "Dorada_Motors_WEB_API_ENTREGA"
$TempBackendApp = Join-Path $TempBackend "dorada_api"

if (Test-Path $TempBackend) {
    Remove-Item $TempBackend -Recurse -Force
}

New-Item -ItemType Directory -Path $TempBackendApp -Force | Out-Null

Get-ChildItem $Backend -Force |
    Where-Object {
        $_.Name -notin @(
            "LEEME_PROFESOR.txt",
            "carrito.php",
            "favoritos.php",
            ".git",
            ".github",
            ".vscode"
        )
    } |
    ForEach-Object {
        Copy-Item $_.FullName $TempBackendApp -Recurse -Force
    }

$AuditoriaTemp = Join-Path $TempBackendApp "data\auditoria.jsonl"
if (Test-Path $AuditoriaTemp) {
    Remove-Item $AuditoriaTemp -Force
}

$WebZip = Join-Path $Entrega "Dorada_Motors_WEB_API.zip"
Compress-Archive -Path $TempBackendApp -DestinationPath $WebZip -Force

# 5. Crear ZIP limpio de Flutter
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

# Quitar archivos auxiliares que no necesita el profesor
$ArchivosQuitarFlutter = @(
    "dorada_motors.iml",
    "PREPARAR_ENTREGA_INDICADOR_II.ps1",
    "VERIFICAR_SISTEMA.ps1",
    "PRUEBA_INTEGRACION.php",
    "CONTROL_150_FUNCIONES.txt",
    "VALIDAR_DASHBOARD_150.php",
    "ENTREGA_INDICADOR_II.txt"
)

foreach ($archivo in $ArchivosQuitarFlutter) {
    $ruta = Join-Path $TempFlutter $archivo
    if (Test-Path $ruta) {
        Remove-Item $ruta -Force
    }
}

$FlutterZip = Join-Path $Entrega "Dorada_Motors_FLUTTER.zip"
Compress-Archive -Path (Join-Path $TempFlutter "*") -DestinationPath $FlutterZip -Force

# 6. Validar que los tres archivos de entrega existan
$ArchivosEntrega = @(
    $SqlEntrega,
    $WebZip,
    $FlutterZip
)

foreach ($archivo in $ArchivosEntrega) {
    if (!(Test-Path $archivo)) {
        throw "Falta un archivo de entrega: $archivo"
    }
}

# 7. Crear ZIP final
Compress-Archive -Path $Entrega -DestinationPath $ZipFinal -Force

# 8. Mostrar resultado
Write-Host ""
Write-Host "=== ENTREGA LISTA ===" -ForegroundColor Green
Write-Host "Carpeta: $Entrega" -ForegroundColor Green
Write-Host "ZIP final: $ZipFinal" -ForegroundColor Green
Write-Host ""
Write-Host "Contenido de PROYECTO:" -ForegroundColor Cyan

Get-ChildItem $Entrega |
    Select-Object Name, Length |
    Format-Table -AutoSize

Write-Host ""
Write-Host "El archivo que debes subir al examen es: PROYECTO.zip" -ForegroundColor Yellow

Start-Process $Entrega
