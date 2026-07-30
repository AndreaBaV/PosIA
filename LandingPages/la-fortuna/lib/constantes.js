/* Constantes de la tienda en linea. Espejo de packages/posia_core/lib/src/
   constants/posia_constants.dart — mantener ambos lados en sincronia.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

/** Nombre comercial por defecto. */
export const NOMBRE_TIENDA = 'La Fortuna';

/** WhatsApp de la tienda en formato wa.me (52 + 10 digitos). */
export const WHATSAPP_PREDETERMINADO = '527226527751';

/** Maximo de partidas aceptadas en un pedido web. */
export const LIMITE_LINEAS_PEDIDO = 100;

/** Maxima cantidad por partida. */
export const LIMITE_CANTIDAD_LINEA = 9999;

/** Productos por pagina en el catalogo publico. */
export const LIMITE_PAGINA_CATALOGO = 60;

/** Formas de pago ofrecidas en linea (sin credito, sin cobro en el sitio). */
export const METODOS_PAGO = new Set(['efectivo', 'transferencia']);

/**
 * Dispositivo con el que se firman los eventos del canal web.
 *
 * No es ninguna caja, asi que todas reciben el pedido en su pull (que solo
 * excluye los eventos propios).
 */
export const DISPOSITIVO_WEB = 'tienda-web';

/** Segundos de cache en el borde para las lecturas del catalogo. */
export const CACHE_CATALOGO_SEGUNDOS = 300;

/** Segundos de cache para los datos de la tienda (cambian casi nunca). */
export const CACHE_TIENDA_SEGUNDOS = 3600;
