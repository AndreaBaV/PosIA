# La Fortuna — Tienda en línea

Catálogo público y captura de pedidos para clientes finales. El cliente arma su
pedido, recibe **folio + ticket** y continúa por **WhatsApp** para acordar pago y
entrega. El pedido entra al POS como cualquier pedido de caja.

Corre en **Cloudflare Pages** (plan gratuito), **no** en el hub de Northflank.

**Autor:** Equipo POSIA · **Matrícula:** POSIA-2026-001
**Fecha creación:** 2026-07-29

---

## Por qué fuera del hub

El hub de Northflank está en plan gratuito y atiende la sincronización de las
cajas: es infraestructura de operación, no de tráfico público. Si la tienda
viviera ahí, cada visita al catálogo competiría con el sync de las cajas y
despertaría el contenedor en frío.

Aquí el hub **no participa**: Cloudflare sirve el sitio desde el borde y habla
directo con Neon. La tienda sigue funcionando aunque Northflank esté suspendido.

```
Navegador del cliente
        │
        ▼
Cloudflare Pages  ──────────────►  Neon (Postgres)
  · sitio estático (borde)            · lee products / categories
  · funciones /v1/public/*            · escribe sync_events + orders + order_lines
        │
        └─ el pedido queda en sync_events …
                                          │
Cajas POSIA ── pull normal /v1/events ────┘  ──►  módulo Pedidos del POS
```

El pedido **no** se escribe solo en `orders`: se guarda además como evento
`orderUpserted` en `sync_events`, exactamente como lo haría el hub. Por eso
aparece en el módulo **Pedidos** de todas las cajas (estado `recibido`, listo
para asignar y entregar) en su siguiente sincronización. El evento se firma con
el dispositivo `tienda-web`, que no es ninguna caja, así que ninguna se lo pierde.

> **Acoplamiento a vigilar:** `lib/pedido.js` replica lo que hace
> `ProyectorEventosPostgres._pedido`
> (`server/sync_api/lib/src/proyector_eventos_postgres.dart`). Si esa proyección
> cambia, hay que actualizar este lado.

## Estructura

```
LandingPages/la-fortuna/
├── public/              # Sitio estático (HTML, CSS y JS sin build)
├── functions/           # Cloudflare Pages Functions (la ruta = el archivo)
│   ├── _middleware.js   #   CORS y traducción de errores
│   └── v1/public/…
├── lib/                 # Lógica portable: consultas, validación, ticket
├── test/                # node --test, sin base de datos
├── wrangler.toml
└── package.json
```

`lib/` no depende de ninguna API de Cloudflare: mover la tienda a otro
proveedor es reescribir los cinco archivos delgados de `functions/`.

## Endpoints

| Endpoint | Uso |
|----------|-----|
| `GET /v1/public/tienda` | Nombre, dirección y WhatsApp |
| `GET /v1/public/categorias` | Categorías con productos publicables |
| `GET /v1/public/catalogo?q=&categoria=&limite=&desde=` | Página del catálogo |
| `POST /v1/public/pedidos` | Alta de pedido → folio, ticket y enlace WhatsApp |
| `GET /v1/public/pedidos/{folio}` | Seguimiento por folio |

Reglas que aplica el servidor:

- **Nunca se expone inventario.** El catálogo es vitrina: nombre, precio,
  unidad, categoría y presentaciones con precio propio. Sin existencias.
- **Los precios se releen de Neon** al crear el pedido; el navegador solo dice
  *qué* y *cuánto*, jamás *a qué precio*.
- **Catálogo unificado**: se publica el de todas las sucursales activas, sin
  importar de cuál sea cada producto. Un artículo que existe en varias sale una
  sola vez (gana la ficha de la tienda principal; si no está ahí, la más barata).
- Solo salen productos `activo = 1` con precio > 0.
- Los pedidos se centralizan en la **tienda principal** (la de mayor catálogo, o
  la que fije `TIENDA_PUBLICA_ID`) porque `orders.tienda_id` es obligatorio;
  desde ahí el administrador los reasigna a otra sucursal o a un empleado.
- Tope de 100 partidas y 9 999 unidades por partida.
- Las lecturas se cachean en el borde (catálogo 5 min, tienda 1 h): cientos de
  visitas consumen una sola consulta a Neon. Es lo que mantiene el cómputo de
  Neon dentro del plan gratuito.

## Variables de entorno (Cloudflare Pages)

| Variable | Requerida | Descripción |
|----------|-----------|-------------|
| `DATABASE_URL` | sí | Cadena de conexión de Neon. Cárgala como **Secret**, no como variable normal |
| `TIENDA_PUBLICA_ID` | no | Sucursal que recibe los pedidos; sin ella, la de mayor catálogo. No limita lo que se publica |
| `TIENDA_PUBLICA_NOMBRE` | no | Default `La Fortuna` |
| `TIENDA_PUBLICA_WHATSAPP` | no | Default `527226527751` (52 + 10 dígitos) |

## Desarrollo local

```bash
cd LandingPages/la-fortuna
npm install
npm test
```

Para levantar el sitio con las funciones, crea `.dev.vars` (ignorado por Git)
con la `DATABASE_URL` de la rama Neon **pruebas** — nunca la de producción:

```
DATABASE_URL=postgres://…ep-old-glitter-adr6mmgk…
```

```bash
npx wrangler pages dev
```

## Despliegue

En el panel de Cloudflare: **Workers & Pages → Create → Pages → Connect to Git**.

| Ajuste | Valor |
|--------|-------|
| Repositorio | `AndreaBaV/PosIA` |
| Rama de producción | `main` |
| Root directory | `LandingPages/la-fortuna` |
| Build command | *(vacío)* |
| Build output directory | `public` |
| Variables | `DATABASE_URL` como **Secret**; las demás, opcionales |

A partir de ahí cada push a `main` redespliega la tienda, igual que el hub con
Northflank, pero en tuberías separadas: tocar la tienda no redespliega el hub y
viceversa.

La URL pública queda como `https://la-fortuna.pages.dev`. Para usar dominio
propio: **Custom domains** en el mismo proyecto.

### Protección contra abuso

El límite por IP no puede vivir en memoria (cada petición puede caer en un
isolate distinto). Se configura en Cloudflare, no en el código:
**Security → WAF → Rate limiting rules**; por ejemplo, 10 peticiones por minuto
a `/v1/public/pedidos` por IP. El plan gratuito incluye una regla.

## Pendiente

Fotografías del catálogo: ver [PENDIENTE_FOTOS.md](PENDIENTE_FOTOS.md). Hoy cada
producto muestra un marcador con su inicial, y el sitio funciona completo sin
imágenes.
