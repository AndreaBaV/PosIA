/// Banner global de progreso de sincronizacion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';

/// Muestra avance de sync manual aunque el usuario cambie de pestaña.
class BannerProgresoSync extends ConsumerWidget {
	const BannerProgresoSync({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final syncUi = ref.watch(syncProgresoProvider);
		if (!syncUi.activo || syncUi.progreso == null) {
			return const SizedBox.shrink();
		}
		final progreso = syncUi.progreso!;
		return Material(
			color: Colors.indigo.shade50,
			elevation: 1.0,
			child: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
				child: Row(
					children: [
						const SizedBox(
							width: 20.0,
							height: 20.0,
							child: CircularProgressIndicator(strokeWidth: 2.0),
						),
						const SizedBox(width: 12.0),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisSize: MainAxisSize.min,
								children: [
									Text(
										progreso.mensaje,
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
											fontWeight: FontWeight.w600,
										),
										maxLines: 2,
										overflow: TextOverflow.ellipsis,
									),
									const SizedBox(height: 6.0),
									if (progreso.tienePorcentaje)
										LinearProgressIndicator(
											value: progreso.fraccion,
											minHeight: 4.0,
											borderRadius: BorderRadius.circular(2.0),
										)
									else
										const LinearProgressIndicator(minHeight: 4.0),
								],
							),
						),
						if (progreso.tienePorcentaje) ...[
							const SizedBox(width: 10.0),
							Text(
								'${progreso.porcentaje} %',
								style: Theme.of(context).textTheme.labelLarge?.copyWith(
									fontWeight: FontWeight.bold,
									color: Colors.indigo.shade800,
								),
							),
						],
					],
				),
			),
		);
	}
}
