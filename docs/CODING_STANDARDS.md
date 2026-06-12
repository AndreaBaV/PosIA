# Estandares de codificacion POSIA

Documento normativo para todo el codigo fuente del proyecto POSIA (Dart/Flutter).

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Fecha creacion:** 2026-06-07 18:30:00 (UTC-6)  
**Ultima modificacion:** 2026-06-07 18:30:00 (UTC-6)

---

## 1. Nombres de identificadores

| Elemento | Convencion | Ejemplo |
|----------|------------|---------|
| Variables y funciones | camelCase | `precioUnitario`, `calcularTotal()` |
| Constantes | UPPER_SNAKE_CASE | `MAX_CAJAS_POR_TIENDA` |
| Clases | PascalCase singular | `Venta`, `Producto`, `MotorPrecio` |
| Archivos | snake_case | `motor_precio.dart` |
| Paquetes | snake_case | `posia_pricing` |

### Reglas adicionales

- El nombre debe ser representativo del contenido o proposito.
- No usar acentos, diéresis ni letra ene en identificadores.
- Preferir terminos en espanol para dominio de negocio (`Venta`, `Tienda`) y ingles para infraestructura tecnica (`Repository`, `Adapter`) cuando sea convencion del ecosistema.

---

## 2. Estructura del codigo

- Separar elementos de un estatuto con espacio en blanco cuando mejore legibilidad.
- Literales decimales: al menos un digito antes y despues del punto (`0.0`, `1.5`).
- Usar parentesis solo cuando sean necesarios por precedencia.
- Una linea de codigo = un estatuto.
- Sangria: **un Tab** por nivel de anidacion.
- Llave de apertura `{` en la misma linea del encabezado.
- Llave de cierre `}` alineada al margen izquierdo de la estructura que delimita.
- Separar funciones o secciones logicas con un renglon en blanco.
- No declarar variables sin uso.

### Ejemplo Dart

```dart
void procesarVenta(Venta venta) {
	if (venta.lineas.isEmpty) {
		return;
	}
	final total = calcularTotal(venta);
	registrarVenta(venta, total);
}
```

---

## 3. Comentarios y documentacion

### 3.1 Encabezado de archivo (obligatorio)

Todo archivo `.dart` debe iniciar con bloque de documentacion:

```dart
/// Descripcion breve del modulo o archivo.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;
```

Actualizar `Ultima modificacion` en cada cambio significativo.

### 3.2 Funciones y metodos (obligatorio)

Los comentarios van **antes** de la definicion, nunca entre lineas del cuerpo ni entre funciones mezclados con codigo.

```dart
/// Calcula el precio final aplicando reglas de mayoreo y cliente.
///
/// [producto] Producto a cotizar.
/// [cantidad] Unidades o kilogramos solicitados.
/// [cliente] Cliente opcional; null indica mostrador.
/// Retorna el precio unitario resuelto en MXN.
double resolverPrecio(Producto producto, double cantidad, Cliente? cliente) {
	// cuerpo
}
```

### 3.3 Clases

Documentar proposito de la clase antes de su declaracion.

### 3.4 Prohibiciones

- No comentarios obvios que repiten el codigo.
- No dejar codigo comentado (codigo muerto).
- No comentarios inline salvo casos excepcionales de algoritmos no triviales (evitar en general).

---

## 4. Metodos y funciones

- Una funcion = una responsabilidad completa.
- No usar `break` ni `continue` dentro de ciclos; preferir extraccion a funciones, condiciones claras o colecciones funcionales.
- Variables locales con valor inicial cuando aplique.

---

## 5. Flutter / Dart especifico

| Tema | Regla POSIA |
|------|-------------|
| State management | Riverpod en aplicacion |
| Persistencia | Drift + SQLite |
| Monorepo | Melos |
| Tests | `test/` por paquete, nombre `*_test.dart` |
| Exports | Un barrel file por paquete (`posia_core.dart`) |

---

## 6. Control de calidad

Antes de integrar codigo:

```bash
melos run analyze
melos run test
melos run format
```

---

## 7. Registro de cambios de este documento

| Fecha | Autor | Cambio |
|-------|-------|--------|
| 2026-06-07 18:30 | POSIA-2026-001 | Version inicial |
