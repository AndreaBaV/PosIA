# Compila artefactos moviles POSIA para tiendas.
param(
    [ValidateSet("android", "apk", "ios", "all")]
    [string]$Plataforma = "android",
    [switch]$SinIconos,
    [string]$HubUrl = $env:POSIA_HUB_URL,
    [string]$HubApiKey = $env:POSIA_HUB_API_KEY
)

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $Raiz "apps\posia_pos"

Set-Location $AppDir

$Defines = @()
if ($HubUrl) { $Defines += "--dart-define=POSIA_HUB_URL=$HubUrl" }
if ($HubApiKey) { $Defines += "--dart-define=POSIA_HUB_API_KEY=$HubApiKey" }
$DefineArgs = $Defines -join " "

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

if (-not $SinIconos) {
    Write-Host "==> Iconos y splash" -ForegroundColor Cyan
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
}

function Build-AndroidBundle {
    $keyProps = Join-Path $AppDir "android\key.properties"
    if (-not (Test-Path $keyProps)) {
        Write-Host "AVISO: Sin android/key.properties - el AAB usara firma debug." -ForegroundColor Yellow
        Write-Host "       Ejecuta scripts\generar_keystore_android.ps1 antes de publicar." -ForegroundColor Yellow
    }
    Write-Host "==> flutter build appbundle --release $DefineArgs" -ForegroundColor Cyan
    if ($DefineArgs) {
        Invoke-Expression "flutter build appbundle --release $DefineArgs"
    } else {
        flutter build appbundle --release
    }
    $aab = Join-Path $AppDir "build\app\outputs\bundle\release\app-release.aab"
    if (Test-Path $aab) {
        Write-Host "AAB listo: $aab" -ForegroundColor Green
    }
}

function Build-AndroidApk {
    Write-Host "==> flutter build apk --release $DefineArgs" -ForegroundColor Cyan
    if ($DefineArgs) {
        Invoke-Expression "flutter build apk --release $DefineArgs"
    } else {
        flutter build apk --release
    }
    $apk = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apk) {
        Write-Host "APK listo: $apk" -ForegroundColor Green
    }
}

function Build-Ios {
    if ($env:OS -notmatch "Darwin") {
        Write-Error "iOS requiere macOS con Xcode. Ver docs/PUBLICACION_MOVIL.md seccion 4."
    }
    Write-Host "==> flutter build ipa --release $DefineArgs" -ForegroundColor Cyan
    if ($DefineArgs) {
        Invoke-Expression "flutter build ipa --release $DefineArgs"
    } else {
        flutter build ipa --release
    }
}

switch ($Plataforma) {
    "android" { Build-AndroidBundle }
    "apk"     { Build-AndroidApk }
    "ios"     { Build-Ios }
    "all"     {
        Build-AndroidBundle
        Build-AndroidApk
        Build-Ios
    }
}

Write-Host "`nVer docs/PUBLICACION_MOVIL.md para subir a Play Store y App Store." -ForegroundColor Cyan
