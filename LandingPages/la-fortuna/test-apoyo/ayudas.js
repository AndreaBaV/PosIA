/* Doble de prueba del cliente SQL de Neon.
   Registra las consultas para poder afirmar sobre ellas sin base de datos.

   Vive fuera de test/ porque `node --test` trata TODO archivo .js dentro de un
   directorio llamado test como archivo de pruebas, y este solo exporta ayudas:
   aparecia en el reporte como una suite vacia mas.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

export function sqlFalso(datos = {}) {
	const llamadas = [];
	const responder = (texto) => {
		if (texto.includes('FROM stores')) return datos.tiendas ?? [];
		if (texto.includes('FROM categories')) {
			// `consultarCategorias` publica la lista pintando el chip;
			// `categoriasPorTokens` —el fallback de sugerencias sin
			// resultados directos— hace un SELECT DISTINCT c.id sin COUNT.
			if (texto.includes('COUNT(')) {
				return datos.categorias ?? [];
			}
			return datos.categoriasSugerencia ?? [];
		}
		if (texto.includes('FROM product_presentations')) return datos.presentaciones ?? [];
		if (texto.includes('FROM wholesale_tiers')) return datos.escalas ?? [];
		if (texto.includes('FROM products')) {
			// La consulta de sugerencias es la unica que filtra por
			// `p.categoria_id = ANY($2)` (mientras que `opciones.ids` filtra
			// por `p.id = ANY(...)` y el filtro normal de categoria usa
			// `= $N`). Con eso el mock decide sin depender del orden en que
			// se llamo, para no romper `crearPedido` que tambien pega en
			// products dos veces (validacion + registro).
			if (texto.includes('p.categoria_id = ANY(')) {
				return datos.sugerencias ?? [];
			}
			return datos.productos ?? [];
		}
		if (texto.includes('FROM order_lines')) return datos.lineasPedido ?? [];
		if (texto.includes('FROM orders')) return datos.pedidos ?? [];
		return [];
	};
	const sql = {
		llamadas,
		query(texto, parametros = []) {
			llamadas.push({ texto, parametros });
			return Promise.resolve(responder(texto));
		},
		transaction(consultas) {
			llamadas.push({ texto: 'TRANSACTION', parametros: [consultas.length] });
			return Promise.all(consultas);
		},
	};
	return sql;
}

/** Consultas registradas que contienen [fragmento]. */
export function consultasCon(sql, fragmento) {
	return sql.llamadas.filter((llamada) => llamada.texto.includes(fragmento));
}
