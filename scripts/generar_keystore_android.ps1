# Genera keystore de release para Google Play (ejecutar una sola vez).
# Los archivos generados NO se suben al repositorio.

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $Raiz "apps\posia_pos\android"
$Keystore = Join-Path $AndroidDir "posia-release.keystore"
$KeyProps = Join-Path $AndroidDir "key.properties"

if (Test-Path $Keystore) {
    Write-Host "Ya existe ${Keystore} - no se sobrescribe." -ForegroundColor Yellow
    exit 0
}

$StorePass = Read-Host "Contrasena del keystore (min. 6 caracteres)"
$KeyPass = Read-Host "Contrasena de la clave (Enter = misma que keystore)"
if ([string]::IsNullOrWhiteSpace($KeyPass)) {
    $KeyPass = $StorePass
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    $javaHome = $env:JAVA_HOME
    if ($javaHome) {
        $keytool = Join-Path $javaHome "bin\keytool.exe"
    }
}
if (-not (Test-Path $keytool)) {
    Write-Error "No se encontro keytool. Instala JDK 17 o define JAVA_HOME."
}

& $keytool -genkeypair `
    -v `
    -storetype PKCS12 `
    -keystore $Keystore `
    -alias posia `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass $StorePass `
    -keypass $KeyPass `
    -dname "CN=POSIA, OU=Mobile, O=POSIA, L=Ciudad, ST=Estado, C=MX"

$props = @(
    "storePassword=$StorePass"
    "keyPassword=$KeyPass"
    "keyAlias=posia"
    "storeFile=../posia-release.keystore"
)
$props | Set-Content -Path $KeyProps -Encoding ASCII

Write-Host "Keystore: ${Keystore}" -ForegroundColor Green
Write-Host "Config:   ${KeyProps}" -ForegroundColor Green
Write-Host "Guarda las contrasenas en un lugar seguro." -ForegroundColor Cyan
