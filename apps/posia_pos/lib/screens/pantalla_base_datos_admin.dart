/// Gestion del almacenamiento Neon: uso, export Excel y purga de historial.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_sync/posia_sync.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/admin_providers.dart';
import '../util/escritor_xlsx.dart';

class PantallaBaseDatosAdmin extends ConsumerStatefulWidget {
	const PantallaBaseDatosAdmin({super.key});

	@override
	ConsumerState<PantallaBaseDatosAdmin> createState() =>
		_PantallaBaseDatosAdminState();
}

class _PantallaBaseDatosAdminState extends ConsumerState<PantallaBaseDatosAdmin> {
	UsoBaseNeon? _uso;
	String? _error;
	var _cargando = true;
	var _ocupado = false;
	DateTime _antesDe = DateTime.now().toUtc().subtract(const Duration(days: 90));
	final _grupos = {for (final g in GruposHistorialNeon.todos) g: true};
	var _exportado = false;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _cargarUso());
	}

	List<String> get _seleccionados =>
		_grupos.entries.where((e) => e.value).map((e) => e.key).toList();

	Future<HubSyncClient?> _cliente() async {
		return ref.read(clienteHubGestionBaseProvider.future);
	}

	Future<void> _cargarUso() async {
		setState(() {
			_cargando = true;
			_error = null;
		});
		try {
			final cliente = await _cliente();
			if (cliente == null) {
				throw StateError(
					'Este dispositivo no tiene hub configurado. '
					'Configure la nube en Estado de la nube.',
				);
			}
			final uso = await cliente.obtenerUsoBase();
			if (!mounted) {
				return;
			}
			setState(() {
				_uso = uso;
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

	Future<void> _elegirFecha() async {
		final local = _antesDe.toLocal();
		final elegido = await showDatePicker(
			context: context,
			initialDate: local,
			firstDate: DateTime(2020),
			lastDate: DateTime.now(),
		);
		if (elegido == null) {
			return;
		}
		setState(() {
			_antesDe = DateTime.utc(elegido.year, elegido.month, elegido.day);
			_exportado = false;
		});
	}

	Future<void> _exportar() async {
		if (_seleccionados.isEmpty) {
			_aviso('Elija al menos un tipo de historial');
			return;
		}
		setState(() => _ocupado = true);
		try {
			final cliente = await _cliente();
			if (cliente == null) {
				throw StateError('Hub no configurado');
			}
			final resultado = await cliente.exportarHistorialNeon(
				antesDe: _antesDe,
				grupos: _seleccionados,
			);
			if (resultado.hojas.isEmpty || resultado.filasTotales == 0) {
				_aviso('No hay filas anteriores a esa fecha');
				return;
			}
			final hojas = <String, List<List<String>>>{};
			for (final hoja in resultado.hojas) {
				if (hoja.columnas.isEmpty) {
					continue;
				}
				hojas[EscritorXlsx.nombreHojaSeguro(hoja.nombre)] = [
					hoja.columnas,
					...hoja.filas,
				];
			}
			if (hojas.isEmpty) {
				_aviso('No hay filas anteriores a esa fecha');
				return;
			}
			final bytes = EscritorXlsx.escribir(hojas);
			final ruta = await _guardarXlsx(bytes);
			if (!mounted) {
				return;
			}
			setState(() => _exportado = true);
			if (ruta != null) {
				await Share.shareXFiles(
					[
						XFile(
							ruta,
							mimeType:
								'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
						),
					],
					subject: 'Historial POSIA',
					text: 'Respaldo de la nube anterior a ${_etiquetaFecha(_antesDe)}',
				);
			}
			if (!mounted) {
				return;
			}
			final extra = resultado.truncado
				? ' El archivo se recortó al máximo de filas; use una fecha más cercana si falta información.'
				: '';
			_aviso('Excel guardado ($ruta).$extra');
		} on Object catch (error) {
			_aviso('$error');
		} finally {
			if (mounted) {
				setState(() => _ocupado = false);
			}
		}
	}

	Future<String?> _guardarXlsx(Uint8List bytes) async {
		if (kIsWeb) {
			return null;
		}
		final carpeta = await getDownloadsDirectory() ??
			await getApplicationDocumentsDirectory();
		final marca = DateTime.now().toLocal().toIso8601String().replaceAll(':', '-');
		final ruta =
			'${carpeta.path}${Platform.pathSeparator}posia_nube_$marca.xlsx';
		await File(ruta).writeAsBytes(bytes, flush: true);
		return ruta;
	}

	Future<void> _compactar() async {
		setState(() => _ocupado = true);
		try {
			final cliente = await _cliente();
			if (cliente == null) {
				throw StateError('Hub no configurado');
			}
			final n = await cliente.compactarCatalogoNeon();
			await _cargarUso();
			_aviso(
				n == 0
					? 'El catálogo ya estaba compacto'
					: 'Se quitaron $n eventos duplicados del catálogo',
			);
		} on Object catch (error) {
			_aviso('$error');
		} finally {
			if (mounted) {
				setState(() => _ocupado = false);
			}
		}
	}

	Future<void> _purgar() async {
		if (_seleccionados.isEmpty) {
			_aviso('Elija al menos un tipo de historial');
			return;
		}
		if (!_exportado) {
			final seguir = await showDialog<bool>(
				context: context,
				builder: (ctx) => AlertDialog(
					icon: const Icon(Icons.warning_amber, color: PosiaColors.cancelar),
					title: const Text('Exportar antes de borrar'),
					content: const Text(
						'Puede guardar un Excel con ese historial y después eliminarlo '
						'de la nube. Si continúa sin exportar, esos datos no se podrán '
						'recuperar desde Neon.\n\n'
						'El catálogo (productos, clientes, existencias) no se borra. '
						'Cada caja conserva su historial local.',
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(ctx, false),
							child: const Text('Cancelar'),
						),
						TextButton(
							onPressed: () => Navigator.pop(ctx, true),
							child: const Text('Borrar sin Excel'),
						),
					],
				),
			);
			if (seguir != true) {
				return;
			}
		}
		if (!mounted) {
			return;
		}
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				icon: const Icon(Icons.delete_forever, color: PosiaColors.cancelar),
				title: const Text('Eliminar de la nube'),
				content: Text(
					'Se borrará de Neon el historial anterior al '
					'${_etiquetaFecha(_antesDe)}.\n\n'
					'Esto libera espacio del plan gratuito. No se puede deshacer.',
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Cancelar'),
					),
					FilledButton(
						style: FilledButton.styleFrom(
							backgroundColor: PosiaColors.cancelar,
						),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text('Eliminar'),
					),
				],
			),
		);
		if (confirmar != true) {
			return;
		}
		setState(() => _ocupado = true);
		try {
			final cliente = await _cliente();
			if (cliente == null) {
				throw StateError('Hub no configurado');
			}
			final resultado = await cliente.purgarHistorialNeon(
				antesDe: _antesDe,
				grupos: _seleccionados,
			);
			await _cargarUso();
			if (!mounted) {
				return;
			}
			setState(() => _exportado = false);
			_aviso('Se eliminaron ${resultado.filasEliminadas} filas de la nube');
		} on Object catch (error) {
			_aviso('$error');
		} finally {
			if (mounted) {
				setState(() => _ocupado = false);
			}
		}
	}

	void _aviso(String texto) {
		if (!mounted) {
			return;
		}
		PosiaNotificaciones.mostrarSnackBar(
			context,
			SnackBar(content: Text(texto)),
		);
	}

	String _etiquetaFecha(DateTime fecha) {
		final l = fecha.toLocal();
		final mm = l.month.toString().padLeft(2, '0');
		final dd = l.day.toString().padLeft(2, '0');
		return '${l.year}-$mm-$dd';
	}

	String _formatoBytes(int bytes) {
		if (bytes < 1024) {
			return '$bytes B';
		}
		if (bytes < 1024 * 1024) {
			return '${(bytes / 1024).toStringAsFixed(1)} KB';
		}
		return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Base de datos (nube)'),
				actions: [
					IconButton(
						onPressed: _cargando || _ocupado ? null : _cargarUso,
						icon: const Icon(Icons.refresh),
					),
				],
			),
			body: _cargando
				? const Center(child: CircularProgressIndicator())
				: _error != null
					? Center(
							child: Padding(
								padding: const EdgeInsets.all(24),
								child: Text(_error!, textAlign: TextAlign.center),
							),
						)
					: _cuerpo(),
		);
	}

	Widget _cuerpo() {
		final uso = _uso;
		final fraccion = (uso?.fraccion ?? 0).clamp(0.0, 1.0);
		final colorBarra = (uso?.sobreElLimite ?? false)
			? PosiaColors.cancelar
			: (uso?.cercaDelLimite ?? false)
				? Colors.orange
				: PosiaColors.cobrar;
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				Card(
					child: Padding(
						padding: const EdgeInsets.all(16),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text(
									'Plan gratuito de Neon (0.5 GB)',
									style: Theme.of(context).textTheme.titleMedium,
								),
								const SizedBox(height: 8),
								Text(
									uso == null
										? 'Sin datos'
										: '${_formatoBytes(uso.bytesUsados)} de '
											'${_formatoBytes(uso.bytesLimite)}',
								),
								const SizedBox(height: 8),
								LinearProgressIndicator(
									value: fraccion,
									color: colorBarra,
									minHeight: 10,
								),
								if (uso?.cercaDelLimite == true) ...[
									const SizedBox(height: 8),
									Text(
										uso!.sobreElLimite
											? 'Está al límite. Exporte y borre historial viejo.'
											: 'Se acerca al tope. Conviene limpiar historial.',
										style: TextStyle(color: colorBarra),
									),
								],
							],
						),
					),
				),
				const SizedBox(height: 12),
				Text(
					'Tablas en la nube',
					style: Theme.of(context).textTheme.titleMedium,
				),
				const SizedBox(height: 8),
				...(uso?.tablas.take(12) ?? const <FilaUsoTablaNeon>[]).map(
					(t) => ListTile(
						dense: true,
						title: Text(t.tabla),
						trailing: Text(
							'${t.filas} filas · ${_formatoBytes(t.bytes)}',
							style: Theme.of(context).textTheme.bodySmall,
						),
					),
				),
				const Divider(height: 32),
				Text(
					'Historial a exportar o borrar',
					style: Theme.of(context).textTheme.titleMedium,
				),
				const SizedBox(height: 4),
				const Text(
					'El catálogo (productos, clientes, existencias, precios) no se '
					'toca. Cada caja conserva su historial local.',
				),
				const SizedBox(height: 8),
				ListTile(
					contentPadding: EdgeInsets.zero,
					title: const Text('Anterior a'),
					subtitle: Text(_etiquetaFecha(_antesDe)),
					trailing: const Icon(Icons.calendar_month),
					onTap: _ocupado ? null : _elegirFecha,
				),
				...GruposHistorialNeon.todos.map((grupo) {
					return CheckboxListTile(
						value: _grupos[grupo] ?? false,
						onChanged: _ocupado
							? null
							: (v) => setState(() {
									_grupos[grupo] = v ?? false;
									_exportado = false;
								}),
						title: Text(GruposHistorialNeon.etiquetas[grupo] ?? grupo),
						subtitle: Text(
							GruposHistorialNeon.descripciones[grupo] ?? '',
						),
						controlAffinity: ListTileControlAffinity.leading,
					);
				}),
				const SizedBox(height: 12),
				FilledButton.icon(
					onPressed: _ocupado ? null : _exportar,
					icon: const Icon(Icons.table_view),
					label: const Text('Exportar a Excel'),
				),
				const SizedBox(height: 8),
				OutlinedButton.icon(
					onPressed: _ocupado ? null : _purgar,
					icon: const Icon(Icons.delete_forever),
					label: const Text('Eliminar de la nube'),
				),
				const SizedBox(height: 8),
				TextButton.icon(
					onPressed: _ocupado ? null : _compactar,
					icon: const Icon(Icons.compress),
					label: const Text('Compactar catálogo duplicado'),
				),
				if (_ocupado) ...[
					const SizedBox(height: 16),
					const Center(child: CircularProgressIndicator()),
					const SizedBox(height: 8),
					const Text(
						'Puede tardar un minuto si hay mucho historial.',
						textAlign: TextAlign.center,
					),
				],
			],
		);
	}
}
