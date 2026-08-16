/// Panel para consultar y aplicar actualizaciones de la app (laptops Windows).
library;

import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../services/servicio_actualizacion_app.dart';

class PantallaActualizacionesAdmin extends ConsumerStatefulWidget {
	const PantallaActualizacionesAdmin({super.key});

	@override
	ConsumerState<PantallaActualizacionesAdmin> createState() =>
		_PantallaActualizacionesAdminState();
}

class _PantallaActualizacionesAdminState
	extends ConsumerState<PantallaActualizacionesAdmin> {
	VersionApp? _instalada;
	ManifestoActualizacionApp? _remota;
	String? _error;
	var _cargando = true;
	var _instalando = false;
	int _bytesRecibidos = 0;
	int? _bytesTotales;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _consultar());
	}

	Future<void> _consultar() async {
		setState(() {
			_cargando = true;
			_error = null;
		});
		try {
			final info = await PackageInfo.fromPlatform();
			final instalada = VersionApp(
				nombre: info.version,
				build: int.tryParse(info.buildNumber) ?? 0,
			);
			final servicio = await ref.read(servicioActualizacionAppProvider.future);
			ManifestoActualizacionApp? remota;
			if (servicio != null) {
				remota = await servicio.consultar(
					plataforma: plataformaActualizacionApp(),
				);
			}
			if (!mounted) {
				return;
			}
			setState(() {
				_instalada = instalada;
				_remota = remota;
				_cargando = false;
			});
		} on Object catch (error) {
			if (!mounted) {
				return;
			}
			setState(() {
				_error = '$error';
				_cargando = false;
			});
		}
	}

	bool get _hayActualizacion {
		final instalada = _instalada;
		final remota = _remota;
		if (instalada == null || remota == null) {
			return false;
		}
		return hayActualizacionDisponible(instalada: instalada, remota: remota);
	}

	Future<void> _descargarEInstalar() async {
		final servicio = await ref.read(servicioActualizacionAppProvider.future);
		final paquete = _remota?.paquete;
		if (servicio == null || paquete == null || paquete.url.trim().isEmpty) {
			return;
		}
		setState(() {
			_instalando = true;
			_error = null;
			_bytesRecibidos = 0;
			_bytesTotales = paquete.tamanoBytes > 0 ? paquete.tamanoBytes : null;
		});
		try {
			final archivo = await servicio.descargar(
				paquete: paquete,
				alProgreso: (recibidos, total) {
					if (!mounted) {
						return;
					}
					setState(() {
						_bytesRecibidos = recibidos;
						_bytesTotales = total ?? _bytesTotales;
					});
				},
			);
			final resultado = await servicio.instalar(archivo);
			if (!mounted) {
				return;
			}
			if (resultado == ResultadoInstalacionActualizacion.reinicioPendiente) {
				if (!mounted) {
					exit(0);
				}
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							'Cerrando para instalar. POSIA se reabrirá sola.',
						),
					),
				);
				await Future<void>.delayed(const Duration(milliseconds: 800));
				exit(0);
			}
			if (resultado == ResultadoInstalacionActualizacion.instaladorAbierto) {
				if (!mounted) {
					return;
				}
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text(
							'Se abrió el instalador. Siga las instrucciones y '
							'reabra POSIA al terminar.',
						),
					),
				);
			}
		} on Object catch (error) {
			if (!mounted) {
				return;
			}
			setState(() => _error = '$error');
		} finally {
			if (mounted) {
				setState(() => _instalando = false);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		final servicioAsync = ref.watch(servicioActualizacionAppProvider);
		return Scaffold(
			appBar: AppBar(
				title: const Text('Actualizaciones'),
				actions: [
					IconButton(
						tooltip: 'Volver a consultar',
						onPressed: _cargando || _instalando ? null : _consultar,
						icon: const Icon(Icons.refresh),
					),
				],
			),
			body: servicioAsync.when(
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (error, _) => Center(child: Text('$error')),
				data: (servicio) {
					if (_cargando) {
						return const Center(child: CircularProgressIndicator());
					}
					return ListView(
						padding: const EdgeInsets.all(24.0),
						children: [
							const Icon(
								Icons.system_update,
								size: 72.0,
								color: Colors.teal,
							),
							const SizedBox(height: 16.0),
							Text(
								servicio?.soportaInstalacionAutomatica == true
									? 'Descargue la versión más reciente. Al terminar, '
										'la app se cierra, se actualiza y se reabre sola.'
									: 'En este teléfono las actualizaciones se instalan '
										'solas desde la tienda. Aquí solo puede consultar '
										'la versión.',
								textAlign: TextAlign.center,
								style: Theme.of(context).textTheme.bodyMedium,
							),
							const SizedBox(height: 24.0),
							_FilaDato(
								icono: Icons.computer,
								etiqueta: 'Versión instalada',
								valor: _instalada?.etiqueta ?? '—',
							),
							const SizedBox(height: 12.0),
							_FilaDato(
								icono: Icons.cloud_download,
								etiqueta: 'Versión en la nube',
								valor: _etiquetaRemota(servicio != null),
							),
							if (_remota != null && _remota!.notas.trim().isNotEmpty) ...[
								const SizedBox(height: 16.0),
								Card(
									child: ListTile(
										leading: const Icon(Icons.notes),
										title: const Text('Novedades'),
										subtitle: Text(_remota!.notas.trim()),
									),
								),
							],
							if (_error != null) ...[
								const SizedBox(height: 16.0),
								Card(
									color: PosiaColors.cancelar.withValues(alpha: 0.08),
									child: ListTile(
										leading: const Icon(
											Icons.error_outline,
											color: PosiaColors.cancelar,
										),
										title: const Text('No se pudo completar'),
										subtitle: Text(_error!),
									),
								),
							],
							if (_instalando) ...[
								const SizedBox(height: 24.0),
								LinearProgressIndicator(
									value: _progresoDescarga,
								),
								const SizedBox(height: 8.0),
								Text(
									_textoProgreso,
									textAlign: TextAlign.center,
									style: Theme.of(context).textTheme.bodySmall,
								),
							],
							const SizedBox(height: 28.0),
							if (servicio == null)
								FilledButton.icon(
									onPressed: null,
									icon: const Icon(Icons.cloud_off),
									label: const Text('Sin servidor de nube'),
								)
							else if (_hayActualizacion &&
								servicio.soportaInstalacionAutomatica &&
								(_remota?.hayPaquete ?? false))
								FilledButton.icon(
									onPressed: _instalando ? null : _descargarEInstalar,
									icon: const Icon(Icons.download),
									label: Text(
										_instalando
											? 'Descargando…'
											: 'Descargar e instalar ${_remota!.version}',
									),
								)
							else if (_hayActualizacion &&
								!servicio.soportaInstalacionAutomatica)
								const Text(
									'Cuando la tienda publique esta versión, el teléfono '
									'la instalará automáticamente.',
									textAlign: TextAlign.center,
								)
							else if (_hayActualizacion && !(_remota?.hayPaquete ?? false))
								const Text(
									'Hay una versión más reciente, pero el servidor aún '
									'no publicó el paquete de Windows.',
									textAlign: TextAlign.center,
								)
							else if (_remota != null)
								FilledButton.tonalIcon(
									onPressed: null,
									icon: const Icon(Icons.check_circle),
									label: const Text('Ya está actualizado'),
								),
						],
					);
				},
			),
		);
	}

	String _etiquetaRemota(bool hayHub) {
		if (!hayHub) {
			return 'Sin servidor configurado';
		}
		final remota = _remota;
		if (remota == null) {
			return 'Sin versión publicada';
		}
		return remota.build > 0
			? '${remota.version}+${remota.build}'
			: remota.version;
	}

	double? get _progresoDescarga {
		final total = _bytesTotales;
		if (total == null || total <= 0) {
			return null;
		}
		return (_bytesRecibidos / total).clamp(0.0, 1.0);
	}

	String get _textoProgreso {
		final total = _bytesTotales;
		if (total != null && total > 0) {
			return '${_formatearBytes(_bytesRecibidos)} de ${_formatearBytes(total)}';
		}
		return _formatearBytes(_bytesRecibidos);
	}

	String _formatearBytes(int bytes) {
		if (bytes < 1024) {
			return '$bytes B';
		}
		if (bytes < 1024 * 1024) {
			return '${(bytes / 1024).toStringAsFixed(1)} KB';
		}
		return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
	}
}

class _FilaDato extends StatelessWidget {
	const _FilaDato({
		required this.icono,
		required this.etiqueta,
		required this.valor,
	});

	final IconData icono;
	final String etiqueta;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Card(
			child: ListTile(
				leading: Icon(icono, color: Colors.teal),
				title: Text(etiqueta),
				trailing: Text(
					valor,
					style: Theme.of(context).textTheme.titleMedium,
				),
			),
		);
	}
}
