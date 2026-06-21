# Manual de usuario — POSIA

**Autor:** Equipo POSIA  
**Matricula:** POSIA-2026-001  
**Version de la app:** 0.1.0  
**Ultima actualizacion:** 2026-06-11  
**Plataformas:** Windows (escritorio), iPhone, Android

---

## Tabla de contenido

1. [Introduccion](#1-introduccion)
2. [Requisitos e instalacion](#2-requisitos-e-instalacion)
3. [Pantalla principal](#3-pantalla-principal)
4. [Acceso al panel de administracion](#4-acceso-al-panel-de-administracion)
5. [Flujo diario de caja](#5-flujo-diario-de-caja)
6. [Caja en escritorio (Windows)](#6-caja-en-escritorio-windows)
7. [Caja movil por voz (iPhone / Android)](#7-caja-movil-por-voz-iphone--android)
8. [Impresion de tickets](#8-impresion-de-tickets)
9. [Panel de administracion](#9-panel-de-administracion)
10. [Sincronizacion con la nube](#10-sincronizacion-con-la-nube)
11. [Limitaciones](#11-limitaciones)
12. [Solucion de problemas](#12-solucion-de-problemas)
13. [Registro de cambios](#13-registro-de-cambios)

---

## 1. Introduccion

POSIA es un punto de venta **offline-first**: la caja funciona sin internet. Los datos se guardan en el dispositivo y, si configuras un servidor de sincronizacion, se replican automaticamente cuando hay conexion.

### Dos modos de caja

| Plataforma | Interfaz | Uso ideal |
|------------|----------|-----------|
| **Windows** | Grilla de productos, escaner USB, carrito lateral | Caja fija en mostrador |
| **iPhone / Android** | Boton de voz, carrito y cobro | Caja movil, venta rapida hablada |

El panel de **Admin** (inventario, reportes, sync, configuracion) es el mismo en todas las plataformas.

### Forma de pago

POSIA soporta **efectivo, tarjeta, transferencia, mixto y crédito/fiado** en el diálogo de cobro.

---

## 2. Requisitos e instalacion

### Windows (escritorio)

| Requisito | Detalle |
|-----------|---------|
| Sistema | Windows 10 o superior |
| Instalacion | Carpeta completa de la app (no solo el `.exe`) |
| Opcional | Impresora termica por red (IP, puerto 9100) |
| Opcional | Lector de codigos USB tipo teclado |

**Primer arranque:**

1. Ejecuta `posia_pos.exe` desde la carpeta `Release`.
2. La app crea la base de datos local (`posia_local.db`).
3. En instalacion nueva carga datos de demostracion (productos, categorias, vendedores).

### iPhone

| Requisito | Detalle |
|-----------|---------|
| Dispositivo | iPhone con iOS reciente (recomendado fisico, no simulador) |
| Permisos | Microfono y reconocimiento de voz (la app los solicita al abrir caja) |
| Desarrollo | Licencia de desarrollador Apple para instalar desde Xcode o `flutter run` |

**Primer arranque:**

1. Instala la app en el iPhone (Xcode o `flutter run -d <tu-iphone>`).
2. Acepta permiso de microfono cuando aparezca.
3. La base local y datos demo se crean igual que en escritorio.

### Android

| Requisito | Detalle |
|-----------|---------|
| Sistema | Android 8 o superior |
| Permisos | Microfono e internet (para sync) |

---

## 3. Pantalla principal

Tras elegir tienda e **iniciar sesión** (usuario + contraseña), la barra inferior muestra:

| Pestaña | Funcion | Quien la ve |
|---------|---------|-------------|
| **Caja** | Registrar ventas | Todos |
| **Admin** | Configuracion, inventario y reportes | Supervisor y administrador |

Los **empleados** solo ven **Caja**; **Mi cuenta** esta en el icono de perfil de la barra superior.

- En **Windows** veras la grilla completa de productos.
- En **iPhone/Android** veras la caja minimalista con boton **Hablar**.

---

## 4. Inicio de sesion y PINs

### Flujo

1. Al abrir la app, **selecciona la tienda**.
2. En **Iniciar sesion**, ingresa tu **codigo de usuario** (numerico).
3. Ingresa tu **contrasena** (PIN de 4 digitos) en el teclado numerico.

### Cuentas por defecto (datos demo)

| Usuario | Contrasena | Persona | Rol |
|---------|------------|---------|-----|
| `1000` | `1234` | Ana Administradora | Administrador |
| `2001` | `2345` | Carlos Supervisor Centro | Supervisor |
| `2002` | `2345` | Laura Supervisor Norte | Supervisor |
| `3001` | `3456` | Pedro Empleado | Empleado |

Respaldo admin del dispositivo: usuario `0000` + PIN de configuracion (demo: `1234`).

### Administracion del PIN

- **Usuarios:** Admin → **Usuarios** para crear cuentas y asignar PIN por persona.
- **PIN del dispositivo (admin):** Admin → **Configuracion** → **Guardar PIN** (respaldo de acceso administrativo; demo: `1234`).
- **Tu propio PIN:** Admin → **Mi cuenta** → **Cambiar PIN**.

> En produccion configura PINs propios del negocio y desactiva o cambia las cuentas demo antes de operar.

---

## 5. Panel de administracion

El acceso a Admin depende del rol con el que iniciaste sesion:

- **Administrador:** todas las secciones.
- **Supervisor:** usuarios de su tienda, inventario y operacion limitada.
- **Empleado:** sin panel Admin (solo caja).

Para volver a caja, toca la pestaña **Caja**. Para cerrar sesion, usa **Cerrar sesion** en la barra superior.

---

## 6. Flujo diario de caja

Este flujo aplica en **todas** las plataformas.

### Paso 1 — Abrir turno (obligatorio)

Sin turno abierto **no se puede cobrar**.

1. Admin → **Corte de caja**
2. Escribe el **fondo inicial** en efectivo (ej. $500)
3. Toca **Abrir turno**

Veras un candado abierto (verde) cuando el turno esta activo.

### Paso 2 — Registrar ventas

- **Escritorio:** grilla, escaner o teclado (ver seccion 6).
- **Movil:** voz o texto (ver seccion 7).

Opcional en escritorio: seleccionar **Vendedor** y **Cliente** antes de cobrar.

### Paso 3 — Cobrar

1. Verifica el total del carrito.
2. Toca **COBRAR**.
3. Confirma el monto.
4. Se genera el ticket (archivo o impresora segun configuracion).

### Paso 4 — Cerrar turno (fin del dia)

1. Admin → **Corte de caja**
2. Revisa: ventas del turno, efectivo vendido, efectivo esperado en caja.
3. Toca **Cerrar turno**
4. Se imprime o guarda el ticket de corte automaticamente.

---

## 6. Caja en escritorio (Windows)

### Vista general

```
┌─────────────────────────────────────────────────────────┐
│  Tienda Centro                              Total $XXX  │
├─────────────────────────────────────────────────────────┤
│ [Todos] [Bebidas] [Abarrotes] [Lacteos] ...             │
├──────────────────────────┬──────────────────────────────┤
│   GRILLA DE PRODUCTOS    │      CARRITO / LINEAS        │
├──────────────────────────┴──────────────────────────────┤
│ [Escanear] [Vendedor] [Cliente] [Cancelar]   [COBRAR]  │
└─────────────────────────────────────────────────────────┘
```

### Barra de categorias

- Chips horizontales con icono y color.
- **Todos** muestra el catalogo completo.
- Toca una categoria para filtrar productos.

### Agregar productos

| Metodo | Como |
|--------|------|
| Tocar producto | Un toque en la grilla agrega 1 unidad |
| Codigo de barras | Escanea con lector USB (tipo teclado) o toca **Escanear** para escribir el codigo |
| Variantes | Si el producto tiene presentaciones (ej. Coca 600ml / 2L), aparece un dialogo al tocarlo |

### Productos especiales

| Tipo | Comportamiento |
|------|----------------|
| **Carniceria** | Pide peso en kilogramos |
| **Farmacia** | Pide seleccion de lote (caducidad FEFO) |

### Botones de accion

| Boton | Funcion |
|-------|---------|
| **Escanear** | Entrada manual de codigo de barras |
| **Vendedor** | Asigna vendedor activo para reportes |
| **Cliente** | Asigna cliente; aplica precios preferenciales o mayoreo |
| **Cancelar** | Vacia el carrito (con confirmacion) |
| **COBRAR** | Cierra la venta en efectivo |

### Aviso sin turno

Si no hay turno abierto, aparece un aviso naranja y el cobro queda bloqueado.

---

## 7. Caja movil por voz (iPhone / Android)

La caja movil esta pensada para vender **hablando**. Es la funcion principal en telefono.

### Elementos de pantalla

| Elemento | Funcion |
|----------|---------|
| **Hablar** | Activa el microfono; dicta la venta |
| **Detener** | Para la escucha |
| Campo de texto | Mismo comando por escrito si prefieres no hablar |
| **Procesar texto** | Ejecuta el comando escrito |
| Carrito | Productos agregados con cantidad resuelta |
| **COBRAR** | Cierra venta en efectivo |

### Comandos de voz — agregar productos

Habla de forma natural en espanol. Ejemplos:

```
Genera el ticket: vendi un kilogramo de arroz, medio kilo de frijol peruano y 1 caja de leche
```

```
Agrega dos litros de aceite y una lata de atun
```

```
Vendi media caja de huevo
```

Palabras clave que entiende el sistema:

| Palabra | Significado |
|---------|-------------|
| kilo, kilogramo, kg | Peso en kilogramos |
| litro, litros | Volumen en litros |
| caja, carton | Empaque (ver tabla de cajas abajo) |
| pieza, lata, unidad | Unidad suelta |
| medio, media, mitad | 0.5 unidades |

### Comandos de voz — otras acciones

| Decir... | Accion |
|----------|--------|
| *Cobrar* / *Cobra en efectivo* / *Cierra la venta* | Cierra la venta actual |
| *Vacia el carrito* / *Cancela la venta* | Borra el carrito sin cobrar |

### Como el sistema entiende las cajas

Cuando dices *"1 caja de leche"*, POSIA consulta el catalogo para saber si la caja es **una unidad de venta** o un **empaque con varias piezas**:

| Producto (demo) | Unidad de venta | Piezas por caja | Si dices "1 caja de..." |
|-----------------|-----------------|-----------------|-------------------------|
| Leche 1L | litro | 12 | Agrega **12 litros** |
| Atun lata | pieza | 24 | Agrega **24 latas** |
| Huevo carton 12 | caja | — | Agrega **1 carton** |

> Para productos nuevos, el dueno debe configurar en catalogo cuantas piezas trae cada caja (`piezas_por_caja`). Sin ese dato, "1 caja" cuenta como 1 unidad.

### Flujo recomendado en iPhone

1. Admin → **Corte de caja** → abrir turno.
2. Pestaña **Caja** → toca **Hablar**.
3. Dicta el ticket completo en una frase.
4. Revisa el carrito y los mensajes de confirmacion.
5. Toca **COBRAR**.
6. Al final del dia: Admin → **Corte de caja** → cerrar turno.

### Si el microfono no funciona

- Usa el **campo de texto** y **Procesar texto** con la misma frase.
- Verifica permisos: Ajustes del iPhone → POSIA → Microfono activado.
- El reconocimiento de voz funciona mejor en **dispositivo fisico** que en simulador.

---

## 8. Impresion de tickets

Configura la impresora en Admin → **Configuracion**.

| Modo | Comportamiento |
|------|----------------|
| **Solo archivo** | Guarda tickets en carpeta local |
| **Solo red** | Envia a impresora termica ESC/POS (IP, puerto 9100) |
| **Red + archivo** | Intenta red; si falla, guarda archivo |

### Ubicacion de archivos

| Plataforma | Ruta |
|------------|------|
| Windows | `Documents\POSIA\tickets` |
| iPhone / Android | Documentos de la app → `POSIA/tickets` |

### Cuando se imprime

| Evento | Ticket |
|--------|--------|
| Cobro exitoso | Ticket de venta |
| Cerrar turno | Ticket de corte de caja |
| Historial → Detalle → **Reimprimir** | Copia del ticket de venta |

---

## 9. Panel de administracion

### Ventas

| Opcion | Que hace |
|--------|----------|
| **Ventas hoy** | Resumen del dia y lista de tickets |
| **Historial** | Ventas de 1, 7 o 30 dias; detalle; anular; reimprimir |
| **Corte de caja** | Abrir y cerrar turno |
| **Vendedores** | Registrar y editar vendedores |

**Anular venta:** Historial → icono deshacer. Revierte stock y sincroniza con otras cajas.

**Devolucion parcial:** Historial → tocar venta → **Devolver** → cantidad por linea.

**Reimprimir:** Historial → tocar venta → **Reimprimir**.

### Catalogo

| Opcion | Que hace |
|--------|----------|
| **Categorias** | Crear y activar categorias para la grilla de caja |
| **Productos** | Ver catalogo; alta rapida; variantes (icono capas) |
| **Carniceria** | Productos por peso |
| **Farmacia** | Lotes y alertas de caducidad |

### Inventario

| Opcion | Que hace |
|--------|----------|
| **Existencias** | Stock por tienda; tocar fila para stock minimo |
| **Movimientos** | Entrada, salida o ajuste con motivo |
| **Traspasos** | Enviar o recibir entre sucursales |

### Personas

| Opcion | Que hace |
|--------|----------|
| **Clientes** | Alta, editar, activar/desactivar |
| **Vendedores** | Alta, editar codigo y nombre |
| **Proveedores** | Alta, editar datos |

### Reportes y sistema

| Opcion | Que hace |
|--------|----------|
| **Reportes** | Ventas por vendedor; alertas de faltantes; exportar CSV |
| **Sincronizar** | URL del hub, API Key, cola, sync manual |
| **Configuracion** | Tenant ID, tienda, caja, impresora, PIN |

**Alertas de faltantes:** Configura stock minimo en Inventario → Existencias (tocar fila de tu tienda).

---

## 10. Sincronizacion con la nube

POSIA puede sincronizar varias cajas contra un servidor en la nube. Guía técnica: [DEPLOYMENT.md](DEPLOYMENT.md) § Hub de sincronización.

### Configuracion rapida

1. Admin → **Sincronizar**
2. **URL del hub:** `https://tu-api.onrender.com`
3. **API Key:** la clave configurada en el servidor
4. **Guardar** → **Sincronizar ahora**

### Comportamiento

- Sync automatico cada 60 segundos cuando hay internet.
- Reintenta al recuperar conexion.
- Replica: ventas, catalogo, variantes, movimientos, devoluciones, anulaciones.

### Tenant ID

En Admin → **Configuracion**, el **Tenant ID** debe coincidir con el tenant en la nube. Si lo cambias, **reinicia la app**.

---

## 11. Limitaciones

| Funcion | Estado |
|---------|--------|
| Pago con tarjeta / mixto / crédito | Disponible en diálogo de cobro |
| Escaneo por camara en movil | No disponible (usa voz o texto) |
| Lector USB en movil | No aplica |
| Admin completo en telefono | Disponible pero pensado para tablet o tareas puntuales |

---

## 12. Solucion de problemas

| Problema | Solucion |
|----------|----------|
| No puedo cobrar | Abre turno en Admin → Corte de caja |
| PIN incorrecto | Verifica usuario y contrasena; demo empleado: `3001` / `3456` |
| Productos no aparecen | Verifica categoria asignada y que esten activos |
| Voz no reconoce producto | Nombre debe parecerse al del catalogo; prueba por texto |
| "1 caja" agrega cantidad incorrecta | Revisa `piezas_por_caja` del producto en catalogo |
| Sync no funciona | Revisa URL, API Key y que el servidor este activo |
| No imprime en red | Verifica IP y puerto 9100; usa modo "ambos" como respaldo |
| App no abre en Windows | Ejecuta desde carpeta `Release` completa con DLLs |
| Microfono bloqueado en iPhone | Ajustes → POSIA → activar Microfono |

---

## 13. Registro de cambios

| Fecha | Cambio |
|-------|--------|
| 2026-06-11 23:00 | Manual inicial — escritorio piloto |
| 2026-06-11 26:00 | Impresion, sync nube, devoluciones |
| 2026-06-11 28:00 | Manual completo: escritorio + movil por voz, iPhone |

---

## Documentación relacionada

- [ADMIN.md](ADMIN.md) — panel de administración
- [DEPLOYMENT.md](DEPLOYMENT.md) — despliegue y sync en nube
- [PUBLICACION_MOVIL.md](PUBLICACION_MOVIL.md) — tiendas móviles
