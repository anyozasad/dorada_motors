# DORADA MOTORS - ORGANIZAR CARPETA LOCAL SIN PERDER ARCHIVOS
# Ejecutar desde la raiz: powershell -ExecutionPolicy Bypass -File .\PHP\ORDENAR_CARPETA_LOCAL.ps1
# Mueve sobrantes de versiones antiguas a un respaldo en Documentos.
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
$proyecto = Split-Path -Parent $PSScriptRoot

if ((Split-Path -Leaf $proyecto) -ne 'dorada_motors') {
    throw "La carpeta raiz debe llamarse dorada_motors: $proyecto"
}
if (!(Test-Path -LiteralPath (Join-Path $proyecto 'Flutter\pubspec.yaml')) -or
    !(Test-Path -LiteralPath (Join-Path $proyecto 'PHP\dorada_api\dashboard.php'))) {
    throw 'Faltan Flutter o PHP completos. No se movio ningun archivo.'
}

# Solo estos elementos antiguos de la raiz. NO tocar Flutter/, PHP/, .git, .github o README.md.
$directoriosAntiguos = @('.dart_tool', '.idea', 'android', 'ios', 'windows', 'build')
$archivosAntiguos = @('.flutter-plugins-dependencies', 'dorada_motors.iml')

$candidatos = @(
    Get-ChildItem -LiteralPath $proyecto -Force | Where-Object {
        ($_.PSIsContainer -and (
            $directoriosAntiguos -contains $_.Name -or
            $_.Name -like 'dorada_nuevo_*'
        )) -or
        (!$_.PSIsContainer -and $archivosAntiguos -contains $_.Name)
    }
)
if ($candidatos.Count -eq 0) {
    Write-Host 'Ya esta ordenado: no hay carpetas antiguas para mover.' -ForegroundColor Green
    exit 0
}

$documentos = [Environment]::GetFolderPath('MyDocuments')
if ([string]::IsNullOrWhiteSpace($documentos)) {
    throw 'No se pudo encontrar Documentos para guardar el respaldo.'
}
$respaldo = Join-Path $documentos (
    'RESPALDO_DORADA_MOTORS_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' +
    [guid]::NewGuid().ToString('N').Substring(0, 6)
)
if ($PSCmdlet.ShouldProcess($proyecto, "Mover $($candidatos.Count) elementos antiguos a $respaldo")) {
    New-Item -ItemType Directory -Path $respaldo -Force | Out-Null
    foreach ($elemento in $candidatos) {
        Move-Item -LiteralPath $elemento.FullName -Destination (Join-Path $respaldo $elemento.Name) -ErrorAction Stop
        Write-Host ("Respaldado: " + $elemento.Name) -ForegroundColor Yellow
    }
    Write-Host 'CARPETA ORDENADA: Flutter y PHP siguen intactos.' -ForegroundColor Green
    Write-Host "Respaldo en: $respaldo" -ForegroundColor Cyan
    Write-Host 'Nota: .github, .gitignore y README.md son archivos tecnicos necesarios.' -ForegroundColor Gray
}
