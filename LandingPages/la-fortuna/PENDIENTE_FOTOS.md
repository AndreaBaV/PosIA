# Pendiente — Fotografías del catálogo y almacenamiento

**Estado:** pendiente de decisión. La tienda en línea **funciona completa sin
fotos**: cada producto muestra un marcador con su inicial y el color de la
marca. Este documento deja resuelto el *cómo*, para ejecutarlo cuando haya
fotos.

**Autor:** Equipo POSIA · **Matrícula:** POSIA-2026-001
**Fecha creación:** 2026-07-29

---

## 1. Dónde NO guardarlas

| Opción | Por qué no |
|--------|-----------|
| En Neon (columna `bytea`) | Postgres cobra caro por GB, infla backups y cada consulta del catálogo pagaría el peso de las imágenes. |
| En el repositorio Git | Miles de binarios hacen el clon y el CI lentísimos; Git no borra historial de blobs. |
| Dentro del contenedor del hub | El sistema de archivos del contenedor es efímero: cada redespliegue borra lo subido. |
| En `public/` de la tienda | Cada foto entraría al repositorio y al despliegue; con miles de productos, el build se vuelve inmanejable. |

## 2. Recomendación: almacenamiento de objetos + CDN

**Cloudflare R2**, que además queda en la misma cuenta donde ya vive la tienda:

- 10 GB gratis al mes y ~USD 0.015 por GB adicional.
- **Salida de datos gratuita** (sin cargo por tráfico), que es justo lo que
  consume una tienda con visitas. En S3 el egreso es el costo que se dispara.
- Bucket público con dominio propio (`fotos.lafortuna.mx`) y caché global.

Alternativas válidas: Backblaze B2 (barato, egreso limitado gratis), Supabase
Storage (cómodo si algún día se usa Supabase), Cloudinary (redimensiona solo,
pero su capa gratuita se agota con catálogos grandes).

### Cuánto espacio hace falta

Con WebP de 800×600 (~70 KB) más miniatura de 400 px (~25 KB):

| Productos con foto | Espacio |
|--------------------|---------|
| 500 | ~48 MB |
| 3 000 | ~285 MB |
| 10 000 | ~950 MB |

Es decir: **el catálogo completo cabe de sobra en la capa gratuita**. El costo
real del pendiente no es el almacenamiento, es tomar las fotos.

## 3. Cómo se conectaría con lo que ya existe

La tabla `products` **ya tiene la columna `ruta_imagen`** (hoy vacía en la
mayoría de los registros) y ya se sincroniza al POS en el evento
`productUpserted`. No hace falta migración.

Convención propuesta:

```
ruta_imagen = "productos/<codigo_barras>.webp"     # o <id>.webp si no hay código
URL pública = ${IMAGENES_BASE_URL}/${ruta_imagen}
```

Trabajo de implementación (estimado: media jornada):

1. Variable `IMAGENES_BASE_URL` en el proyecto de Cloudflare Pages.
2. `lib/catalogo.js` devuelve `imagen` cuando `ruta_imagen` no está vacía
   (concatenando la base); ya se selecciona la fila completa del producto.
3. `public/app.js`: si `producto.imagen` existe, pintar `<img loading="lazy"
   decoding="async" width height>`; si no, dejar el marcador actual. El
   `aspect-ratio` de `.producto__imagen` ya reserva el espacio, así que no
   habrá saltos de maquetación.
4. Script `server/sync_api/bin/importar_fotos.dart` (mismo patrón que
   `heal_neon.dart`: *dry-run* por defecto, `--apply` para escribir) que
   recorre una carpeta local, sube a R2 y emite `productUpserted` con la
   `ruta_imagen` nueva — así la foto también viaja a las cajas.

Importante: la `ruta_imagen` debe viajar en un **evento**, no en un `UPDATE`
directo a Neon; si no, el POS local nunca se entera.

## 4. Cómo tomar las fotos sin morir en el intento

Con muchísimos productos, fotografiar todo de una vez es inviable. Plan por
prioridad:

1. **Los que más se venden primero.** El 80 % de las ventas suele concentrarse
   en unos cientos de claves. La consulta sale de datos que ya están en Neon:

   ```sql
   SELECT sl.producto_id, sl.nombre_producto, SUM(sl.cantidad) AS piezas
   FROM sale_lines sl
   JOIN sales s ON s.id = sl.venta_id
   WHERE s.creada_en > now() - interval '90 days'
   GROUP BY 1, 2
   ORDER BY piezas DESC
   LIMIT 300;
   ```

2. **Estación fija**: mesa con fondo blanco, luz de ventana, teléfono en
   tripié. Se fotografía en tandas mientras se acomoda mercancía.
3. **Nombrar escaneando**: escanear el código de barras con la caja y usar ese
   número como nombre del archivo evita el trabajo de emparejar después.
4. **Nunca tomar fotos de Google.** Son de terceros y exponen a un reclamo de
   derechos. Sirven las propias o las que el proveedor entrega para difusión.
5. Convertir a WebP en lote antes de subir (`cwebp -q 80 -resize 800 0`).

## 5. Decisiones que faltan

- [ ] Proveedor de almacenamiento (recomendado: Cloudflare R2).
- [ ] Dominio para las imágenes y para la tienda en línea.
- [ ] Quién toma las fotos y en qué tandas.
- [ ] Si la caja debe permitir tomar la foto desde el celular al dar de alta un
      producto (evita el trabajo retroactivo para todo lo nuevo).
