# Hardware POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Principio

El nucleo POS **nunca** accede a hardware directamente. Todo pasa por contratos en `posia_hardware` e implementaciones en drivers opcionales.

---

## 2. Contratos

| Interfaz | Proposito |
|----------|-----------|
| `BarcodeScanner` | Stream de codigos escaneados |
| `Scale` | Peso estable en gramos |
| `ReceiptPrinter` | Impresion ticket ESC/POS o PDF |
| `CashDrawer` | Pulso apertura cajon |
| `CustomerDisplay` | Total al cliente |

---

## 3. Registro de drivers

`HardwareRegistry` carga drivers segun configuracion YAML/JSON por tienda:

```yaml
hardware:
  scanner:
    driver: keyboard_wedge
  printer:
    driver: escpos_network
    host: 192.168.1.50
    port: 9100
  scale:
    driver: serial_generic
    port: COM3
    protocol: toledo
```

---

## 4. Drivers incluidos (MVP)

| Driver | Tipo | Notas |
|--------|------|-------|
| `MockBarcodeScanner` | Scanner | Desarrollo y pruebas |
| `TecladoBarcodeScanner` | Scanner | **Activo en produccion** — USB wedge |
| `MockReceiptPrinter` | Printer | Desarrollo; impresion simulada |
| `escpos_network` | Printer | Planificado |
| `pdf_fallback` | Printer | Planificado |

### TecladoBarcodeScanner

Implementacion en `packages/posia_hardware/lib/src/teclado_barcode_scanner.dart`.

- Escucha `HardwareKeyboard` global
- Acumula caracteres rapidos; emite codigo al detectar Enter
- Reinicia buffer si pasan >400 ms entre teclas
- Registrado en `hardwareRegistryProvider` de `posia_pos`

Drivers adicionales en paquetes separados futuros.

---

## 5. Fallbacks

| Hardware ausente | Comportamiento |
|------------------|----------------|
| Impresora | PDF + dialogo compartir |
| Bascula | Entrada manual peso (iconos) |
| Scanner | Busqueda visual / voz |

---

## 6. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Documento inicial |
