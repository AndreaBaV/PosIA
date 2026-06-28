/// Pantalla de mapa para elegir la ubicacion GPS de una tienda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:posia_ui/posia_ui.dart';

import '../util/ubicacion_util.dart';

/// Resultado al confirmar un punto en el mapa.
class UbicacionTiendaSeleccionada {
	const UbicacionTiendaSeleccionada({
		required this.latitud,
		required this.longitud,
	});

	final double latitud;
	final double longitud;
}

/// Abre el selector de mapa y devuelve coordenadas elegidas.
Future<UbicacionTiendaSeleccionada?> mostrarSelectorUbicacionTienda(
	BuildContext context, {
	double? latitudInicial,
	double? longitudInicial,
	String titulo = 'Ubicación de la tienda',
}) {
	return Navigator.of(context, rootNavigator: true).push<UbicacionTiendaSeleccionada>(
		MaterialPageRoute(
			fullscreenDialog: true,
			builder: (_) => _PantallaSelectorUbicacionTienda(
				titulo: titulo,
				latitudInicial: latitudInicial,
				longitudInicial: longitudInicial,
			),
		),
	);
}

class _PantallaSelectorUbicacionTienda extends StatefulWidget {
	const _PantallaSelectorUbicacionTienda({
		required this.titulo,
		this.latitudInicial,
		this.longitudInicial,
	});

	final String titulo;
	final double? latitudInicial;
	final double? longitudInicial;

	@override
	State<_PantallaSelectorUbicacionTienda> createState() =>
		_PantallaSelectorUbicacionTiendaState();
}

class _PantallaSelectorUbicacionTiendaState
	extends State<_PantallaSelectorUbicacionTienda> {
	final _mapController = MapController();
	LatLng? _marcador;
	bool _cargando = true;
	String? _mensaje;

	static const _centroMexico = LatLng(19.432608, -99.133209);

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _inicializarMapa());
	}

	@override
	void dispose() {
		_mapController.dispose();
		super.dispose();
	}

	Future<void> _inicializarMapa() async {
		LatLng centro;
		if (widget.latitudInicial != null && widget.longitudInicial != null) {
			centro = LatLng(widget.latitudInicial!, widget.longitudInicial!);
		} else {
			try {
				final pos = await obtenerUbicacionActual();
				centro = LatLng(pos.latitude, pos.longitude);
			} catch (error) {
				centro = _centroMexico;
				_mensaje = '$error';
			}
		}
		if (!mounted) {
			return;
		}
		setState(() {
			_marcador = centro;
			_cargando = false;
		});
		WidgetsBinding.instance.addPostFrameCallback((_) {
			if (mounted) {
				_mapController.move(centro, 16.0);
			}
		});
	}

	Future<void> _irAMiUbicacion() async {
		setState(() {
			_cargando = true;
			_mensaje = null;
		});
		try {
			final pos = await obtenerUbicacionActual();
			final punto = LatLng(pos.latitude, pos.longitude);
			if (!mounted) {
				return;
			}
			setState(() {
				_marcador = punto;
				_cargando = false;
			});
			_mapController.move(punto, 17.0);
		} catch (error) {
			if (!mounted) {
				return;
			}
			setState(() {
				_cargando = false;
				_mensaje = '$error';
			});
		}
	}

	void _confirmar() {
		final punto = _marcador;
		if (punto == null) {
			return;
		}
		Navigator.of(context).pop(
			UbicacionTiendaSeleccionada(
				latitud: punto.latitude,
				longitud: punto.longitude,
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final punto = _marcador;
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.titulo),
				actions: [
					TextButton(
						onPressed: punto == null ? null : _confirmar,
						child: const Text('Listo'),
					),
				],
			),
			body: Stack(
				children: [
					if (_cargando)
						const Center(child: CircularProgressIndicator())
					else if (punto != null)
						FlutterMap(
							mapController: _mapController,
							options: MapOptions(
								initialCenter: punto,
								initialZoom: 16.0,
								onTap: (_, latLng) => setState(() => _marcador = latLng),
							),
							children: [
								TileLayer(
									urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
									userAgentPackageName: 'com.posia.posia_pos',
								),
								MarkerLayer(
									markers: [
										Marker(
											point: punto,
											width: 48,
											height: 48,
											child: const Icon(
												Icons.store,
												color: PosiaColors.cobrar,
												size: 40,
											),
										),
									],
								),
							],
						),
					Positioned(
						left: 16,
						right: 16,
						bottom: 16,
						child: Material(
							elevation: 6,
							borderRadius: BorderRadius.circular(16),
							child: Padding(
								padding: const EdgeInsets.all(16.0),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Text(
											'Toque el mapa para mover el pin o use su ubicación actual.',
											style: Theme.of(context).textTheme.bodySmall,
										),
										if (_mensaje != null) ...[
											const SizedBox(height: 8.0),
											Text(
												_mensaje!,
												style: const TextStyle(
													color: PosiaColors.cancelar,
													fontSize: 12.0,
												),
											),
										],
										if (punto != null) ...[
											const SizedBox(height: 8.0),
											Text(
												'Lat ${punto.latitude.toStringAsFixed(6)} · '
												'Lng ${punto.longitude.toStringAsFixed(6)}',
												style: Theme.of(context).textTheme.labelSmall,
											),
										],
										const SizedBox(height: 12.0),
										OutlinedButton.icon(
											onPressed: _cargando ? null : _irAMiUbicacion,
											icon: const Icon(Icons.my_location),
											label: const Text('Usar mi ubicación'),
										),
										const SizedBox(height: 8.0),
										FilledButton.icon(
											onPressed: punto == null || _cargando ? null : _confirmar,
											icon: const Icon(Icons.check),
											label: const Text('Establecer como ubicación de la tienda'),
										),
									],
								),
							),
						),
					),
				],
			),
		);
	}
}
