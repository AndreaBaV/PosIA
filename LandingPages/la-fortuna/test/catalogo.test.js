/* Pruebas del catalogo publico: filtros, paginacion y lo que NO se publica.

   Autor: Equipo POSIA · Matricula: POSIA-2026-001 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
	consultarCatalogo,
	consultarCategorias,
	escaparLike,
	normalizarBusqueda,
} from '../lib/catalogo.js';
import { redondearMonto } from '../lib/dinero.js';
import { consultasCon, sqlFalso } from '../test-apoyo/ayudas.js';

const TIENDA = 'tienda-1';

function producto(id, nombre, precio = 10, extra = {}) {
	return {
		id,
		nombre,
		precio_base: precio,
		unidad_medida: 'pieza',
		categoria_id: 'cat-1',
		notas: '',
		categoria_nombre: 'Abarrotes',
		ruta_imagen: '',
		...extra,
	};
}

test('el catálogo nunca consulta ni publica existencias', async () => {
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	const datos = await consultarCatalogo(sql, TIENDA);

	for (const llamada of sql.llamadas) {
		assert.ok(!/stock_levels|warehouse_stock/i.test(llamada.texto),
			'no debe tocarse ninguna tabla de inventario');
	}
	assert.deepEqual(Object.keys(datos.productos[0]).sort(), [
		'categoria', 'categoriaId', 'descripcion', 'escalas', 'id', 'imagenUrl',
		'nombre', 'precio', 'presentaciones', 'unidad',
	]);
});

test('el catálogo expone la imagen del producto cuando existe, o null si no', async () => {
	const conImagen = producto('p1', 'Frijol');
	conImagen.ruta_imagen = 'https://pub-test.r2.dev/productos/p1-123.jpg';
	const sinImagen = producto('p2', 'Arroz');
	sinImagen.ruta_imagen = '';

	const sql = sqlFalso({ productos: [conImagen, sinImagen] });
	const datos = await consultarCatalogo(sql, TIENDA);

	const [frijol, arroz] = datos.productos;
	assert.equal(frijol.imagenUrl, 'https://pub-test.r2.dev/productos/p1-123.jpg');
	assert.equal(arroz.imagenUrl, null);
});

test('el catálogo trae las escalas de precio por cantidad', async () => {
	const sql = sqlFalso({
		productos: [producto('carne', 'Bistec')],
		escalas: [
			{ producto_id: 'carne', cantidad_minima: 0.5, precio_unitario: 40 },
			{ producto_id: 'carne', cantidad_minima: 1, precio_unitario: 30 },
		],
	});
	const datos = await consultarCatalogo(sql, TIENDA);
	assert.equal(datos.productos[0].escalas.length, 2);
	assert.equal(datos.productos[0].escalas[0].cantidadMinima, 0.5);
	assert.equal(datos.productos[0].escalas[0].precioUnitario, 40);
	assert.ok(
		consultasCon(sql, 'FROM wholesale_tiers').length >= 1,
		'debe leer wholesale_tiers para respetar medio/cuarto kilo',
	);
});

test('opciones.ids filtra por producto sin paginar, para refrescar un carrito guardado', async () => {
	const sql = sqlFalso({
		productos: [producto('carne', 'Bistec'), producto('pollo', 'Pechuga')],
	});
	const datos = await consultarCatalogo(sql, TIENDA, { ids: ['carne', 'pollo'] });

	const consulta = sql.llamadas.find((l) => l.texto.includes('FROM products'));
	assert.ok(consulta.texto.includes('p.id = ANY('),
		'debe filtrar por id cuando se piden ids especificos');
	assert.deepEqual(consulta.parametros[1], ['carne', 'pollo']);
	// Sin paginar: no debe faltar ningun producto de la lista pedida por
	// culpa del LIMIT normal de la vitrina.
	assert.equal(datos.hayMas, false);
	assert.equal(datos.productos.length, 2);
});

test('opciones.ids ignorado si viene vacio: se comporta como el catalogo normal', async () => {
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	await consultarCatalogo(sql, TIENDA, { ids: [] });

	const consulta = sql.llamadas.find((l) => l.texto.includes('FROM products'));
	assert.ok(!consulta.texto.includes('p.id = ANY('),
		'una lista vacia no debe agregar el filtro por id');
});

test('solo salen productos activos y con precio, de cualquier sucursal', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA);
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('p.activo = 1'));
	assert.ok(consulta.texto.includes('p.precio_base > 0'));
	assert.ok(
		!/AND p\.tienda_id = \$\d+/.test(consulta.texto),
		'el catálogo es unificado: la sucursal no filtra (solo desempata)',
	);
	assert.ok(
		consulta.texto.includes('JOIN stores s ON s.id = p.tienda_id AND s.activa = 1'),
		'pero sí se excluyen las sucursales dadas de baja',
	);
});

test('un producto repetido en varias sucursales sale una sola vez', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA);
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('DISTINCT ON (lower(btrim(p.nombre)))'));
	assert.ok(
		consulta.texto.includes('(p.tienda_id = $1) DESC, p.precio_base ASC'),
		'gana la ficha de la tienda principal y, si no está, la más barata',
	);
	assert.equal(consulta.parametros[0], TIENDA);
});

test('la búsqueda numera sus parámetros junto al filtro de categoría', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { q: 'frijol', categoria: 'cat-9', limite: 20, desde: 40 });
	const consulta = consultasCon(sql, 'FROM products')[0];
	// El texto buscable es nombre + notas + categoria normalizados sin acentos.
	assert.ok(
		consulta.texto.includes('translate(') && consulta.texto.includes('LIKE $2'),
		'debe pasar el token contra el texto normalizado',
	);
	assert.ok(consulta.texto.includes('p.codigo_barras = $3'),
		'el codigo de barras exacto sigue siendo un atajo de la busqueda');
	assert.ok(consulta.texto.includes('p.categoria_id = $4'));
	assert.ok(consulta.texto.includes('LIMIT $5 OFFSET $6'));
	assert.deepEqual(consulta.parametros, [TIENDA, '%frijol%', 'frijol', 'cat-9', 21, 40]);
});

test('la búsqueda encuentra "arándano" cuando el usuario escribe "arandano"', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { q: 'arandano' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	// El comparador SQL debe normalizar el texto en la columna (translate)
	// y el parametro debe llegar en minusculas sin acentos: si el usuario
	// buscaba con o sin tilde, "arándano" y "arandano" caen en el mismo
	// LIKE y el producto aparece.
	assert.ok(consulta.texto.includes('translate('),
		'la columna debe pasar por translate() para ignorar acentos');
	assert.ok(consulta.texto.includes("'áàäâéèëêíìïîóòöôúùüûñ'"),
		'debe listar los acentos que se mapean a su letra base');
	assert.equal(consulta.parametros[1], '%arandano%');
});

test('la búsqueda entra normalizada aunque el usuario ponga MAYÚSCULAS y acentos', () => {
	assert.equal(normalizarBusqueda('Arándano'), 'arandano');
	assert.equal(normalizarBusqueda('MAÑANA'), 'manana');
	assert.equal(normalizarBusqueda(' Frü tas '), ' fru tas ');
});

test('la búsqueda es multi-token: "arroz saman" pide los dos, en cualquier orden', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { q: 'arroz saman' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	// Cada token es una clausula LIKE aparte unidas por AND: "Saman 5kg
	// arroz blanco" y "Arroz Saman 1kg" matchean, "Arroz" solo no.
	const conteoLikes = (consulta.texto.match(/LIKE \$/g) || []).length;
	assert.equal(conteoLikes, 2, 'un LIKE por token');
	assert.ok(consulta.texto.includes(' AND '),
		'los tokens de la busqueda se combinan con AND');
	assert.deepEqual(consulta.parametros.slice(1, 4), ['%arroz%', '%saman%', 'arroz saman']);
});

test('tokens repetidos no duplican clausulas: "arroz arroz" es una sola', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { q: 'arroz arroz' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	const conteoLikes = (consulta.texto.match(/LIKE \$/g) || []).length;
	assert.equal(conteoLikes, 1, 'sin repetidos');
});

test('los comodines de la consulta no vuelven ruidosa la busqueda', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { q: '50%_frijol' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	// El % y el _ del usuario se escapan, ya no arman un comodin real.
	assert.equal(consulta.parametros[1], '%50\\%\\_frijol%');
});

test('precio_min y precio_max recortan por debajo y por arriba', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { precioMin: '20', precioMax: '80' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('p.precio_base >= $'));
	assert.ok(consulta.texto.includes('p.precio_base <= $'));
	assert.ok(consulta.parametros.includes(20));
	assert.ok(consulta.parametros.includes(80));
});

test('precio_min <= 0 o no numerico se ignora, no rompe la consulta', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { precioMin: '-3', precioMax: 'abc' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(!consulta.texto.includes('p.precio_base >='),
		'sin filtro cuando el valor es negativo o vacio');
	assert.ok(!consulta.texto.includes('p.precio_base <='),
		'sin filtro cuando el valor no es numerico');
});

test('orden=precio_asc ordena por precio ascendente en el wrapper externo', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { orden: 'precio_asc' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('ORDER BY unicos.precio_base ASC'));
});

test('orden=precio_desc ordena de mas caro a mas barato', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { orden: 'precio_desc' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('ORDER BY unicos.precio_base DESC'));
});

test('orden desconocido cae al alfabético, no se cuela un ORDER BY inyectado', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { orden: '; DROP TABLE products; --' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes('ORDER BY unicos.nombre ASC'));
	assert.ok(!/DROP TABLE/i.test(consulta.texto));
});

test('la búsqueda con resultados devuelve sugerencias de la misma categoría', async () => {
	const arandanos = producto('p-arandano', 'Arándano deshidratado', 120, {
		categoria_id: 'cat-frutos', categoria_nombre: 'Frutos secos',
	});
	const almendras = producto('p-almendra', 'Almendra fileteada', 180, {
		categoria_id: 'cat-frutos', categoria_nombre: 'Frutos secos',
		ruta_imagen: 'https://pub/almendra.jpg',
	});
	const sql = sqlFalso({
		productos: [arandanos],
		sugerencias: [almendras],
	});

	const datos = await consultarCatalogo(sql, TIENDA, { q: 'arandano' });

	assert.equal(datos.productos.length, 1);
	assert.equal(datos.productos[0].nombre, 'Arándano deshidratado');
	assert.equal(datos.sugerencias.length, 1);
	assert.equal(datos.sugerencias[0].nombre, 'Almendra fileteada');

	// La consulta de sugerencias debe filtrar por categoria_id y excluir
	// los productos ya devueltos como resultados directos.
	const consultasProductos = consultasCon(sql, 'FROM products');
	assert.equal(consultasProductos.length, 2, 'principal + sugerencias');
	const sugerencia = consultasProductos[1];
	assert.ok(sugerencia.texto.includes('p.categoria_id = ANY('));
	assert.ok(sugerencia.texto.includes('p.id <> ALL('),
		'las sugerencias no repiten lo que ya salio arriba');
	// Un mismo producto en dos sucursales (misma normalizacion de nombre,
	// distinto id) no debe colarse en sugerencias solo porque el filtro
	// por id no cubre a la otra fila.
	assert.ok(sugerencia.texto.includes('lower(btrim(p.nombre)) <> ALL('),
		'excluir tambien por nombre normalizado evita repetir el mismo articulo');
	// Comparte el criterio "primero con foto, luego mas barato" para que la
	// franja "podria interesarte" no arranque con articulos sin imagen.
	assert.ok(sugerencia.texto.includes('ruta_imagen IS NOT NULL'));
});

test('sin resultados directos, las sugerencias vienen de categorías que matchean el nombre', async () => {
	// El usuario escribe algo que no existe en products; la vitrina no
	// puede dejarlo con las manos vacias, asi que le muestra productos de
	// una categoria cuyo nombre matchea con la busqueda ("carne" cae en la
	// categoria Carnes aunque no exista "ablandador de carne" como fila).
	const mayonesa = producto('p-mayo', 'Mayonesa McCormick', 65, {
		categoria_id: 'cat-condim', categoria_nombre: 'Condimentos',
	});
	const sql = sqlFalso({
		productos: [],
		categoriasSugerencia: [{ id: 'cat-condim' }],
		sugerencias: [mayonesa],
	});

	const datos = await consultarCatalogo(sql, TIENDA, { q: 'ablandador de carne' });

	assert.equal(datos.productos.length, 0);
	assert.equal(datos.sugerencias.length, 1);
	assert.equal(datos.sugerencias[0].nombre, 'Mayonesa McCormick');

	// El fallback consulta categorias por token —sin COUNT, para que el mock
	// lo diferencie de la lista publica— y luego pide productos de esas ids.
	const consultaCategorias = consultasCon(sql, 'FROM categories')
		.filter((c) => !c.texto.includes('COUNT('));
	assert.equal(consultaCategorias.length, 1);
	assert.ok(consultaCategorias[0].texto.includes('translate(lower(c.nombre)'),
		'el fallback busca en el nombre de la categoria sin acentos');
});

test('sin búsqueda de texto no se calculan sugerencias', async () => {
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	const datos = await consultarCatalogo(sql, TIENDA);

	const consultasProductos = consultasCon(sql, 'FROM products');
	assert.equal(consultasProductos.length, 1,
		'sin busqueda no tiene sentido gastar en sugerencias');
	assert.deepEqual(datos.sugerencias, []);
});

test('si el usuario ya filtró por una categoría, las sugerencias no repiten "más de lo mismo"', async () => {
	// Dentro de la vitrina de una sola categoria, sugerir otros productos
	// de esa MISMA categoria es ruido: ya los esta viendo. Se apaga.
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	const datos = await consultarCatalogo(sql, TIENDA, { q: 'frijol', categoria: 'cat-9' });
	assert.deepEqual(datos.sugerencias, []);
	assert.equal(consultasCon(sql, 'FROM products').length, 1);
});

test('la paginación (`desde > 0`) tampoco calcula sugerencias', async () => {
	// Las sugerencias son para la primera vista de resultados; al bajar
	// con "Ver más productos" ya no tienen contexto util.
	const sql = sqlFalso({ productos: [producto('p1', 'Frijol')] });
	await consultarCatalogo(sql, TIENDA, { q: 'frijol', desde: 60 });
	assert.equal(consultasCon(sql, 'FROM products').length, 1);
});

test('la categoría "sin-categoria" agrupa los productos sueltos', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { categoria: 'sin-categoria' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.ok(consulta.texto.includes("p.categoria_id IS NULL OR p.categoria_id = ''"));
	assert.equal(consulta.parametros.length, 3, 'sin parámetro de categoría');
});

test('hayMas se decide con un producto extra, no con COUNT', async () => {
	const cinco = ['a', 'b', 'c', 'd', 'e'].map((id) => producto(id, id));
	const sql = sqlFalso({ productos: cinco });
	const datos = await consultarCatalogo(sql, TIENDA, { limite: 4 });
	assert.equal(datos.productos.length, 4);
	assert.equal(datos.hayMas, true);
	assert.equal(datos.siguiente, 4);

	const sinExtra = sqlFalso({ productos: cinco.slice(0, 3) });
	const ultima = await consultarCatalogo(sinExtra, TIENDA, { limite: 4, desde: 8 });
	assert.equal(ultima.hayMas, false);
	assert.equal(ultima.siguiente, 11);
});

test('el límite por página no se puede inflar desde la URL', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA, { limite: '5000', desde: '-3' });
	const consulta = consultasCon(sql, 'FROM products')[0];
	assert.equal(consulta.parametros.at(-2), 61, 'tope de 60 productos + 1 de sondeo');
	assert.equal(consulta.parametros.at(-1), 0, 'sin desplazamientos negativos');
});

test('cada producto trae sus presentaciones con precio propio', async () => {
	const sql = sqlFalso({
		productos: [producto('p1', 'Frijol', 38.5)],
		presentaciones: [
			{ id: 'pr1', producto_id: 'p1', nombre: 'Bulto 25 kg', precio: 890, factor_a_base: 25 },
		],
	});
	const datos = await consultarCatalogo(sql, TIENDA);
	assert.deepEqual(datos.productos[0].presentaciones, [
		{ id: 'pr1', nombre: 'Bulto 25 kg', precio: 890, factor: 25 },
	]);

	const consulta = consultasCon(sql, 'FROM product_presentations')[0];
	assert.ok(consulta.texto.includes('precio IS NOT NULL'));
	assert.ok(consulta.texto.includes('es_presentacion_base = 0'));
});

test('sin productos no se consultan presentaciones', async () => {
	const sql = sqlFalso({ productos: [] });
	await consultarCatalogo(sql, TIENDA);
	assert.equal(consultasCon(sql, 'FROM product_presentations').length, 0);
});

test('las categorías vacías no se listan', async () => {
	const sql = sqlFalso({ categorias: [{ id: 'cat-1', nombre: 'Abarrotes', total: 12 }] });
	const datos = await consultarCategorias(sql);
	assert.deepEqual(datos.categorias, [{ id: 'cat-1', nombre: 'Abarrotes', total: 12 }]);
	const consulta = consultasCon(sql, 'FROM categories')[0];
	assert.ok(consulta.texto.includes('HAVING COUNT(p.id) > 0'));
	assert.ok(consulta.texto.includes('c.activa = 1'));
	assert.ok(
		consulta.texto.includes('COUNT(DISTINCT lower(btrim(p.nombre)))'),
		'el total no debe inflarse con el mismo producto de varias sucursales',
	);
});

test('los comodines de LIKE se escapan', () => {
	assert.equal(escaparLike('100%_algo'), '100\\%\\_algo');
});

test('los precios se redondean como en el POS', () => {
	assert.equal(redondearMonto(38.505), 38.51);
	assert.equal(redondearMonto(0.1 + 0.2), 0.3);
	assert.equal(redondearMonto(165 * 1.5), 247.5);
});
