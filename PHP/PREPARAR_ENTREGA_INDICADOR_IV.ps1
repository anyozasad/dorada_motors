# Entrega del Indicador IV - Dorada Motors
# Ejecutar dentro de la carpeta del proyecto. No incluye datos personales ni secretos.
param([switch]$PaquetesSeparados)
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$preparador = Join-Path $base 'PREPARAR_ENTREGA_INDICADOR_II.ps1'
if (!(Test-Path $preparador)) { throw 'Falta el empaquetador principal del proyecto.' }
$argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $preparador)
if ($PaquetesSeparados) { $argumentos += '-PaquetesSeparados' }
& powershell.exe @argumentos
if ($LASTEXITCODE -ne 0) { throw 'La preparación del proyecto falló. Revisa el mensaje anterior.' }
$escritorio = [Environment]::GetFolderPath('Desktop')
$origen = Join-Path $escritorio 'ENTREGA_DORADA_MOTORS.zip'
$destino = Join-Path $escritorio 'INDICADOR_IV_DORADA_MOTORS.zip'
if (!(Test-Path $origen) -or (Get-Item $origen).Length -lt 100000) {
  throw 'No se encontró la entrega completa. Revisa el empaquetado anterior.'
}
Move-Item -Path $origen -Destination $destino -Force
Write-Host ''
Write-Host 'ENTREGA INDICADOR IV PREPARADA' -ForegroundColor Green
Write-Host "Archivo para subir al instituto: $destino" -ForegroundColor Green
Write-Host 'Incluye Flutter, dashboard PHP, API, esquema MySQL e instrucciones.' -ForegroundColor Cyan
Write-Host 'La verificación funcional presencial debe hacerse con XAMPP y la matriz de requisitos.' -ForegroundColor Cyan
