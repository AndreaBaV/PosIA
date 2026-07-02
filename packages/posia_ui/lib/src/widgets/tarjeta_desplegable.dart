/// Tarjeta con lista desplegable para formularios y filtros.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// [Card] con [ExpansionTile] estilizado para secciones colapsables.
class TarjetaDesplegable extends StatelessWidget {
	const TarjetaDesplegable({
		required this.titulo,
		required this.children,
		this.subtitulo,
		this.icono,
		this.inicialmenteExpandido = false,
		this.alCambiarExpansion,
		this.margen,
		super.key,
	});

	final String titulo;
	final String? subtitulo;
	final IconData? icono;
	final List<Widget> children;
	final bool inicialmenteExpandido;
	final ValueChanged<bool>? alCambiarExpansion;
	final EdgeInsetsGeometry? margen;

	@override
	Widget build(BuildContext context) {
		return Card(
			margin: margen ?? const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
			clipBehavior: Clip.antiAlias,
			child: Theme(
				data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
				child: ExpansionTile(
					leading: icono != null
						? Container(
							padding: const EdgeInsets.all(8.0),
							decoration: BoxDecoration(
								color: PosiaColors.cobrar.withValues(alpha: 0.1),
								borderRadius: BorderRadius.circular(10.0),
							),
							child: Icon(icono, color: PosiaColors.cobrar, size: 22.0),
						)
						: null,
					title: Text(
						titulo,
						style: Theme.of(context).textTheme.titleSmall?.copyWith(
							fontWeight: FontWeight.w600,
						),
					),
					subtitle: subtitulo != null
						? Text(
							subtitulo!,
							style: TextStyle(color: Colors.grey.shade600, fontSize: 13.0),
						)
						: null,
					initiallyExpanded: inicialmenteExpandido,
					onExpansionChanged: alCambiarExpansion,
					shape: const RoundedRectangleBorder(),
					collapsedShape: const RoundedRectangleBorder(),
					children: [
						Padding(
							padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: children,
							),
						),
					],
				),
			),
		);
	}
}
