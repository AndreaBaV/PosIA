/// Tarjetas y piezas visuales para listas admin de contactos comerciales.
library;

import 'package:flutter/material.dart';
import 'package:posia_ui/posia_ui.dart';

/// Encabezado con texto introductorio y chips de resumen.
class EncabezadoListaAdmin extends StatelessWidget {
	const EncabezadoListaAdmin({
		required this.descripcion,
		required this.chips,
		super.key,
	});

	final String descripcion;
	final List<Widget> chips;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						descripcion,
						style: Theme.of(context).textTheme.bodySmall?.copyWith(
							color: Colors.grey.shade700,
						),
					),
					if (chips.isNotEmpty) ...[
						const SizedBox(height: 10.0),
						Wrap(spacing: 8.0, runSpacing: 6.0, children: chips),
					],
				],
			),
		);
	}
}

/// Chip compacto para métricas de la lista.
class ChipResumenAdmin extends StatelessWidget {
	const ChipResumenAdmin({
		required this.icono,
		required this.etiqueta,
		super.key,
	});

	final IconData icono;
	final String etiqueta;

	@override
	Widget build(BuildContext context) {
		return Chip(
			avatar: Icon(icono, size: 16.0),
			label: Text(etiqueta),
			visualDensity: VisualDensity.compact,
			materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
		);
	}
}

/// Estado vacío con llamada a la acción.
class EstadoVacioListaAdmin extends StatelessWidget {
	const EstadoVacioListaAdmin({
		required this.icono,
		required this.titulo,
		required this.subtitulo,
		this.textoBoton,
		this.onAgregar,
		super.key,
	});

	final IconData icono;
	final String titulo;
	final String subtitulo;
	final String? textoBoton;
	final VoidCallback? onAgregar;

	@override
	Widget build(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(32.0),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(icono, size: 56.0, color: Colors.grey.shade400),
						const SizedBox(height: 16.0),
						Text(
							titulo,
							style: Theme.of(context).textTheme.titleMedium,
							textAlign: TextAlign.center,
						),
						const SizedBox(height: 8.0),
						Text(
							subtitulo,
							style: TextStyle(color: Colors.grey.shade600),
							textAlign: TextAlign.center,
						),
						if (onAgregar != null && textoBoton != null) ...[
							const SizedBox(height: 20.0),
							FilledButton.icon(
								onPressed: onAgregar,
								icon: const Icon(Icons.add),
								label: Text(textoBoton!),
							),
						],
					],
				),
			),
		);
	}
}

/// Tarjeta de entidad comercial (cliente, proveedor, etc.).
class TarjetaEntidadAdmin extends StatelessWidget {
	const TarjetaEntidadAdmin({
		required this.titulo,
		required this.iconoAvatar,
		required this.onTap,
		this.subtitulo,
		this.colorAvatar,
		this.chips = const [],
		this.inactivo = false,
		this.onEliminar,
		super.key,
	});

	final String titulo;
	final String? subtitulo;
	final IconData iconoAvatar;
	final Color? colorAvatar;
	final List<Widget> chips;
	final bool inactivo;
	final VoidCallback onTap;
	final VoidCallback? onEliminar;

	@override
	Widget build(BuildContext context) {
		final color = colorAvatar ?? PosiaColors.cobrar;
		return Card(
			margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
			child: InkWell(
				borderRadius: BorderRadius.circular(12.0),
				onTap: onTap,
				child: Padding(
					padding: const EdgeInsets.fromLTRB(12.0, 12.0, 4.0, 12.0),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							CircleAvatar(
								backgroundColor: inactivo
									? Colors.grey.shade300
									: color.withValues(alpha: 0.15),
								child: Icon(
									iconoAvatar,
									color: inactivo ? Colors.grey.shade600 : color,
								),
							),
							const SizedBox(width: 12.0),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											titulo,
											style: TextStyle(
												fontWeight: FontWeight.w600,
												fontSize: 16.0,
												color: inactivo ? Colors.grey.shade600 : null,
											),
										),
										if (subtitulo != null && subtitulo!.isNotEmpty) ...[
											const SizedBox(height: 4.0),
											Text(
												subtitulo!,
												style: TextStyle(
													fontSize: 13.0,
													color: Colors.grey.shade700,
												),
											),
										],
										if (chips.isNotEmpty) ...[
											const SizedBox(height: 8.0),
											Wrap(
												spacing: 6.0,
												runSpacing: 4.0,
												children: chips,
											),
										],
									],
								),
							),
							if (onEliminar != null)
								PopupMenuButton<String>(
									onSelected: (accion) {
										if (accion == 'eliminar') {
											onEliminar!();
										}
									},
									itemBuilder: (_) => [
										const PopupMenuItem(
											value: 'eliminar',
											child: Row(
												children: [
													Icon(Icons.delete_outline, color: PosiaColors.cancelar),
													SizedBox(width: 8.0),
													Text('Eliminar'),
												],
											),
										),
									],
								)
							else
								const Icon(Icons.chevron_right, color: Colors.grey),
						],
					),
				),
			),
		);
	}
}

/// Chip informativo pequeño dentro de una tarjeta.
class ChipDetalleEntidad extends StatelessWidget {
	const ChipDetalleEntidad({
		required this.icono,
		required this.texto,
		this.color,
		super.key,
	});

	final IconData icono;
	final String texto;
	final Color? color;

	@override
	Widget build(BuildContext context) {
		return Chip(
			avatar: Icon(icono, size: 14.0, color: color),
			label: Text(texto, style: const TextStyle(fontSize: 12.0)),
			visualDensity: VisualDensity.compact,
			materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
			padding: EdgeInsets.zero,
			labelPadding: const EdgeInsets.only(right: 6.0),
		);
	}
}
