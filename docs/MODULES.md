# Modulos POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Nucleo (siempre activo)

| ID | Nombre | Descripcion |
|----|--------|-------------|
| `core` | Nucleo POS | Ventas, productos, clientes, corte de caja |
| `multi_store` | Multi-tienda | Inventario compartido, transferencias |
| `sync_hub` | Sync hub | Sincronizacion central entre sucursales |
| `sync_lan` | Sync LAN | Sincronizacion entre 2 cajas por tienda |

---

## 2. Modulos comerciales opcionales

| ID | Nombre | Rubro |
|----|--------|-------|
| `wholesale_pricing` | Precios mayoreo | Abarrotes, carniceria |
| `customer_pricing` | Precio preferencial | Todos |
| `credit_sales` | Venta a credito / fiado | Todos |
| `pharmacy` | Farmacia | Lotes, caducidad |
| `butcher` | Carniceria | Peso, cortes, bascula |
| `cfdi` | Facturacion CFDI | Mexico |
| `voice_commands` | Comandos de voz | Accesibilidad |

---

## 3. Activacion por licencia

Archivo `posia.lic` (JSON firmado):

```json
{
  "tenantId": "550e8400-e29b-41d4-a716-446655440000",
  "modules": ["core", "multi_store", "wholesale_pricing"],
  "maxStores": 5,
  "maxRegisters": 10,
  "supportExpiresAt": "2027-06-07"
}
```

Validacion offline en `posia_licensing`.

---

## 4. Paquetes de licencia sugeridos

| Paquete | Tiendas | Cajas | Modulos |
|---------|---------|-------|---------|
| Basico | 1 | 2 | core |
| Negocio | 3 | 6 | core, multi_store, wholesale_pricing |
| Completo | 5 | 10 | todos excepto cfdi |
| Enterprise | ilimitado | ilimitado | todos |

---

## 5. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-07 18:30 | Documento inicial |
