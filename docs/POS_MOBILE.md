# POS movil — Caja por voz (iOS / Android)

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Ultima actualizacion:** 2026-06-11

---

## Vision

En iPhone y Android, POSIA usa una **caja minimalista** centrada en **comandos de voz**. El cajero habla la venta; el motor interpreta productos, cantidades y unidades (kg, caja, pieza) y arma el ticket.

Escritorio (Windows) conserva la grilla completa de productos.

---

## Pantalla de caja movil

| Elemento | Funcion |
|----------|---------|
| Boton **Hablar** | Captura voz (STT espanol Mexico) |
| Campo manual | Mismo comando por texto si no hay microfono |
| Carrito | Lineas agregadas con cantidad resuelta |
| **COBRAR** | Venta en efectivo + ticket a archivo |

---

## Comandos de voz

### Agregar productos

```
Genera el ticket: vendi un kilogramo de arroz, medio kilo de frijol peruano y 1 caja de leche
```

### Cobrar

```
Cobrar
Cobra en efectivo
Cierra la venta
```

### Vaciar

```
Vacia el carrito
```

---

## Resolucion de cajas

El catalogo usa `piezas_por_caja` en cada producto:

| Producto | Unidad venta | piezas_por_caja | "1 caja de..." |
|----------|--------------|-----------------|----------------|
| Leche 1L | litro | 12 | 12 litros |
| Atun lata | pieza | 24 | 24 latas |
| Huevo carton 12 | caja | — | 1 carton |

Configura `piezas_por_caja` en Admin → Productos (campo en base de datos v4).

---

## Probar en iPhone

1. Abre `apps/posia_pos/ios/Runner.xcworkspace` en Xcode.
2. Selecciona tu equipo de desarrollo y un iPhone fisico.
3. Desde terminal:

```bash
cd apps/posia_pos
flutter pub get
flutter run -d <id-iphone>
```

4. Admin → **Corte de caja** → abrir turno (obligatorio).
5. Caja → **Hablar** → dicta el ticket de ejemplo.

Tickets se guardan en documentos de la app: `POSIA/tickets`.

---

## Paquete `posia_voice`

- `InterpretadorComandosVoz` — analiza espanol hablado
- `ResolvedorCantidadVoz` — convierte cajas a piezas segun catalogo
- `MotorComandosVoz` — une interpretacion + busqueda en catalogo

Tests: `packages/posia_voice/test/interpretador_comandos_voz_test.dart`

---

## Limites (minimalista)

- Solo efectivo (sin multipago)
- Admin completo disponible pero pensado para tablet; en telefono prioriza voz + corte + sync
- Requiere productos en catalogo local (demo o sync con hub)
