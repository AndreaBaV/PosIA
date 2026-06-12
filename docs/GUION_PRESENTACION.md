# Guion de presentacion comercial — POSIA

**Duracion sugerida:** 15–20 minutos  
**Audiencia:** Dueno de tienda / tomador de decision  
**PIN demo:** `1234`

---

## Antes de la presentacion (checklist)

- [ ] Windows: ejecutar desde carpeta `Release` completa
- [ ] iPhone: instalar en dispositivo fisico; aceptar permiso de microfono
- [ ] Verificar banner verde **"Listo para presentacion"** al abrir
- [ ] Turno de caja ya abierto con fondo $500 (automatico en demo)
- [ ] Ocultar banner con X si estorba
- [ ] No abrir Sync a menos que el hub en Render este activo

---

## Acto 1 — Problema y propuesta (2 min)

> "Las tiendas pierden ventas cuando el sistema falla sin internet, cuando el cajero tarda en registrar productos, o cuando no hay control de caja al cierre del dia."

> "POSIA es un punto de venta que funciona **offline**, sincroniza en la nube cuando hay conexion, y en movil permite **vender hablando**."

---

## Acto 2 — Caja escritorio Windows (5 min)

1. Mostrar pantalla de caja con grilla de productos y categorias.
2. Destacar banner: turno abierto, listo para vender.
3. **Venta rapida:**
   - Tocar **Arroz 1kg** + **Coca-Cola** (elegir variante 600ml)
   - Mostrar carrito lateral con totales
4. **Escaneo:** boton Escanear → codigo `7501000100011` (arroz)
5. **Carniceria:** Filete de res → ingresar 0.5 kg
6. **Farmacia:** Paracetamol → seleccionar lote (mostrar alerta caducidad en Admin despues)
7. **COBRAR** → confirmacion → ticket en `Documents/POSIA/tickets`
8. Mencionar: solo efectivo hoy; multipago fuera de alcance por diseno

---

## Acto 3 — Caja movil por voz iPhone (5 min) — ESTRELLA

1. Cambiar al iPhone (o Android).
2. Mostrar pantalla minimalista con boton **Hablar**.
3. Dictar claramente:

> "Genera el ticket: vendi un kilogramo de arroz, medio kilo de frijol peruano y 1 caja de leche"

4. Mostrar como el sistema:
   - Interpreta cantidades (1 kg, 0.5 kg)
   - Resuelve **1 caja de leche = 12 litros** (no 1 pieza)
5. Tocar **COBRAR** → confirmar monto
6. Plan B si falla microfono: pegar el mismo texto en **Comando manual** → Procesar

**Frase de cierre voz:**

> "El cajero no busca en menus: describe la venta como habla con el cliente."

---

## Acto 4 — Control del negocio Admin (5 min)

1. Pestaña **Admin** → PIN `1234`
2. **Ventas hoy:** mostrar 2 ventas demo del dia ($86.50 acumulado en turno)
3. **Historial:** reimprimir ticket; mencionar anulacion y devolucion parcial
4. **Corte de caja:** turno abierto, efectivo esperado; no cerrar si seguira la demo
5. **Reportes:** exportar CSV al portapapeles
6. **Farmacia:** alerta lote proximo a caducar (LOT-2025-B)
7. **Configuracion:** tenant, tienda, impresora red/archivo

---

## Acto 5 — Nube y cierre comercial (3 min)

> "Varias cajas sincronizan contra Neon PostgreSQL y API en Render — plan gratuito para empezar."

Mostrar Admin → Sincronizar (solo si hub activo).

**Cierre:**

| Beneficio | POSIA |
|-----------|-------|
| Opera sin internet | SQLite local |
| Multi-caja | Sync Neon + Render |
| Rapidez en piso | Voz en movil |
| Control | Corte de caja, historial, inventario |
| Costo inicial | Infra gratuita + Windows/iPhone existentes |

**Preguntas frecuentes:**

- *¿Tarjeta?* — Solo efectivo en esta version; tarjeta en roadmap si el cliente lo requiere.
- *¿Que necesito?* — PC Windows o iPhone, impresora termica opcional (red o archivo).
- *¿Cuanto tarda implantacion?* — 1 dia configuracion catalogo + tenant + capacitacion.

---

## Numeros demo de referencia

| Dato | Valor |
|------|-------|
| Tienda | Tienda Centro |
| Turno fondo | $500 |
| Ventas previas demo | 2 tickets ($86.50) |
| PIN admin | 1234 |
| Productos clave voz | Arroz, Frijol peruano, Leche 1L (caja=12) |

---

## Plan B (contingencia)

| Falla | Accion |
|-------|--------|
| Microfono iPhone | Comando manual por texto |
| COBRAR deshabilitado | Admin → Corte de caja → Abrir turno |
| App no abre Windows | Carpeta Release completa |
| Sync error | Omitir acto 5; enfatizar offline |
