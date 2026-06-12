# Modulo vertical carniceria POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 20:15:00 (UTC-6)

---

## Paquete

`packages/posia_module_butcher`

## Funcionalidades

- Venta por peso en kilogramos
- Validacion de peso minimo (100 g)
- Integracion con bascula via `posia_hardware.Scale`
- Mayoreo por escala de kg (ej. 5+ kg precio B)
- Dialogo de captura de peso en caja

## Productos demo

| ID | Nombre | Precio/kg |
|----|--------|-----------|
| prod-filete-res | Filete de res | $180 (mayoreo $165 desde 5 kg) |
| prod-chorizo | Chorizo casero | $95 |

## Licencia

Modulo `ModuloLicencia.butcher`
