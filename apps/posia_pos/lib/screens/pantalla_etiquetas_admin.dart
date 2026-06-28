/// Impresion de etiquetas de producto en PDF por lotes.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../utils/generador_etiquetas_pdf.dart';
import 'pantalla_vista_previa_etiquetas_pdf.dart';

class PantallaEtiquetasAdmin extends ConsumerStatefulWidget {
	const PantallaEtiquetasAdmin({super.key});

	@override
	ConsumerState<PantallaEtiquetasAdmin> createState() => _PantallaEtiquetasAdminState();
}

class _PantallaEtiquetasAdminState extends ConsumerState<PantallaEtiquetasAdmin> {
	final _anchoCtrl = TextEditingController();
	final _altoCtrl = TextEditingController();
	final _busquedaCtrl = TextEditingController();
	final _seleccionados = <String>{};
	List<Producto> _productos = [];
	String? _carpetaDestino;
	var _cargando = true;
	var _generando = false;

	@override
	void initState() {
		super.initState();
		_cargar();
	}

	@override
	void dispose() {
		_anchoCtrl.dispose();
		_altoCtrl.dispose();
		_busquedaCtrl.dispose();
		super.dispose();
	}

	Future<void> _cargar() async {
		setState(() => _cargando = true);
		final servicio = await ref.read(servicioAdminProvider.future);
		final productos = await servicio.listarProductosActivosPorTienda(servicio.tiendaActivaId);
		final ancho = await servicio.obtenerEtiquetaAnchoMm();
		final alto = await servicio.obtenerEtiquetaAltoMm();
		final carpeta = await servicio.obtenerCarpetaEtiquetas();
		if (mounted) {
			_anchoCtrl.text = ancho.toStringAsFixed(1);
			_altoCtrl.text = alto.toStringAsFixed(1);
			setState(() {
				_productos = productos;
				_carpetaDestino = carpeta;
				_cargando = false;
			});
		}
	}

	Future<String> _resolverCarpetaDestino() async {
		final guardada = _carpetaDestino;
		if (guardada != null && guardada.isNotEmpty) {
			final dir = Directory(guardada);
			if (await dir.exists()) {
				return guardada;
			}
		}
		final directorio = await getApplicationDocumentsDirectory();
		final carpeta = Directory('${directorio.path}/$CARPETA_DOCUMENTOS_APP/etiquetas');
		if (!await carpeta.exists()) {
			await carpeta.create(recursive: true);
		}
		return carpeta.path;
	}

	Future<void> _elegirCarpeta() async {
		final ruta = await FilePicker.platform.getDirectoryPath(
			dialogTitle: 'Carpeta para guardar etiquetas',
			initialDirectory: _carpetaDestino,
		);
		if (ruta == null || ruta.isEmpty) {
			return;
		}
		final servicio = await ref.read(servicioAdminProvider.future);
		await servicio.guardarCarpetaEtiquetas(ruta);
		if (mounted) {
			setState(() => _carpetaDestino = ruta);
		}
	}

	List<Producto> get _filtrados {
		final texto = _busquedaCtrl.text.trim().toLowerCase();
		if (texto.isEmpty) {
			return _productos;
		}
		return _productos.where((p) {
			return p.nombre.toLowerCase().contains(texto) ||
				p.codigoBarras.toLowerCase().contains(texto);
		}).toList();
	}

	Future<void> _mostrarVistaPrevia() async {
		if (_seleccionados.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Seleccione al menos un producto')),
			);
			return;
		}
		final ancho = double.tryParse(_anchoCtrl.text.trim());
		final alto = double.tryParse(_altoCtrl.text.trim());
		if (ancho == null || alto == null || ancho < 20 || alto < 15) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Tamaño inválido (mínimo 20 x 15 mm)')),
			);
			return;
		}
		setState(() => _generando = true);
		try {
			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.guardarTamanoEtiquetaMm(anchoMm: ancho, altoMm: alto);
			final items = _productos
				.where((p) => _seleccionados.contains(p.id))
				.map(
					(p) => DatosEtiquetaProducto(
						codigoBarras: p.codigoBarras,
						nombre: p.nombre,
						precio: p.precioBase,
					),
				)
				.toList();
			final bytes = await generarPdfEtiquetasProductos(
				productos: items,
				anchoMm: ancho,
				altoMm: alto,
			);
			final carpeta = await _resolverCarpetaDestino();
			if (!mounted) {
				return;
			}
			final rutaGuardada = await Navigator.push<String>(
				context,
				MaterialPageRoute<String>(
					builder: (_) => PantallaVistaPreviaEtiquetasPdf(
						bytes: bytes,
						carpetaDestino: carpeta,
					),
				),
			);
			if (!mounted || rutaGuardada == null) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('PDF guardado: $rutaGuardada')),
			);
		} catch (error) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('$error'), backgroundColor: PosiaColors.cancelar),
			);
		} finally {
			if (mounted) {
				setState(() => _generando = false);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final filtrados = _filtrados;
		return Scaffold(
			appBar: AppBar(
				title: const Text('Etiquetas de producto'),
				actions: [
					if (_seleccionados.isNotEmpty)
						TextButton(
							onPressed: () => setState(_seleccionados.clear),
							child: Text('Limpiar (${_seleccionados.length})'),
						),
				],
			),
			body: _cargando
				? const Center(child: CircularProgressIndicator())
				: Column(
					children: [
						Padding(
							padding: const EdgeInsets.all(16.0),
							child: Column(
								children: [
									Row(
										children: [
											Expanded(
												child: TextField(
													controller: _anchoCtrl,
													keyboardType: const TextInputType.numberWithOptions(decimal: true),
													decoration: const InputDecoration(
														labelText: 'Ancho (mm)',
														border: OutlineInputBorder(),
													),
												),
											),
											const SizedBox(width: 12.0),
											Expanded(
												child: TextField(
													controller: _altoCtrl,
													keyboardType: const TextInputType.numberWithOptions(decimal: true),
													decoration: const InputDecoration(
														labelText: 'Alto (mm)',
														border: OutlineInputBorder(),
													),
												),
											),
										],
									),
									const SizedBox(height: 12.0),
									Row(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Padding(
												padding: EdgeInsets.only(top: 12.0),
												child: Icon(Icons.folder_outlined),
											),
											const SizedBox(width: 8.0),
											Expanded(
												child: Text(
													_carpetaDestino?.isNotEmpty == true
														? _carpetaDestino!
														: 'Sin carpeta elegida (se usara Documents/$CARPETA_DOCUMENTOS_APP/etiquetas)',
													maxLines: 3,
													overflow: TextOverflow.ellipsis,
												),
											),
											const SizedBox(width: 8.0),
											OutlinedButton.icon(
												onPressed: _elegirCarpeta,
												icon: const Icon(Icons.folder_open),
												label: const Text('Elegir'),
											),
										],
									),
									const SizedBox(height: 12.0),
									TextField(
										controller: _busquedaCtrl,
										decoration: const InputDecoration(
											labelText: 'Buscar producto',
											prefixIcon: Icon(Icons.search),
											border: OutlineInputBorder(),
										),
										onChanged: (_) => setState(() {}),
									),
								],
							),
						),
						Expanded(
							child: ListView.builder(
								itemCount: filtrados.length,
								itemBuilder: (context, indice) {
									final producto = filtrados[indice];
									final seleccionado = _seleccionados.contains(producto.id);
									return CheckboxListTile(
										value: seleccionado,
										onChanged: (v) {
											setState(() {
												if (v == true) {
													_seleccionados.add(producto.id);
												} else {
													_seleccionados.remove(producto.id);
												}
											});
										},
										title: Text(producto.nombre),
										subtitle: Text(
											'${producto.codigoBarras} · ${formatearMoneda(producto.precioBase)}',
										),
									);
								},
							),
						),
						SafeArea(
							child: Padding(
								padding: const EdgeInsets.all(16.0),
								child: SizedBox(
									width: double.infinity,
									child: FilledButton.icon(
										onPressed: _generando ? null : _mostrarVistaPrevia,
										icon: _generando
											? const SizedBox(
												width: 18.0,
												height: 18.0,
												child: CircularProgressIndicator(strokeWidth: 2.0),
											)
											: const Icon(Icons.preview),
										label: Text(
											_generando
												? 'Generando...'
												: 'Vista previa (${_seleccionados.length})',
										),
									),
								),
							),
						),
					],
				),
		);
	}
}
