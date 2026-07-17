/// Claves de secciones del panel de administracion.
library;

/// Permisos asignables a roles personalizados (excluye [miCuenta], siempre visible).
class PermisosAdmin {
	const PermisosAdmin._();

	static const miCuenta = 'mi_cuenta';

	static const usuarios = 'usuarios';
	static const asistencia = 'asistencia';
	static const nomina = 'nomina';

	static const ventas = 'ventas';
	static const pedidos = 'pedidos';
	static const historial = 'historial';
	static const creditos = 'creditos';
	static const cotizaciones = 'cotizaciones';
	static const corte = 'corte';

	static const categorias = 'categorias';
	static const productos = 'productos';
	static const importarProductos = 'importar_productos';
	static const claveEtiquetas = 'etiquetas';
	static const precios = 'precios';
	static const promociones = 'promociones';

	static const existencias = 'existencias';
	static const compras = 'compras';
	static const movimientos = 'movimientos';
	static const traspasos = 'traspasos';
	static const almacenes = 'almacenes';
	static const presentaciones = 'presentaciones';

	static const clientes = 'clientes';
	static const proveedores = 'proveedores';

	static const tiendas = 'tiendas';
	static const reportes = 'reportes';
	static const sync = 'sync';
	static const config = 'config';
	static const rolesPersonalizados = 'roles_personalizados';

	/// Todas las claves que se pueden asignar a un rol personalizado.
	static const asignables = [
		usuarios,
		asistencia,
		nomina,
		ventas,
		pedidos,
		historial,
		creditos,
		cotizaciones,
		corte,
		categorias,
		productos,
		importarProductos,
		claveEtiquetas,
		precios,
		promociones,
		existencias,
		compras,
		movimientos,
		traspasos,
		almacenes,
		presentaciones,
		clientes,
		proveedores,
		tiendas,
		reportes,
		sync,
		config,
		rolesPersonalizados,
	];

	static const etiquetas = {
		usuarios: 'Equipo',
		asistencia: 'Asistencia',
		nomina: 'Nómina',
		ventas: 'Ventas por tienda',
		pedidos: 'Pedidos',
		historial: 'Historial',
		creditos: 'Créditos',
		cotizaciones: 'Cotizaciones',
		corte: 'Corte de caja',
		categorias: 'Categorías',
		productos: 'Productos',
		importarProductos: 'Importar productos',
		claveEtiquetas: 'Etiquetas',
		precios: 'Listas de precios',
		promociones: 'Promociones',
		existencias: 'Existencias',
		compras: 'Compras',
		movimientos: 'Movimientos',
		traspasos: 'Traspasos',
		almacenes: 'Almacenes',
		presentaciones: 'Presentaciones',
		clientes: 'Clientes',
		proveedores: 'Proveedores',
		tiendas: 'Tiendas',
		reportes: 'Reportes',
		sync: 'Estado de la nube',
		config: 'Configuración',
		rolesPersonalizados: 'Roles personalizados',
	};

	static const secciones = {
		'Cuenta': [usuarios, asistencia, nomina, rolesPersonalizados],
		'Ventas': [ventas, pedidos, historial, creditos, cotizaciones, corte],
		'Catálogo': [
			categorias,
			productos,
			importarProductos,
			claveEtiquetas,
			precios,
			promociones,
		],
		'Inventario': [
			existencias,
			compras,
			movimientos,
			traspasos,
			almacenes,
			presentaciones,
		],
		'Personas': [clientes, proveedores],
		'Sistema': [tiendas, reportes, sync, config],
	};
}
