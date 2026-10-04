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

# 2. Exportar la base de datos real
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

# 3. Sincronizar backend con XAMPP
if (!(Test-Path $Htdocs)) {
    New-Item -ItemType Directory -Path $Htdocs | Out-Null
}

Copy-Item (Join-Path $Backend "*") $Htdocs -Recurse -Force

# 4. Crear ZIP limpio del proyecto web + API
$TempBackend = Join-Path $env:TEMP "Dorada_Motors_WEB_API_ENTREGA"

if (Test-Path $TempBackend) {
    Remove-Item $TempBackend -Recurse -Force
}

New-Item -ItemType Directory -Path $TempBackend | Out-Null

Get-ChildItem $Backend -Force |
    Where-Object {
        $_.Name -notin @(
            "LEEME_PROFESOR.txt",
            ".git",
            ".github",
            ".vscode"
        )
    } |
    ForEach-Object {
        Copy-Item $_.FullName $TempBackend -Recurse -Force
    }

$WebZip = Join-Path $Entrega "Dorada_Motors_WEB_API.zip"
Compress-Archive -Path (Join-Path $TempBackend "*") -DestinationPath $WebZip -Force

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
