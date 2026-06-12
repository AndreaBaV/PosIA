/// Modulos activables mediante licencia perpetua.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Identificadores de modulos comerciales POSIA.
enum ModuloLicencia {
	/// Nucleo de ventas y catalogo.
	core,

	/// Inventario compartido entre sucursales.
	multiStore,

	/// Sincronizacion con hub central.
	syncHub,

	/// Sincronizacion LAN entre cajas.
	syncLan,

	/// Escalas de precio mayoreo.
	wholesalePricing,

	/// Precios preferenciales por cliente.
	customerPricing,

	/// Ventas a credito.
	creditSales,

	/// Modulo vertical farmacia.
	pharmacy,

	/// Modulo vertical carniceria.
	butcher,

	/// Facturacion CFDI Mexico.
	cfdi,

	/// Comandos de voz en caja.
	voiceCommands,
}
