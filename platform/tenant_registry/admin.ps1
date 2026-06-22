# Arranca el panel web de tenants (desde platform/tenant_registry).
$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

function Clear-DartNativeDllCache {
    $libDir = Join-Path $ScriptDir ".dart_tool\lib"
    foreach ($dll in @("sqlite3.dll", "dartjni.dll")) {
        $ruta = Join-Path $libDir $dll
        if (Test-Path $ruta) {
            Remove-Item -Force $ruta -ErrorAction SilentlyContinue
        }
    }
}

Get-NetTCPConnection -LocalPort 3847 -ErrorAction SilentlyContinue |
    ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }

Clear-DartNativeDllCache
Set-Location $ScriptDir
dart run bin/posia_admin_web.dart
