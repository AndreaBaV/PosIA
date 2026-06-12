# Guia de interfaz POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Modo caja (trabajadores)

### Principios

- Iconos grandes (minimo 64x64 dp tactiles)
- Numeros de total en tipografia extra grande
- Maximo 4 acciones en barra inferior fija
- Feedback sonoro en escaneo y cobro exitoso
- Minimo texto; etiquetas opcionales bajo iconos

### Layout

```
┌─────────────────────────────────────────────┐
│  [Tienda]              Total: $1,234.56     │
├──────────────────────────┬──────────────────┤
│                          │                  │
│   Grid productos         │    Carrito       │
│   (fotos grandes)          │    (iconos)      │
│                          │                  │
├──────────────────────────┴──────────────────┤
│ [Cliente] [Cantidad] [Cancelar] [COBRAR]    │
└─────────────────────────────────────────────┘
```

### Colores semanticos

| Accion | Color |
|--------|-------|
| Cobrar | Verde `#2E7D32` |
| Cancelar | Rojo `#C62828` |
| Neutral | Gris `#424242` |

---

## 2. Modo administrador

- Maximo 5 items en menu principal
- Asistentes paso a paso con iconos
- Reportes: un grafico + exportar
- Sin terminos tecnicos ("Sincronizar" → icono nube)

---

## 3. Accesibilidad

- Contraste WCAG AA minimo
- Areas tactiles minimo 48x48 dp
- Soporte voz (modulo futuro `voice_commands`)

---

## 4. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Documento inicial |
