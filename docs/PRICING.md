# Motor de precios POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Objetivo

Resolver el precio unitario final en MXN para abarrotes, farmacia y carniceria con:

- Precio base por tienda
- Escalas de mayoreo por cantidad
- Precio fijo por cliente y producto
- Lista de precios por tipo de cliente

---

## 2. Orden de prioridad

```
1. PrecioClienteProducto (cliente + producto especifico)
2. ListaPreciosCliente (tipo mayorista, preferencial, etc.)
3. EscalaMayoreo (cantidad >= umbral)
4. PrecioBase tienda + producto
```

---

## 3. Modelo de datos

### PrecioBase

- `productoId`, `tiendaId`, `precioUnitario`

### EscalaMayoreo

- `productoId`, `cantidadMinima`, `precioUnitario`

### PrecioClienteProducto

- `clienteId`, `productoId`, `precioUnitario`

### ListaPrecios

- `listaId`, `nombre` (ej. "Mayorista A")
- Productos con precio override en la lista

---

## 4. Ejemplos

### Abarrotes — mayoreo por caja

- 1-11 piezas: $15.00
- 12+ piezas: $12.50

### Carniceria — mayoreo por kilo

- 0.1-4.9 kg: $180/kg
- 5.0+ kg: $165/kg

### Cliente preferencial

- Restaurante "La Fonda": filete a $160/kg fijo

---

## 5. API interna

```dart
ResultadoPrecio resolverPrecio(ContextoPrecio contexto);
```

`ContextoPrecio` incluye: producto, cantidad, tienda, cliente opcional, canal.

`ResultadoPrecio` incluye: precioUnitario, reglaAplicada (auditoria).

---

## 6. Redondeo

- Moneda MXN: 2 decimales
- Modo: half-up (`0.005` → `0.01`)

---

## 7. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Documento inicial |
