/* Doble de prueba del cliente SQL de Neon.
   Registra las consultas para poder afirmar sobre ellas sin base de datos.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

export function sqlFalso(datos = {}) {
	const llamadas = [];
	const responder = (texto) => {
		if (texto.includes('FROM stores')) return datos.tiendas ?? [];
		if (texto.includes('FROM categories')) return datos.categorias ?? [];
		if (texto.includes('FROM product_presentations')) return datos.presentaciones ?? [];
		if (texto.includes('FROM products')) return datos.productos ?? [];
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
