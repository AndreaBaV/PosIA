# Atajos para el CLI de tenants POSIA.
param(
    [Parameter(Position = 0)]
    [string]$Comando = "list",
    [string]$Tenant = "",
    [string]$Nombre = "",
    [string]$Codigo = "",
    [string]$Pin = "",
    [switch]$Provision
)

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $PSScriptRoot
$Registry = Join-Path $Raiz "tenant_registry"

function Clear-DartNativeDllCache {
    # Dart en Windows falla si sqlite3.dll ya existe en .dart_tool/lib (errno 183).
    $libDir = Join-Path $Registry ".dart_tool\lib"
    foreach ($dll in @("sqlite3.dll", "dartjni.dll")) {
        $ruta = Join-Path $libDir $dll
        if (Test-Path $ruta) {
            Remove-Item -Force $ruta -ErrorAction SilentlyContinue
        }
    }
}

function Stop-PosiaAdminWeb {
    Get-NetTCPConnection -LocalPort 3847 -ErrorAction SilentlyContinue |
        ForEach-Object {
            Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        }
}

Set-Location $Registry

switch ($Comando.ToLower()) {
    "init" {
        dart run bin/posia_tenants.dart init
    }
    "list" {
        dart run bin/posia_tenants.dart list
    }
    "crear" {
        if (-not $Nombre) { throw "Usa -Nombre 'Mi negocio'" }
        dart run bin/posia_tenants.dart crear --nombre $Nombre
    }
    "add-tienda" {
        if (-not $Tenant -or -not $Nombre) { throw "Usa -Tenant y -Nombre" }
        dart run bin/posia_tenants.dart add-tienda --tenant $Tenant --nombre $Nombre
    }
    "add-usuario" {
        if (-not $Tenant -or -not $Nombre -or -not $Codigo -or -not $Pin) {
            throw "Usa -Tenant -Nombre -Codigo -Pin"
        }
        dart run bin/posia_tenants.dart add-usuario --tenant $Tenant --nombre $Nombre --codigo $Codigo --pin $Pin
    }
    "provision" {
        if (-not $Tenant) { throw "Usa -Tenant <uuid>" }
        dart run bin/posia_tenants.dart provision --tenant $Tenant
    }
    "seed-review" {
        if ($Provision) {
            dart run bin/posia_tenants.dart seed-review --provision
        } else {
            dart run bin/posia_tenants.dart seed-review
        }
    }
    "show" {
        if (-not $Tenant) { throw "Usa -Tenant <uuid>" }
        dart run bin/posia_tenants.dart show --id $Tenant
    }
    "admin" {
        Stop-PosiaAdminWeb
        Clear-DartNativeDllCache
        dart run bin/posia_admin_web.dart
    }
    default {
        Write-Host @"
Comandos: init, list, crear, add-tienda, add-usuario, provision, seed-review, show, admin

Ejemplos:
  .\platform\scripts\tenants.ps1 crear -Nombre "Farmacia Sur"
  .\platform\scripts\tenants.ps1 provision -Tenant <uuid>
  .\platform\scripts\tenants.ps1 seed-review -Provision
  .\platform\scripts\tenants.ps1 admin
"@
    }
}
