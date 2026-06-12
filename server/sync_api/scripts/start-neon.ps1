# Arranca el hub POSIA con Neon (lee server/sync_api/.env)
Set-Location $PSScriptRoot\..
dart run bin/probar_neon.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Iniciando API en http://localhost:8080 ..."
dart run bin/server.dart
