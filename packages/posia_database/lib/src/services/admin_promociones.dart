/// Dominio de promociones: lotes de mayoreo cruzado y combos de precio fijo.
///
/// Extraído de `ServicioAdmin` (`_guardarLotePromocionImportado`,
/// `_registrarEventoLotePromocion`) y ampliado con CRUD desde UI — antes
/// solo existía la ruta de importación masiva.
library;

import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:uuid/uuid.dart';

import '../repositories/combo_repository.dart';
import '../repositories/lote_promocion_repository.dart';
import '../repositories/producto_repository.dart';
import '../repositories/variante_repository.dart';
import '../sync/admin_emisor_eventos_sync.dart';

/// Miembro de un lote o combo con su nombre para mostrar en UI.
class MiembroPromocion {
	const MiembroPromocion({required this.productoId, required this.nombre});

	final String productoId;
	final String nombre;
}

/// Catálogo de promociones cruzadas entre productos.
class AdminPromociones {
	AdminPromociones({
		required LotePromocionRepository lotePromocionRepository,
		required ComboRepository comboRepository,
		required AdminEmisorEventosSync emisorEventos,
		required SyncOrchestrator syncOrchestrator,
		ProductoRepository? productoRepository,
		VarianteRepository? varianteRepository,
	}) : _lotePromocionRepository = lotePromocionRepository,
	     _comboRepository = comboRepository,
	     _emisorEventos = emisorEventos,
	     _syncOrchestrator = syncOrchestrator,
	     _productoRepository = productoRepository,
	     _varianteRepository = varianteRepository;

	final LotePromocionRepository _lotePromocionRepository;
	final ComboRepository _comboRepository;
	final AdminEmisorEventosSync _emisorEventos;
	final SyncOrchestrator _syncOrchestrator;
	final ProductoRepository? _productoRepository;
	final VarianteRepository? _varianteRepository;
	final Uuid _generadorId = const Uuid();

	Future<List<LotePromocion>> listarLotesPromocion() {
		return _lotePromocionRepository.listarTodos();
	}

	Future<LotePromocion?> obtenerLotePromocion(String id) {
		return _lotePromocionRepository.obtenerPorId(id);
	}

	/// Sugiere miembros para un lote a partir de la "familia" de un producto:
	/// el producto padre mismo más sus variantes activas (`productoPadreId`).
	///
	/// Las variantes viven en `product_variants`, una tabla distinta a
	/// `products` — [MiembroPromocion.productoId] usa el id de la variante
	/// directamente, igual que hace el carrito al venderla
	/// (`ServicioCaja.agregarVariante`); `AseguradorPadresFk.asegurarProducto`
	/// sabe reflejar esos ids como stub FK real en vez de un placeholder
	/// genérico cuando se guarda el lote.
	Future<List<MiembroPromocion>> sugerirMiembrosDeFamilia(
		String productoPadreId,
	) async {
		final padre = await _productoRepository?.obtenerPorId(productoPadreId);
		final variantes =
			await _varianteRepository?.listarActivasPorProductoPadre(productoPadreId) ??
			[];
		final miembros = <MiembroPromocion>[];
		if (padre != null) {
			miembros.add(MiembroPromocion(productoId: padre.id, nombre: padre.nombre));
		}
		for (final variante in variantes) {
			miembros.add(
				MiembroPromocion(
					productoId: variante.id,
					nombre: padre != null
						? '${padre.nombre} - ${variante.nombre}'
						: variante.nombre,
				),
			);
		}
		return miembros;
	}

	/// Resuelve nombres para mostrar de los miembros de un lote/combo ya
	/// guardado, buscando primero en productos y luego en variantes.
	Future<List<MiembroPromocion>> nombresDeMiembros(List<String> productoIds) async {
		final resultado = <MiembroPromocion>[];
		for (final id in productoIds) {
			final producto = await _productoRepository?.obtenerPorId(id);
			if (producto != null) {
				resultado.add(MiembroPromocion(productoId: id, nombre: producto.nombre));
				continue;
			}
			final variante = await _varianteRepository?.obtenerPorId(id);
			if (variante != null) {
				final padre = await _productoRepository?.obtenerPorId(variante.productoPadreId);
				resultado.add(
					MiembroPromocion(
						productoId: id,
						nombre: padre != null
							? '${padre.nombre} - ${variante.nombre}'
							: variante.nombre,
					),
				);
				continue;
			}
			resultado.add(MiembroPromocion(productoId: id, nombre: id));
		}
		return resultado;
	}

	/// Crea o actualiza un lote de promoción desde la UI de administración.
	/// Reemplaza la membresía tal cual la deja el admin (no la fusiona).
	Future<LotePromocion> guardarLotePromocion({
		String? id,
		required String nombre,
		required double cantidadMinima,
		required double precioUnitario,
		required List<String> productoIds,
		bool activo = true,
	}) async {
		final loteId = id ?? _generadorId.v4();
		final existente = id == null ? null : await _lotePromocionRepository.obtenerPorId(id);
		final lote = LotePromocion(
			id: loteId,
			codigoExterno: existente?.codigoExterno ?? loteId,
			nombre: nombre,
			cantidadMinima: cantidadMinima,
			precioUnitario: precioUnitario,
			activo: activo,
			productoIds: productoIds,
		);
		await _lotePromocionRepository.reemplazarLote(lote);
		await _registrarEventoLotePromocion(lote);
		return lote;
	}

	/// Baja lógica: desactiva el lote sin perder su historial de miembros.
	Future<void> eliminarLotePromocion(String id) async {
		final existente = await _lotePromocionRepository.obtenerPorId(id);
		if (existente == null) {
			return;
		}
		final lote = existente.copiarCon(activo: false);
		await _lotePromocionRepository.reemplazarLote(lote);
		await _registrarEventoLotePromocion(lote);
	}

	/// Registra (o amplía) un lote encontrado durante la importación masiva
	/// de productos — fusiona miembros con los que ya existieran bajo el
	/// mismo código externo en vez de reemplazarlos.
	Future<void> registrarLoteDesdeImportacion({
		required String codigoExterno,
		required double cantidadMinima,
		required double precioUnitario,
		required List<String> productoIds,
	}) async {
		final existente = await _lotePromocionRepository.obtenerPorCodigoExterno(
			codigoExterno,
		);
		final miembros = <String>{
			...?existente?.productoIds,
			...productoIds,
		}.toList();
		final lote = LotePromocion(
			id: existente?.id ?? _generadorId.v4(),
			codigoExterno: codigoExterno,
			nombre: existente?.nombre.isNotEmpty == true
				? existente!.nombre
				: 'Lote promocion $codigoExterno',
			cantidadMinima: cantidadMinima,
			precioUnitario: precioUnitario,
			activo: true,
			productoIds: miembros,
		);
		await _lotePromocionRepository.reemplazarLote(lote);
		await _registrarEventoLotePromocion(lote);
	}

	Future<void> _registrarEventoLotePromocion(LotePromocion lote) async {
		final eventoId = await _emisorEventos.lotePromocion(lote);
		if (eventoId.isEmpty) {
			return;
		}
		await _syncOrchestrator.sincronizarEventosPorIds([eventoId]);
	}

	Future<List<Combo>> listarCombos() {
		return _comboRepository.listarTodos();
	}

	Future<Combo?> obtenerCombo(String id) {
		return _comboRepository.obtenerPorId(id);
	}

	/// Crea o actualiza un combo de precio fijo desde la UI de administración.
	Future<Combo> guardarCombo({
		String? id,
		required String nombre,
		required double precioCombo,
		required List<ComboMiembro> miembros,
		bool activo = true,
	}) async {
		final combo = Combo(
			id: id ?? _generadorId.v4(),
			nombre: nombre,
			precioCombo: precioCombo,
			activo: activo,
			miembros: miembros,
		);
		await _comboRepository.reemplazarCombo(combo);
		await _registrarEventoCombo(combo);
		return combo;
	}

	/// Baja lógica: desactiva el combo sin perder su historial de miembros.
	Future<void> eliminarCombo(String id) async {
		final existente = await _comboRepository.obtenerPorId(id);
		if (existente == null) {
			return;
		}
		final combo = existente.copiarCon(activo: false);
		await _comboRepository.reemplazarCombo(combo);
		await _registrarEventoCombo(combo);
	}

	Future<void> _registrarEventoCombo(Combo combo) async {
		final eventoId = await _emisorEventos.combo(combo);
		if (eventoId.isEmpty) {
			return;
		}
		await _syncOrchestrator.sincronizarEventosPorIds([eventoId]);
	}
}
