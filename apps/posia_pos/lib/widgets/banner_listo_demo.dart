/// Banner de checklist para presentacion comercial.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';
import '../util/plataforma_util.dart';

/// Muestra estado del demo y tips de presentacion.
class BannerListoDemo extends ConsumerStatefulWidget {
	const BannerListoDemo({super.key});

	@override
	ConsumerState<BannerListoDemo> createState() => _BannerListoDemoState();
}

class _BannerListoDemoState extends ConsumerState<BannerListoDemo> {
	bool _visible = true;

	@override
	Widget build(BuildContext context) {
		if (!_visible) {
			return const SizedBox.shrink();
		}
		final estado = ref.watch(carritoNotifierProvider);
		return estado.when(
			data: (s) => Material(
				color: PosiaColors.cobrar.withValues(alpha: 0.12),
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Icon(Icons.rocket_launch, color: PosiaColors.cobrar, size: 22.0),
							const SizedBox(width: 8.0),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text(
											'Listo para presentacion',
											style: TextStyle(fontWeight: FontWeight.bold),
										),
										Text(
											esPlataformaMovilNativa()
												? 'Voz: "Genera el ticket: vendi un kilo de arroz, medio kilo de frijol peruano y 1 caja de leche" · PIN $PIN_ADMIN_DEMO'
												: 'Turno ${s.turnoAbierto ? "abierto" : "cerrado"} · PIN Admin $PIN_ADMIN_DEMO · Escanea o toca productos',
											style: Theme.of(context).textTheme.bodySmall,
										),
									],
								),
							),
							IconButton(
								icon: const Icon(Icons.close, size: 18.0),
								onPressed: () => setState(() => _visible = false),
								tooltip: 'Ocultar',
							),
						],
					),
				),
			),
			loading: () => const SizedBox.shrink(),
			error: (_, _) => const SizedBox.shrink(),
		);
	}
}
