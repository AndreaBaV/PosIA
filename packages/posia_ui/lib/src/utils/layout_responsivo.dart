/// Utilidades de layout adaptativo para distintos tamanos de pantalla.
library;

import 'package:flutter/material.dart';

import '../theme/posia_theme.dart';

/// Categoria de ancho de pantalla.
enum TipoPantalla {
	compacto,
	medio,
	amplio,
	extraAmplio,
}

/// Helpers de espaciado, columnas y disposicion responsiva.
class LayoutResponsivo {
	const LayoutResponsivo._();

	static const double _umbralCompacto = 600.0;
	static const double _umbralMedio = 900.0;
	static const double _umbralAmplio = 1200.0;

	/// Clasifica el ancho disponible.
	static TipoPantalla deAncho(double ancho) {
		if (ancho < _umbralCompacto) {
			return TipoPantalla.compacto;
		}
		if (ancho < _umbralMedio) {
			return TipoPantalla.medio;
		}
		if (ancho < _umbralAmplio) {
			return TipoPantalla.amplio;
		}
		return TipoPantalla.extraAmplio;
	}

	static TipoPantalla de(BuildContext context) =>
		deAncho(MediaQuery.sizeOf(context).width);

	/// Padding exterior segun ancho.
	static double padding(double ancho) {
		return switch (deAncho(ancho)) {
			TipoPantalla.compacto => 16.0,
			TipoPantalla.medio => 24.0,
			TipoPantalla.amplio => 32.0,
			TipoPantalla.extraAmplio => 40.0,
		};
	}

	static EdgeInsets paddingTodo(BuildContext context) {
		final p = padding(MediaQuery.sizeOf(context).width);
		return EdgeInsets.all(p);
	}

	/// Columnas para grillas de menu admin.
	static int columnasGrid(double ancho) {
		return switch (deAncho(ancho)) {
			TipoPantalla.compacto => 2,
			TipoPantalla.medio => 3,
			TipoPantalla.amplio => 4,
			TipoPantalla.extraAmplio => 5,
		};
	}

	/// Disposicion en dos columnas para formularios de acceso.
	static bool usarPanelLateral(double ancho, double alto) =>
		ancho >= 720.0 && alto >= 360.0;

	/// Ancho maximo del formulario en vista compacta.
	static double anchoMaximoFormulario(double ancho) {
		if (ancho < _umbralCompacto) {
			return ancho;
		}
		if (ancho < _umbralMedio) {
			return 480.0;
		}
		return 560.0;
	}
}

/// Marco de pantalla completa con panel lateral en escritorio.
class MarcoAutenticacion extends StatelessWidget {
	const MarcoAutenticacion({
		required this.titulo,
		required this.subtitulo,
		required this.contenido,
		this.etiquetaTienda,
		this.pie,
		this.icono = Icons.point_of_sale,
		super.key,
	});

	final String titulo;
	final String subtitulo;
	final String? etiquetaTienda;
	final Widget contenido;
	final Widget? pie;
	final IconData icono;

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, constraints) {
				final ancho = constraints.maxWidth;
				final alto = constraints.maxHeight;
				final padding = LayoutResponsivo.padding(ancho);
				final dosColumnas = LayoutResponsivo.usarPanelLateral(ancho, alto);

				if (dosColumnas) {
					return Row(
						children: [
							Expanded(
								flex: 11,
								child: _PanelMarca(
									titulo: titulo,
									subtitulo: subtitulo,
									etiquetaTienda: etiquetaTienda,
									icono: icono,
								),
							),
							Expanded(
								flex: 9,
								child: ColoredBox(
									color: Theme.of(context).scaffoldBackgroundColor,
									child: SafeArea(
										child: _cuerpoScroll(
											context: context,
											alto: alto,
											padding: padding,
											incluirEncabezado: false,
										),
									),
								),
							),
						],
					);
				}

				return ColoredBox(
					color: Theme.of(context).scaffoldBackgroundColor,
					child: SafeArea(
						child: _cuerpoScroll(
							context: context,
							alto: alto,
							padding: padding,
							incluirEncabezado: true,
						),
					),
				);
			},
		);
	}

	Widget _cuerpoScroll({
		required BuildContext context,
		required double alto,
		required double padding,
		required bool incluirEncabezado,
	}) {
		return SingleChildScrollView(
			padding: EdgeInsets.symmetric(
				horizontal: padding,
				vertical: padding,
			),
			child: ConstrainedBox(
				constraints: BoxConstraints(minHeight: alto - padding * 2),
				child: Center(
					child: ConstrainedBox(
						constraints: BoxConstraints(
							maxWidth: LayoutResponsivo.anchoMaximoFormulario(
								MediaQuery.sizeOf(context).width,
							),
						),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								if (incluirEncabezado)
									_EncabezadoAutenticacion(
										titulo: titulo,
										subtitulo: subtitulo,
										etiquetaTienda: etiquetaTienda,
										icono: icono,
										compacto: true,
									),
								if (incluirEncabezado) const SizedBox(height: 24.0),
								contenido,
								if (pie != null) ...[
									const SizedBox(height: 12.0),
									pie!,
								],
							],
						),
					),
				),
			),
		);
	}
}

class _PanelMarca extends StatelessWidget {
	const _PanelMarca({
		required this.titulo,
		required this.subtitulo,
		this.etiquetaTienda,
		required this.icono,
	});

	final String titulo;
	final String subtitulo;
	final String? etiquetaTienda;
	final IconData icono;

	@override
	Widget build(BuildContext context) {
		return DecoratedBox(
			decoration: BoxDecoration(
				gradient: LinearGradient(
					begin: Alignment.topLeft,
					end: Alignment.bottomRight,
					colors: [
						PosiaColors.cobrar,
						PosiaColors.cobrar.withValues(alpha: 0.82),
						const Color(0xFF1B5E20),
					],
				),
			),
			child: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(40.0),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Container(
								padding: const EdgeInsets.all(18.0),
								decoration: BoxDecoration(
									color: Colors.white.withValues(alpha: 0.15),
									borderRadius: BorderRadius.circular(20.0),
								),
								child: Icon(icono, size: 48.0, color: Colors.white),
							),
							const SizedBox(height: 28.0),
							Text(
								'POSIA',
								style: Theme.of(context).textTheme.headlineMedium?.copyWith(
									color: Colors.white,
									fontWeight: FontWeight.w800,
									letterSpacing: 1.2,
								),
							),
							const SizedBox(height: 8.0),
							Text(
								titulo,
								style: Theme.of(context).textTheme.headlineSmall?.copyWith(
									color: Colors.white,
									fontWeight: FontWeight.w600,
								),
							),
							const SizedBox(height: 12.0),
							Text(
								subtitulo,
								style: Theme.of(context).textTheme.bodyLarge?.copyWith(
									color: Colors.white.withValues(alpha: 0.9),
									height: 1.4,
								),
							),
							if (etiquetaTienda != null) ...[
								const SizedBox(height: 24.0),
								Chip(
									avatar: const Icon(Icons.storefront, color: Colors.white, size: 18.0),
									label: Text(
										etiquetaTienda!,
										style: const TextStyle(
											color: Colors.white,
											fontWeight: FontWeight.w600,
										),
									),
									backgroundColor: Colors.white.withValues(alpha: 0.18),
									side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
								),
							],
						],
					),
				),
			),
		);
	}
}

class _EncabezadoAutenticacion extends StatelessWidget {
	const _EncabezadoAutenticacion({
		required this.titulo,
		required this.subtitulo,
		this.etiquetaTienda,
		required this.icono,
		required this.compacto,
	});

	final String titulo;
	final String subtitulo;
	final String? etiquetaTienda;
	final IconData icono;
	final bool compacto;

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				Container(
					width: compacto ? 64.0 : 80.0,
					height: compacto ? 64.0 : 80.0,
					decoration: BoxDecoration(
						color: PosiaColors.cobrar.withValues(alpha: 0.12),
						shape: BoxShape.circle,
					),
					child: Icon(icono, size: compacto ? 32.0 : 40.0, color: PosiaColors.cobrar),
				),
				const SizedBox(height: 16.0),
				Text(
					titulo,
					textAlign: TextAlign.center,
					style: Theme.of(context).textTheme.headlineSmall?.copyWith(
						fontWeight: FontWeight.bold,
					),
				),
				const SizedBox(height: 8.0),
				Text(
					subtitulo,
					textAlign: TextAlign.center,
					style: Theme.of(context).textTheme.bodyMedium?.copyWith(
						color: Theme.of(context).colorScheme.outline,
					),
				),
				if (etiquetaTienda != null) ...[
					const SizedBox(height: 12.0),
					Chip(
						avatar: const Icon(Icons.storefront, size: 18.0, color: PosiaColors.cobrar),
						label: Text(
							etiquetaTienda!,
							style: const TextStyle(fontWeight: FontWeight.w600),
						),
						backgroundColor: PosiaColors.cobrar.withValues(alpha: 0.08),
						side: BorderSide(color: PosiaColors.cobrar.withValues(alpha: 0.25)),
					),
				],
			],
		);
	}
}
