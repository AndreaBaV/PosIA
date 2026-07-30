/* Tienda en linea La Fortuna — catalogo, carrito, pedido y seguimiento.
   Autor: Equipo POSIA · Matricula: POSIA-2026-001
   Sin framework ni build: se sirve tal cual desde el hub. */

(function () {
	'use strict';

	// El sitio vive junto al hub, asi que el origen relativo basta. Para
	// desarrollo local contra un hub remoto: index.html?api=https://mi-hub
	var API = (new URLSearchParams(location.search).get('api') ||
		window.POSIA_API_BASE || '').replace(/\/$/, '');

	var CLAVE_CARRITO = 'lafortuna.carrito.v1';
	var CLAVE_FOLIOS = 'lafortuna.folios.v1';
	var POR_PAGINA = 60;

	var dinero = new Intl.NumberFormat('es-MX', {
		style: 'currency', currency: 'MXN'
	});

	var estado = {
		tienda: { nombre: 'La Fortuna', whatsapp: '', direccion: '' },
		carrito: leerJson(CLAVE_CARRITO, []),
		categoria: '',
		busqueda: '',
		desde: 0,
		hayMas: false,
		peticion: 0,
		ultimoPedido: null
	};

	var $ = function (sel, raiz) { return (raiz || document).querySelector(sel); };
	var $$ = function (sel, raiz) {
		return Array.prototype.slice.call((raiz || document).querySelectorAll(sel));
	};

	// --- Utilidades ---------------------------------------------------------

	function leerJson(clave, respaldo) {
		try {
			var crudo = localStorage.getItem(clave);
			return crudo ? JSON.parse(crudo) : respaldo;
		} catch (e) {
			return respaldo;
		}
	}

	function guardarJson(clave, valor) {
		try {
			localStorage.setItem(clave, JSON.stringify(valor));
		} catch (e) { /* modo privado: el carrito solo vive en memoria */ }
	}

	function elemento(etiqueta, clase, texto) {
		var nodo = document.createElement(etiqueta);
		if (clase) { nodo.className = clase; }
		if (texto !== undefined && texto !== null) { nodo.textContent = String(texto); }
		return nodo;
	}

	function brindis(mensaje) {
		var caja = $('[data-brindis]');
		caja.textContent = mensaje;
		caja.hidden = false;
		clearTimeout(brindis._t);
		brindis._t = setTimeout(function () { caja.hidden = true; }, 2600);
	}

	function pedir(ruta, opciones) {
		return fetch(API + ruta, opciones).then(function (respuesta) {
			return respuesta.json().catch(function () { return {}; }).then(function (cuerpo) {
				if (!respuesta.ok) {
					throw new Error(cuerpo.error || 'No pudimos conectar con la tienda');
				}
				return cuerpo;
			});
		});
	}

	function cantidadTexto(valor) {
		return Number.isInteger(valor) ? String(valor) : String(Math.round(valor * 1000) / 1000);
	}

	function esGranel(unidad) {
		return /kilo|gramo|litro|metro/i.test(unidad || '');
	}

	// --- Tienda -------------------------------------------------------------

	function cargarTienda() {
		return pedir('/v1/public/tienda').then(function (datos) {
			estado.tienda = datos;
			$$('[data-tienda-nombre]').forEach(function (n) { n.textContent = datos.nombre; });
			var direccion = $('[data-tienda-direccion]');
			if (direccion && datos.direccion) { direccion.textContent = '· ' + datos.direccion; }
			var wa = $('[data-tienda-whatsapp]');
			if (wa && datos.whatsapp) { wa.href = 'https://wa.me/' + datos.whatsapp; }
			document.title = datos.nombre + ' — Tienda en línea';
		}).catch(function () { /* la portada sigue siendo usable */ });
	}

	// --- Catalogo -----------------------------------------------------------

	function cargarCategorias() {
		return pedir('/v1/public/categorias').then(function (datos) {
			var caja = $('[data-categorias]');
			caja.textContent = '';
			caja.appendChild(chipCategoria('', 'Todo'));
			(datos.categorias || []).forEach(function (categoria) {
				caja.appendChild(chipCategoria(categoria.id, categoria.nombre));
			});
		}).catch(function () { /* sin chips, la busqueda sigue funcionando */ });
	}

	function chipCategoria(id, nombre) {
		var chip = elemento('button', 'chip', nombre);
		chip.type = 'button';
		chip.setAttribute('aria-pressed', String(estado.categoria === id));
		chip.addEventListener('click', function () {
			estado.categoria = id;
			$$('.chip').forEach(function (otro) { otro.setAttribute('aria-pressed', 'false'); });
			chip.setAttribute('aria-pressed', 'true');
			reiniciarCatalogo();
		});
		return chip;
	}

	function reiniciarCatalogo() {
		estado.desde = 0;
		$('[data-rejilla]').textContent = '';
		cargarProductos();
	}

	function cargarProductos() {
		// Token de peticion: al cambiar de filtro o busqueda mientras una
		// consulta esta en vuelo, la respuesta vieja se descarta en vez de
		// pisar la rejilla (o de bloquear la nueva consulta).
		var token = ++estado.peticion;
		var aviso = $('[data-catalogo-estado]');
		var rejilla = $('[data-rejilla]');
		var boton = $('[data-cargar-mas]');
		boton.hidden = true;
		boton.disabled = true;
		aviso.hidden = true;
		aviso.className = 'aviso';

		if (estado.desde === 0) {
			for (var i = 0; i < 8; i++) { rejilla.appendChild(elemento('div', 'esqueleto')); }
		}

		var parametros = new URLSearchParams({
			limite: String(POR_PAGINA),
			desde: String(estado.desde)
		});
		if (estado.busqueda) { parametros.set('q', estado.busqueda); }
		if (estado.categoria) { parametros.set('categoria', estado.categoria); }

		pedir('/v1/public/catalogo?' + parametros.toString()).then(function (datos) {
			if (token !== estado.peticion) { return; }
			$$('.esqueleto', rejilla).forEach(function (n) { n.remove(); });
			(datos.productos || []).forEach(function (producto) {
				rejilla.appendChild(tarjetaProducto(producto));
			});
			estado.desde = datos.siguiente;
			estado.hayMas = !!datos.hayMas;
			boton.hidden = !estado.hayMas;
			if (!rejilla.children.length) {
				aviso.textContent = estado.busqueda
					? 'No encontramos "' + estado.busqueda + '". Prueba con otro nombre.'
					: 'Aún no hay productos publicados en esta categoría.';
				aviso.hidden = false;
			}
		}).catch(function (error) {
			if (token !== estado.peticion) { return; }
			$$('.esqueleto', rejilla).forEach(function (n) { n.remove(); });
			aviso.textContent = error.message;
			aviso.className = 'aviso aviso--error';
			aviso.hidden = false;
		}).then(function () {
			if (token === estado.peticion) { boton.disabled = false; }
		});
	}

	function tarjetaProducto(producto) {
		var tarjeta = elemento('article', 'producto');

		// Marcador con la inicial mientras el catalogo no tenga fotografias.
		var imagen = elemento('div', 'producto__imagen', (producto.nombre || '?').charAt(0).toUpperCase());
		imagen.setAttribute('aria-hidden', 'true');
		tarjeta.appendChild(imagen);

		var cuerpo = elemento('div', 'producto__cuerpo');
		cuerpo.appendChild(elemento('h3', 'producto__nombre', producto.nombre));

		var precioNodo = elemento('div', 'producto__precio', dinero.format(producto.precio));
		var metaNodo = elemento('div', 'producto__meta', 'por ' + (producto.unidad || 'pieza'));
		cuerpo.appendChild(precioNodo);
		cuerpo.appendChild(metaNodo);

		var presentaciones = producto.presentaciones || [];
		var selector = null;
		if (presentaciones.length) {
			selector = elemento('select');
			selector.setAttribute('aria-label', 'Presentación de ' + producto.nombre);
			var base = elemento('option', null, 'Por ' + (producto.unidad || 'pieza') +
				' · ' + dinero.format(producto.precio));
			base.value = '';
			selector.appendChild(base);
			presentaciones.forEach(function (presentacion) {
				var opcion = elemento('option', null,
					presentacion.nombre + ' · ' + dinero.format(presentacion.precio));
				opcion.value = presentacion.id;
				selector.appendChild(opcion);
			});
			cuerpo.appendChild(selector);
		}

		// El granel solo aplica a la unidad base: un bulto o una caja se piden
		// enteros aunque el producto se venda por kilo.
		function pasoActual() {
			var elegida = selector ? presentacionDe(producto, selector.value) : null;
			return !elegida && esGranel(producto.unidad) ? 0.25 : 1;
		}

		var contenedorCantidad = elemento('div', 'cantidad');
		var menos = elemento('button', null, '−');
		menos.type = 'button';
		menos.setAttribute('aria-label', 'Quitar');
		var campo = elemento('input');
		campo.type = 'number';
		campo.value = '1';
		campo.setAttribute('aria-label', 'Cantidad de ' + producto.nombre);
		var mas = elemento('button', null, '+');
		mas.type = 'button';
		mas.setAttribute('aria-label', 'Agregar');
		menos.addEventListener('click', function () {
			var paso = pasoActual();
			campo.value = cantidadTexto(Math.max(paso, (parseFloat(campo.value) || paso) - paso));
		});
		mas.addEventListener('click', function () {
			var paso = pasoActual();
			campo.value = cantidadTexto((parseFloat(campo.value) || 0) + paso);
		});
		contenedorCantidad.appendChild(menos);
		contenedorCantidad.appendChild(campo);
		contenedorCantidad.appendChild(mas);
		cuerpo.appendChild(contenedorCantidad);

		// Precio, unidad y paso de la cantidad siguen a la presentacion elegida.
		function sincronizarUnidad() {
			var elegida = selector ? presentacionDe(producto, selector.value) : null;
			var paso = pasoActual();
			campo.min = String(paso);
			campo.step = String(paso);
			var actual = parseFloat(campo.value) || paso;
			campo.value = cantidadTexto(Math.max(paso, Math.round(actual / paso) * paso));
			precioNodo.textContent = dinero.format(elegida ? elegida.precio : producto.precio);
			metaNodo.textContent = 'por ' + (elegida ? elegida.nombre : (producto.unidad || 'pieza'));
		}
		if (selector) { selector.addEventListener('change', sincronizarUnidad); }
		sincronizarUnidad();

		var agregar = elemento('button', 'boton boton--primario producto__agregar', 'Agregar');
		agregar.type = 'button';
		agregar.addEventListener('click', function () {
			var cantidad = parseFloat(campo.value);
			if (!(cantidad > 0)) { campo.focus(); return; }
			agregarAlCarrito(producto, selector ? selector.value : '', cantidad);
			campo.value = cantidadTexto(pasoActual());
		});
		cuerpo.appendChild(agregar);

		tarjeta.appendChild(cuerpo);
		return tarjeta;
	}

	function presentacionDe(producto, id) {
		if (!id) { return null; }
		var lista = producto.presentaciones || [];
		for (var i = 0; i < lista.length; i++) {
			if (lista[i].id === id) { return lista[i]; }
		}
		return null;
	}

	// --- Carrito ------------------------------------------------------------

	function agregarAlCarrito(producto, presentacionId, cantidad) {
		var presentacion = presentacionDe(producto, presentacionId);
		var clave = producto.id + '|' + (presentacionId || '');
		var existente = null;
		estado.carrito.forEach(function (linea) {
			if (linea.clave === clave) { existente = linea; }
		});
		if (existente) {
			existente.cantidad = Math.round((existente.cantidad + cantidad) * 1000) / 1000;
		} else {
			estado.carrito.push({
				clave: clave,
				productoId: producto.id,
				presentacionId: presentacionId || '',
				nombre: producto.nombre + (presentacion ? ' (' + presentacion.nombre + ')' : ''),
				unidad: presentacion ? presentacion.nombre : (producto.unidad || 'pieza'),
				precio: presentacion ? presentacion.precio : producto.precio,
				granel: !presentacion && esGranel(producto.unidad),
				cantidad: cantidad
			});
		}
		persistirCarrito();
		brindis(producto.nombre + ' agregado a tu pedido');
	}

	function persistirCarrito() {
		guardarJson(CLAVE_CARRITO, estado.carrito);
		pintarCarrito();
	}

	function totalCarrito() {
		return estado.carrito.reduce(function (suma, linea) {
			return suma + linea.precio * linea.cantidad;
		}, 0);
	}

	function pintarCarrito() {
		var piezas = estado.carrito.length;
		var contador = $('[data-carrito-contador]');
		contador.textContent = String(piezas);
		contador.hidden = piezas === 0;

		var cuerpo = $('[data-carrito-cuerpo]');
		var formulario = $('[data-form-pedido]');
		cuerpo.textContent = '';

		if (!piezas) {
			formulario.hidden = true;
			var vacio = elemento('p', 'aviso', 'Tu pedido está vacío. Agrega productos del catálogo.');
			cuerpo.appendChild(vacio);
			return;
		}
		formulario.hidden = false;

		estado.carrito.forEach(function (linea) {
			var fila = elemento('div', 'linea');
			var izquierda = elemento('div');
			izquierda.appendChild(elemento('div', 'linea__nombre', linea.nombre));
			izquierda.appendChild(elemento('div', 'linea__meta',
				dinero.format(linea.precio) + ' / ' + linea.unidad));
			fila.appendChild(izquierda);
			fila.appendChild(elemento('div', 'linea__importe',
				dinero.format(linea.precio * linea.cantidad)));

			var controles = elemento('div', 'linea__controles');
			var campo = elemento('input');
			campo.type = 'number';
			campo.min = linea.granel ? '0.25' : '1';
			campo.step = linea.granel ? '0.25' : '1';
			campo.value = cantidadTexto(linea.cantidad);
			campo.setAttribute('aria-label', 'Cantidad de ' + linea.nombre);
			campo.addEventListener('change', function () {
				var nueva = parseFloat(campo.value);
				if (!(nueva > 0)) {
					quitarDelCarrito(linea.clave);
					return;
				}
				linea.cantidad = nueva;
				persistirCarrito();
			});
			controles.appendChild(campo);
			var quitar = elemento('button', 'linea__quitar', 'Quitar');
			quitar.type = 'button';
			quitar.addEventListener('click', function () { quitarDelCarrito(linea.clave); });
			controles.appendChild(quitar);
			fila.appendChild(controles);
			cuerpo.appendChild(fila);
		});

		$('[data-carrito-total]').textContent = dinero.format(totalCarrito());
	}

	function quitarDelCarrito(clave) {
		estado.carrito = estado.carrito.filter(function (linea) { return linea.clave !== clave; });
		persistirCarrito();
	}

	function abrirCarrito(abierto) {
		$('[data-carrito]').hidden = !abierto;
		$('[data-fondo]').hidden = !abierto;
		document.body.style.overflow = abierto ? 'hidden' : '';
		if (abierto) {
			var primero = $('.carrito__cuerpo input, .carrito__pie input');
			if (primero) { primero.focus(); }
		}
	}

	// --- Envio del pedido ---------------------------------------------------

	function enviarPedido(evento) {
		evento.preventDefault();
		var formulario = evento.target;
		var boton = $('[data-enviar-pedido]');
		var error = $('[data-pedido-error]');
		var datos = new FormData(formulario);
		var aDomicilio = datos.get('entrega') !== 'tienda';

		error.hidden = true;
		if (!estado.carrito.length) { return; }
		if (aDomicilio && !String(datos.get('direccion') || '').trim()) {
			error.textContent = 'Necesitamos la dirección para llevarte el pedido.';
			error.hidden = false;
			return;
		}

		boton.disabled = true;
		boton.textContent = 'Enviando…';

		pedir('/v1/public/pedidos', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				nombre: datos.get('nombre'),
				telefono: datos.get('telefono'),
				entregaADomicilio: aDomicilio,
				direccion: datos.get('direccion'),
				metodoPago: datos.get('metodoPago'),
				notas: datos.get('notas'),
				lineas: estado.carrito.map(function (linea) {
					return {
						productoId: linea.productoId,
						presentacionId: linea.presentacionId || null,
						cantidad: linea.cantidad
					};
				})
			})
		}).then(function (pedido) {
			estado.ultimoPedido = pedido;
			estado.carrito = [];
			persistirCarrito();
			formulario.reset();
			var folios = leerJson(CLAVE_FOLIOS, []);
			folios.unshift(pedido.folio);
			guardarJson(CLAVE_FOLIOS, folios.slice(0, 10));
			abrirCarrito(false);
			location.hash = '#/pedido/' + pedido.folio;
		}).catch(function (fallo) {
			error.textContent = fallo.message;
			error.hidden = false;
		}).then(function () {
			boton.disabled = false;
			boton.textContent = 'Enviar pedido';
		});
	}

	// --- Ticket -------------------------------------------------------------

	var ETIQUETAS_ESTADO = {
		recibido: 'Recibido',
		asignado: 'En preparación',
		entregado: 'Entregado',
		cancelado: 'Cancelado'
	};

	var ETIQUETAS_PAGO = {
		efectivo: 'Efectivo contra entrega',
		transferencia: 'Transferencia'
	};

	function pintarTicket(destino, pedido) {
		destino.textContent = '';

		var folio = elemento('div', 'ticket__folio');
		folio.appendChild(elemento('small', null, 'Folio de tu pedido'));
		folio.appendChild(elemento('strong', null, pedido.folio));
		destino.appendChild(folio);

		var encabezado = elemento('p');
		encabezado.appendChild(elemento('span', 'etiqueta-estado',
			ETIQUETAS_ESTADO[pedido.estado] || pedido.estado));
		destino.appendChild(encabezado);

		var datos = elemento('dl', 'ticket__datos');
		agregarDato(datos, 'Tienda', pedido.tienda);
		agregarDato(datos, 'Fecha', fechaLegible(pedido.creadoEn));
		agregarDato(datos, 'Cliente', pedido.nombre);
		agregarDato(datos, 'Teléfono', pedido.telefono);
		agregarDato(datos, 'Entrega', pedido.direccion);
		agregarDato(datos, 'Pago', ETIQUETAS_PAGO[pedido.metodoPago] || pedido.metodoPago);
		if (pedido.notas) { agregarDato(datos, 'Notas', pedido.notas); }
		destino.appendChild(datos);

		var tabla = elemento('table');
		var thead = elemento('thead');
		var filaEncabezado = elemento('tr');
		['Producto', 'Cant.', 'Importe'].forEach(function (titulo) {
			filaEncabezado.appendChild(elemento('th', null, titulo));
		});
		thead.appendChild(filaEncabezado);
		tabla.appendChild(thead);

		var tbody = elemento('tbody');
		(pedido.lineas || []).forEach(function (linea) {
			var fila = elemento('tr');
			fila.appendChild(elemento('td', null, linea.nombreProducto));
			fila.appendChild(elemento('td', null, cantidadTexto(linea.cantidad)));
			fila.appendChild(elemento('td', null, dinero.format(linea.subtotal)));
			tbody.appendChild(fila);
		});
		tabla.appendChild(tbody);

		var tfoot = elemento('tfoot');
		var filaTotal = elemento('tr');
		var etiquetaTotal = elemento('td', null, 'Total');
		etiquetaTotal.colSpan = 2;
		filaTotal.appendChild(etiquetaTotal);
		filaTotal.appendChild(elemento('td', null, dinero.format(pedido.total)));
		tfoot.appendChild(filaTotal);
		tabla.appendChild(tfoot);
		destino.appendChild(tabla);

		destino.appendChild(elemento('p', 'pie__nota',
			'Guarda tu folio. Confirmamos disponibilidad, pago y hora de entrega por WhatsApp.'));
	}

	function agregarDato(lista, etiqueta, valor) {
		if (!valor) { return; }
		lista.appendChild(elemento('dt', null, etiqueta));
		lista.appendChild(elemento('dd', null, valor));
	}

	function fechaLegible(iso) {
		var fecha = new Date(iso);
		if (isNaN(fecha.getTime())) { return ''; }
		return fecha.toLocaleString('es-MX', {
			day: '2-digit', month: '2-digit', year: 'numeric',
			hour: '2-digit', minute: '2-digit'
		});
	}

	// --- Seguimiento --------------------------------------------------------

	function consultarSeguimiento(evento) {
		evento.preventDefault();
		var folio = String(new FormData(evento.target).get('folio') || '').trim().toUpperCase();
		if (!folio) { return; }
		location.hash = '#/seguimiento/' + folio;
		buscarFolio(folio);
	}

	function buscarFolio(folio) {
		var aviso = $('[data-seguimiento-estado]');
		var ticket = $('[data-seguimiento-ticket]');
		var acciones = $('[data-seguimiento-acciones]');
		aviso.className = 'aviso';
		aviso.textContent = 'Buscando tu pedido…';
		aviso.hidden = false;
		ticket.hidden = true;
		acciones.hidden = true;
		$('[data-form-seguimiento] input').value = folio;

		pedir('/v1/public/pedidos/' + encodeURIComponent(folio)).then(function (pedido) {
			aviso.hidden = true;
			pintarTicket(ticket, pedido);
			ticket.hidden = false;
			$('[data-seguimiento-whatsapp]').href = pedido.whatsapp;
			acciones.hidden = false;
		}).catch(function (error) {
			aviso.className = 'aviso aviso--error';
			aviso.textContent = error.message;
			aviso.hidden = false;
		});
	}

	// --- Ruteo --------------------------------------------------------------

	function mostrarVista(nombre) {
		$$('[data-vista]').forEach(function (vista) {
			vista.hidden = vista.getAttribute('data-vista') !== nombre;
		});
		window.scrollTo(0, 0);
	}

	function rutear() {
		var partes = location.hash.replace(/^#\/?/, '').split('/');
		var vista = partes[0] || 'catalogo';

		if (vista === 'pedido') {
			mostrarVista('pedido');
			var folio = (partes[1] || '').toUpperCase();
			var destino = $('[data-ticket]');
			if (estado.ultimoPedido && estado.ultimoPedido.folio === folio) {
				pintarTicket(destino, estado.ultimoPedido);
				$('[data-ticket-whatsapp]').href = estado.ultimoPedido.whatsapp;
				return;
			}
			destino.textContent = 'Cargando tu pedido…';
			pedir('/v1/public/pedidos/' + encodeURIComponent(folio)).then(function (pedido) {
				estado.ultimoPedido = pedido;
				pintarTicket(destino, pedido);
				$('[data-ticket-whatsapp]').href = pedido.whatsapp;
			}).catch(function (error) {
				destino.textContent = error.message;
			});
			return;
		}

		if (vista === 'seguimiento') {
			mostrarVista('seguimiento');
			if (partes[1]) { buscarFolio(partes[1].toUpperCase()); }
			return;
		}

		mostrarVista('catalogo');
	}

	// --- Arranque -----------------------------------------------------------

	function iniciar() {
		pintarCarrito();

		$('[data-abrir-carrito]').addEventListener('click', function () { abrirCarrito(true); });
		$('[data-cerrar-carrito]').addEventListener('click', function () { abrirCarrito(false); });
		$('[data-fondo]').addEventListener('click', function () { abrirCarrito(false); });
		document.addEventListener('keydown', function (evento) {
			if (evento.key === 'Escape') { abrirCarrito(false); }
		});

		$('[data-form-pedido]').addEventListener('submit', enviarPedido);
		$('[data-form-seguimiento]').addEventListener('submit', consultarSeguimiento);
		$('[data-imprimir]').addEventListener('click', function () { window.print(); });
		$('[data-cargar-mas]').addEventListener('click', cargarProductos);

		$$('input[name="entrega"]').forEach(function (opcion) {
			opcion.addEventListener('change', function () {
				var domicilio = $('input[name="entrega"]:checked').value !== 'tienda';
				$('[data-campo-direccion]').hidden = !domicilio;
			});
		});

		var buscador = $('[data-buscador]');
		var temporizador = null;
		buscador.addEventListener('input', function () {
			clearTimeout(temporizador);
			temporizador = setTimeout(function () {
				estado.busqueda = buscador.value.trim();
				reiniciarCatalogo();
			}, 320);
		});

		window.addEventListener('hashchange', rutear);

		cargarTienda();
		cargarCategorias();
		cargarProductos();
		rutear();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', iniciar);
	} else {
		iniciar();
	}
})();
