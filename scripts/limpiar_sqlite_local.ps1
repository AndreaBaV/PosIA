# Reinicia SQLite local de La Fortuna (Windows).
# Cierra la app antes de ejecutar este script.

$ErrorActionPreference = 'Stop'

$documentos = [Environment]::GetFolderPath('MyDocuments')
$archivos = @(
    Join-Path $documentos 'posia_operativa.db'
    Join-Path $documentos 'posia_operativa.db-journal'
    Join-Path $documentos 'posia_operativa.db-wal'
    Join-Path $documentos 'posia_operativa.db-shm'
)

Write-Host "Documentos: $documentos"
Write-Host ""

foreach ($archivo in $archivos) {
    if (Test-Path $archivo) {
        Remove-Item -Force $archivo
        Write-Host "Eliminado: $archivo"
    }
}

Write-Host ""
Write-Host "Listo. La base operativa se recreara vacia al abrir la app."
Write-Host "La configuracion del hub y la caja se conserva en posia_dispositivo.db."
Write-Host "Si la app sigue colgada, cierra sesion o borra tambien posia_dispositivo.db"
Write-Host "(perderas URL del hub y deberas repetir la instalacion tecnica)."
