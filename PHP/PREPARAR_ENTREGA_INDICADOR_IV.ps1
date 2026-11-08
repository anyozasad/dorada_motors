# Indicador IV - UNICO empaquetador. Crea solo Flutter/ y PHP/ en el ZIP.
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Flutter = Join-Path $Repo 'Flutter'
$Php = Join-Path $Repo 'PHP'
if (!(Test-Path (Join-Path $Flutter 'pubspec.yaml')) -or
    !(Test-Path (Join-Path $Php 'dorada_api\dashboard.php'))) {
  throw 'Falta Flutter/pubspec.yaml o PHP/dorada_api/dashboard.php.'
}
$Desktop = [Environment]::GetFolderPath('Desktop')
$Temporal = Join-Path $env:TEMP ('DORADA_MOTORS_INDICADOR_IV_' + [guid]::NewGuid().ToString('N'))
$Zip = Join-Path $Desktop 'INDICADOR_IV_DORADA_MOTORS.zip'
if (Test-Path $Zip) { Remove-Item $Zip -Force }
New-Item -Path $Temporal -ItemType Directory -Force | Out-Null
function CopiarFuentes([string]$origen,[string]$destino) {
  New-Item -ItemType Directory -Path $destino -Force | Out-Null
  $excluir = @(
    (Join-Path $origen '.dart_tool'),
    (Join-Path $origen 'build'),
    (Join-Path $origen '.idea'),
    (Join-Path $origen '.vscode'),
    (Join-Path $origen 'dorada_api\data'),
    (Join-Path $origen 'dorada_api\uploads\privado')
  )
  $argumentos = @($origen,$destino,'/E','/NFL','/NDL','/NJH','/NJS','/NP','/XD') + $excluir + @('/XF','*.zip','*.iml','*.log','.env')
  & robocopy @argumentos | Out-Null
  if ($LASTEXITCODE -gt 7) { throw "Fallo la copia de archivos: $origen" }
}
CopiarFuentes $Flutter (Join-Path $Temporal 'Flutter')
CopiarFuentes $Php (Join-Path $Temporal 'PHP')
# Preservar la regla de acceso restringido, no copiar respaldos o auditoria.
$Data = Join-Path $Temporal 'PHP\dorada_api\data'
New-Item -Path $Data -ItemType Directory -Force | Out-Null
$Htaccess = Join-Path $Php 'dorada_api\data\.htaccess'
if (!(Test-Path -LiteralPath $Htaccess)) { throw 'Falta la regla de seguridad PHP/dorada_api/data/.htaccess' }
Copy-Item -LiteralPath $Htaccess -Destination (Join-Path $Data '.htaccess') -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($Temporal, $Zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
# Comprobar y agregar explicitamente los archivos ocultos que Windows pudiera omitir.
$ArchivoZip = [System.IO.Compression.ZipFile]::Open($Zip, [System.IO.Compression.ZipArchiveMode]::Update)
try {
  foreach ($recurso in @(
    @{ Origen=$Htaccess; Entrada='PHP/dorada_api/data/.htaccess' },
    @{ Origen=(Join-Path $Php 'dorada_api\.htaccess'); Entrada='PHP/dorada_api/.htaccess' },
    @{ Origen=(Join-Path $Flutter '.metadata'); Entrada='Flutter/.metadata' }
  )) {
    if (!(Test-Path -LiteralPath $recurso.Origen)) { throw "No existe archivo requerido: $($recurso.Origen)" }
    if (!$ArchivoZip.GetEntry($recurso.Entrada)) {
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $ArchivoZip, $recurso.Origen, $recurso.Entrada
      ) | Out-Null
    }
  }
} finally {
  $ArchivoZip.Dispose()
}
if (!(Test-Path $Zip) -or (Get-Item $Zip).Length -lt 100000) { throw 'ZIP incompleto o ausente.' }
# Revisar que la entrega conserve únicamente los dos módulos funcionales y ninguna carpeta extra.
$Comprobacion = [System.IO.Compression.ZipFile]::OpenRead($Zip)
try {
  $Raices = @($Comprobacion.Entries | ForEach-Object { ($_.FullName -replace '\\','/').Split('/')[0] } |
    Where-Object { $_ } | Sort-Object -Unique)
  if (($Raices -join ',') -ne 'Flutter,PHP') {
    throw ('El ZIP debe contener únicamente Flutter y PHP: ' + ($Raices -join ', '))
  }
  foreach ($ruta in @('Flutter/pubspec.yaml','PHP/dorada_api/dashboard.php','PHP/dorada_api/.htaccess',
    'PHP/dorada_api/data/.htaccess','PHP/INICIAR_DEMO.ps1','PHP/VERIFICAR_SISTEMA.ps1')) {
    if (!$Comprobacion.GetEntry($ruta)) { throw "Falta en el ZIP: $ruta" }
  }
} finally {
  $Comprobacion.Dispose()
}
Remove-Item $Temporal -Recurse -Force
Write-Host 'ENTREGA DEL INDICADOR IV PREPARADA: solo Flutter y PHP.' -ForegroundColor Green
Write-Host "Archivo para subir: $Zip" -ForegroundColor Cyan
exit 0
