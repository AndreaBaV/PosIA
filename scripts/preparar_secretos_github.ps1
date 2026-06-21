# Genera valores base64 para configurar secrets en GitHub (Settings > Secrets > Actions).
# Uso: .\scripts\preparar_secretos_github.ps1

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $PSScriptRoot
$Keystore = Join-Path $Raiz "apps\posia_pos\android\posia-release.keystore"

Write-Host "=== Secrets Android (Play Store) ===" -ForegroundColor Cyan
if (Test-Path $Keystore) {
    $bytes = [IO.File]::ReadAllBytes($Keystore)
    $b64 = [Convert]::ToBase64String($bytes)
    Write-Host "ANDROID_KEYSTORE_BASE64 (copiar a GitHub Secrets):" -ForegroundColor Yellow
    Write-Host $b64
    Write-Host ""
    Write-Host "Tambien configura:" -ForegroundColor Yellow
    Write-Host "  ANDROID_KEYSTORE_PASSWORD"
    Write-Host "  ANDROID_KEY_PASSWORD"
    Write-Host "  ANDROID_KEY_ALIAS  (ej. posia)"
} else {
    Write-Host "No existe $Keystore" -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts\generar_keystore_android.ps1"
}

Write-Host ""
Write-Host "=== Secrets iOS (App Store, sin Mac) ===" -ForegroundColor Cyan
Write-Host @"
En Mac o exportando desde Apple Developer:

  IOS_DIST_CERTIFICATE_BASE64  -> certificado .p12 en base64
  IOS_DIST_CERTIFICATE_PASSWORD -> contrasena del .p12
  IOS_PROVISION_PROFILE_BASE64 -> perfil App Store .mobileprovision en base64
  IOS_PROVISION_PROFILE_NAME   -> nombre exacto del perfil en Xcode
  APPLE_TEAM_ID                -> Team ID (10 caracteres)
  KEYCHAIN_PASSWORD            -> cualquier string (solo para CI)

PowerShell - codificar .p12:
  [Convert]::ToBase64String([IO.File]::ReadAllBytes('distribucion.p12'))

PowerShell - codificar .mobileprovision:
  [Convert]::ToBase64String([IO.File]::ReadAllBytes('POSIA_AppStore.mobileprovision'))
"@

Write-Host ""
Write-Host "=== Disparar release en GitHub ===" -ForegroundColor Cyan
Write-Host @"
1. Subir secrets en: https://github.com/AndreaBaV/PosIA/settings/secrets/actions
2. Actions > Mobile Release > Run workflow (platform: all)
   O crear tag: git tag mobile-v1.0.0 && git push origin mobile-v1.0.0
3. Descargar AAB/IPA en Artifacts o en Releases
"@
