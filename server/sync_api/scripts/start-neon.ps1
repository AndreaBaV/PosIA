# Arranca el hub POSIA con Neon (lee server/sync_api/.env)
Set-Location $PSScriptRoot\..
dart run bin/probar_neon.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$puerto = 8080
$envFile = Join-Path $PWD ".env"
if (Test-Path $envFile) {
	$linea = Get-Content $envFile | Where-Object { $_ -match '^\s*PORT\s*=' } | Select-Object -First 1
	if ($linea -match '=\s*(\d+)') { $puerto = [int]$Matches[1] }
}
$ocupado = Get-NetTCPConnection -LocalPort $puerto -State Listen -ErrorAction SilentlyContinue
if ($ocupado) {
	Write-Host "Puerto $puerto ya en uso (PID $($ocupado.OwningProcess)). El hub probablemente ya esta corriendo."
	Write-Host "URL: http://localhost:$puerto/v1/health (requiere cabecera x-api-key)"
	exit 0
}

Write-Host "Iniciando API en http://localhost:$puerto ..."
dart run bin/server.dart
