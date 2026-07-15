# Manual de usuario — POSIA

**Autor:** Equipo POSIA  
**Matrícula:** POSIA-2026-001  
**Versión de la app:** 1.0.0  
**Última actualización:** 2026-06-24  
**Plataformas:** Windows (escritorio), iPhone, Android

---

## Tabla de contenido

1. [Introducción](#1-introducción)
2. [Requisitos e instalación](#2-requisitos-e-instalación)
3. [Pantalla principal](#3-pantalla-principal)
4. [Inicio de sesión y PINs](#4-inicio-de-sesión-y-pins)
5. [Panel de administración](#5-panel-de-administración)
6. [Flujo diario de caja](#6-flujo-diario-de-caja)
7. [Caja en escritorio (Windows)](#7-caja-en-escritorio-windows)
8. [Caja móvil por voz (iPhone / Android)](#8-caja-móvil-por-voz-iphone--android)
9. [Inventario de funciones](#9-inventario-de-funciones)
10. [Impresión de tickets](#10-impresión-de-tickets)
11. [Sincronización con la nube](#11-sincronización-con-la-nube)
12. [Asistencia y nómina](#12-asistencia-y-nómina)
13. [Limitaciones](#13-limitaciones)
14. [Solución de problemas](#14-solución-de-problemas)

---

## 1. Introducción

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

## 2. Requisitos e instalación

### Windows (escritorio)

| Requisito | Detalle |
|-----------|---------|
| Sistema | Windows 10 o superior |
| Instalacion | Carpeta completa de la app (no solo el `.exe`) |
| Opcional | Impresora termica por red (IP, puerto 9100) |
| Opcional | Lector de codigos USB tipo teclado |

**Primer arranque:**

1. Ejecuta `posia_pos.exe` desde la carpeta `Release`.
2. La app crea la base de datos local (`posia_local.db`) vacía.
3. Usuarios y catálogo llegan por **sync con el hub** o se cargan en Admin.

### iPhone

| Requisito | Detalle |
|-----------|---------|
| Dispositivo | iPhone con iOS reciente (recomendado fisico, no simulador) |
| Permisos | Microfono y reconocimiento de voz (la app los solicita al abrir caja) |
| Desarrollo | Licencia de desarrollador Apple para instalar desde Xcode o `flutter run` |

**Primer arranque:**

1. Instala la app en el iPhone (Xcode o `flutter run -d <tu-iphone>`).
2. Acepta permiso de microfono cuando aparezca.
3. La base local se crea vacía; los datos operativos llegan por sync o Admin.

### Android

| Requisito | Detalle |
|-----------|---------|
| Sistema | Android 8 o superior |
| Permisos | Microfono e internet (para sync) |

---

## 3. Pantalla principal

Tras **iniciar sesión** (usuario + contraseña), el administrador elige tienda; supervisor y empleado entran directo. La barra inferior muestra:

| Pestaña | Funcion | Quien la ve |
|---------|---------|-------------|
| **Caja** | Registrar ventas | Todos |
| **Admin** | Configuracion, inventario y reportes | Supervisor y administrador |

Los **empleados** solo ven **Caja**; **Mi cuenta** esta en el icono de perfil de la barra superior.

- En **Windows** veras la grilla completa de productos.
- En **iPhone/Android** veras la caja minimalista con boton **Hablar**.

---

## 4. Inicio de sesión y PINs

### Flujo

1. Ingresa tu **código de usuario** (numérico) y pulsa Continuar.
2. Confirma tu **contraseña** (PIN de 4 dígitos) en el teclado de tu rol.
3. **Administrador:** elige la tienda. **Supervisor / empleado:** entran directo a su tienda.

### Administración del PIN

- **Usuarios:** Admin → **Usuarios** para crear cuentas (máx. 15 activas por licencia).
- **PIN del dispositivo (admin):** Admin → **Configuración** → **Guardar PIN** (respaldo técnico con usuario `0000`).
- **Tu propio PIN:** Admin → **Mi cuenta** → **Cambiar PIN**.

---

## 5. Panel de administración

El acceso a Admin depende del rol con el que iniciaste sesión:

- **Administrador:** todas las secciones.
- **Supervisor:** usuarios de su tienda, inventario y operación limitada.
- **Empleado:** sin panel Admin (solo caja, asistencia y pedidos en móvil).

Para volver a caja, toca la pestaña **Caja**. Para cerrar sesión, usa **Cerrar sesión** en la barra superior.

### Ventas

| Opción | Qué hace |
|--------|----------|
| **Ventas hoy** | Resumen del día y lista de tickets |
| **Historial** | Ventas de 1, 7 o 30 días; detalle; anular; devolución parcial; reimprimir |
| **Pedidos** | Recibir pedidos y asignar empleado |
| **Créditos** | Fiados pendientes; liquidar |
| **Cotizaciones** | Historial guardado; reimprimir; WhatsApp |
| **Corte de caja** | Abrir y cerrar turno |

### Catálogo

| Opción | Qué hace |
|--------|----------|
| **Categorías** | Crear y activar categorías para la grilla de caja |
| **Productos** | Catálogo completo; variantes; etiquetas PDF; **alta por voz** en móvil |
| **Listas de precios** | Precios por lista y por cliente |

Carnicería y farmacia se configuran como categorías de producto (peso y lotes).

### Alta de producto por voz (iPhone / Android)

En **Admin → Productos → nuevo o editar**, toca el micrófono de la barra superior.

1. Dicta el producto en una sola frase.
2. Revisa el resumen y confirma **Aplicar al formulario**.
3. Corrige lo que falte y guarda.

Ejemplos:

```
Coca Cola precio 25 costo 18 categoría refrescos stock 40
```

```
Jitomate por kilo a 35 pesos medio kilo 20 cuarto 12
```

```
Arroz código 750123 precio 28.50 mayoreo desde 10 a 25
```

Puedes dictar: nombre, código, categoría, proveedor, unidad, costo, precio, medio/cuarto kilo, stock, mínimo, mayoreo y notas. Si la categoría o el proveedor no existen en el catálogo, el resto se aplica y te avisa para elegirlos a mano. En Windows el micrófono indica que el dictado solo está en móvil.

### Inventario

| Opción | Qué hace |
|--------|----------|
| **Existencias** | Stock por tienda; tocar fila para stock mínimo |
| **Compras** | Entradas de proveedor |
| **Movimientos** | Entrada, salida o ajuste con motivo |
| **Traspasos** | Enviar o recibir entre sucursales |
| **Almacenes** | Centros de distribución |
| **Presentaciones** | Tipos caja, bulto, etc. |

### Personas

| Opción | Qué hace |
|--------|----------|
| **Clientes** | Alta, editar, ficha con historial de ventas |
| **Equipo** | Usuarios, roles, PIN, tarifa nómina |
| **Proveedores** | Alta, editar, productos vinculados |

### Reportes y sistema

| Opción | Qué hace |
|--------|----------|
| **Tiendas** | Alta, baja (máx. 5 activas), geocerca asistencia |
| **Reportes** | KPIs, alertas de faltantes; exportar CSV |
| **Estado de la nube** | Cola sync, sync manual |
| **Configuración** | Tienda, caja, impresora, PIN admin |

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
3. Elige forma de pago: efectivo, tarjeta, transferencia, mixto o crédito.
4. Se genera el ticket (archivo o impresora según configuración).
5. Opcional: enviar ticket por WhatsApp.

### Compartir por WhatsApp

Desde historial de ventas, cotizaciones guardadas o al terminar una venta/cotizacion puede enviar el texto del ticket por WhatsApp.

### Cajon de dinero

En Admin → **Configuracion** active **Abrir cajon al cobrar** y configure la impresora termica por red (puerto 9100). El cajon debe estar conectado a la impresora.

### Paso 4 — Cerrar turno (fin del dia)

1. Admin → **Corte de caja**
2. Revisa: ventas del turno, efectivo vendido, efectivo esperado en caja.
3. Toca **Cerrar turno**
4. Se imprime o guarda el ticket de corte automaticamente.

---

## 7. Caja en escritorio (Windows)

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
| **COBRAR** | Abre diálogo de cobro (multipago) |
| **En espera** | Guarda carrito para atender otro cliente |
| **Recuperar** | Restaura ticket en espera |
| **Cotizar** | Guarda cotización sin cobrar |

### Aviso sin turno

Si no hay turno abierto, aparece un aviso naranja y el cobro queda bloqueado.

---

## 8. Caja móvil por voz (iPhone / Android)

La caja movil esta pensada para vender **hablando**. Es la funcion principal en telefono.

### Elementos de pantalla

| Elemento | Funcion |
|----------|---------|
| **Hablar** | Activa el microfono; dicta la venta |
| **Detener** | Para la escucha |
| Campo de texto | Mismo comando por escrito si prefieres no hablar |
| **Procesar texto** | Ejecuta el comando escrito |
| Carrito | Productos agregados con cantidad resuelta |
| **COBRAR** | Diálogo de cobro (efectivo, tarjeta, transferencia, mixto, crédito) |
| **Pausa** | Poner ticket en espera |
| **Lista** | Recuperar tickets en espera (badge con cantidad) |
| **Cotizar** | Guardar cotización desde el carrito |
| **Vaciar** | Borrar carrito con confirmación |

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

| Producto (ejemplo) | Unidad de venta | Piezas por caja | Si dices "1 caja de..." |
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

---

## 9. Inventario de funciones

Resumen de capacidades por plataforma (v1.0).

### Por plataforma

| Área | Windows | iPhone / Android |
|------|---------|------------------|
| Caja | Grilla + escáner USB | Voz + texto manual |
| Admin completo | Sí | Sí |
| Asistencia empleados | Limitado | Sí (GPS + biometría) |
| Impresora térmica red | Sí | Archivo de respaldo |
| Sync hub | Sí | Sí |

### Caja — venta y cobro

| Función | Windows | Móvil |
|---------|---------|-------|
| Grilla por categoría | Sí | No |
| Escáner USB | Sí | No |
| Comandos de voz | No | Sí |
| Variantes y mayoreo | Sí | Sí |
| Productos por peso (carnicería) | Sí | Sí |
| Lotes farmacia (FEFO) | Sí | Sí (voz: primer lote) |
| Multipago y crédito | Sí | Sí |
| Ticket en espera / recuperar | Sí | Sí |
| Cotización desde carrito | Sí | Sí |
| Atajos de teclado | Sí | No |
| WhatsApp ticket/cotización | Sí | Sí |

### Admin — módulos disponibles

| Sección | Funciones |
|---------|-----------|
| Cuenta | Mi cuenta, equipo, asistencia, nómina |
| Ventas | Ventas hoy, pedidos, historial, créditos, cotizaciones, corte |
| Catálogo | Categorías, productos, variantes, etiquetas PDF, listas de precios |
| Inventario | Existencias, compras, movimientos, traspasos, almacenes, presentaciones |
| Personas | Clientes, proveedores |
| Sistema | Tiendas, reportes, sync, configuración |

### Empleados (móvil)

Pestañas **Caja**, **Asistencia** (PIN + geocerca + Face ID) y **Mis pedidos**.

### Fuera de alcance v1.0

CFDI / timbrado, escáner por cámara en móvil, web como producción.

---

## 10. Impresión de tickets

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

## 11. Sincronización con la nube

La conexion al hub va **incluida en la app** al publicarla (Play Store / App Store). El usuario **no** configura Tenant ID ni URL.

Al abrir la app por primera vez:
1. Selecciona tienda
2. Inicia sesion con su codigo y PIN
3. La sync con la nube corre sola cada 60 s si hay internet

### Para quien publica la app (una sola vez)

Al compilar el release se embeben hub y API key (ver manual técnico §11). Cada dispositivo recibe un identificador de caja único automáticamente.

### Para soporte tecnico (casos excepcionales)

- **Configuracion tecnica** en la pantalla de login (PIN del dispositivo) para cambiar hub o tenant sin reinstalar.

### Para administradores de tienda

- Admin → **Estado de la nube**: ver pendientes y forzar sync manual si hace falta.

---

## 12. Asistencia y nómina

### Asistencia

1. Configure **latitud, longitud y radio** en Admin → **Tiendas**.
2. Admin → **Asistencia** → **Generar PIN** (válido 5 minutos).
3. El empleado abre **Asistencia** en el celular e ingresa el PIN dentro del radio de la tienda.
4. Alternativa: **Entrada con biometría** (Face ID / huella) en la geocerca.

### Nómina

1. Asigne **tarifa por hora** en Admin → **Equipo**.
2. Admin → **Nómina** → calcule el periodo semanal.
3. Exporte CSV al portapapeles.

---

## 13. Limitaciones

| Función | Estado |
|---------|--------|
| Escaneo por cámara en móvil | No disponible (usa voz o texto) |
| Lector USB en móvil | No aplica |
| Admin completo en teléfono | Disponible; pensado para tablet o tareas puntuales |
| CFDI / timbrado | Fuera de alcance v1.0 |

---

## 14. Solución de problemas

| Problema | Solucion |
|----------|----------|
| No puedo cobrar | Abre turno en Admin → Corte de caja |
| PIN incorrecto | Verifica usuario y contraseña con el administrador del negocio |
| Productos no aparecen | Verifica categoria asignada y que esten activos |
| Voz no reconoce producto | Nombre debe parecerse al del catalogo; prueba por texto |
| Dictado de alta no aplica categoría | La categoría debe existir y estar activa; elígela en el formulario |
| Micrófono en productos (Windows) | El dictado de alta solo funciona en iPhone/Android |
| "1 caja" agrega cantidad incorrecta | Revisa `piezas_por_caja` del producto en catalogo |
| Sync no funciona | Revisa URL, API Key y que el servidor este activo |
| "No se pudo contactar el servidor" (cliente nuevo) | En Configuración técnica usa **Probar conexión**. Si falla y Northflank no muestra logs, la laptop del cliente no alcanza el hub (URL, internet, firewall). Tu equipo puede seguir entrando con datos locales guardados de un login anterior. |
| No imprime en red | Verifica IP y puerto 9100; usa modo "ambos" como respaldo |
| App no abre en Windows | Ejecuta desde carpeta `Release` completa con DLLs |
| Microfono bloqueado en iPhone | Ajustes → POSIA → activar Microfono |

---

Historial de versiones: ver [CONTROL_CAMBIOS.md](CONTROL_CAMBIOS.md).  
Despliegue, builds e iOS: ver [MANUAL_TECNICO.md](MANUAL_TECNICO.md).
