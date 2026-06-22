/// Inicio de sesion: usuario, contrasena y activacion por rol.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../providers/app_providers.dart';
import 'pantalla_instalacion_tecnico.dart';

enum _PasoInicioSesion { identificacion, contrasena }

/// Pantalla de autenticacion con flujo por rol.
class PantallaInicioSesion extends ConsumerStatefulWidget {
	const PantallaInicioSesion({super.key});

	@override
	ConsumerState<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends ConsumerState<PantallaInicioSesion> {
	final _codigoController = TextEditingController();
	final _codigoFocus = FocusNode();
	_PasoInicioSesion _paso = _PasoInicioSesion.identificacion;
	Usuario? _usuarioIdentificado;
	String _pinIngresado = '';
	String? _mensajeError;
	bool _validando = false;

	@override
	void dispose() {
		_codigoController.dispose();
		_codigoFocus.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: PosiaColors.fondo,
			body: MarcoAutenticacion(
				titulo: _paso == _PasoInicioSesion.identificacion
					? 'Iniciar sesión'
					: 'Confirma tu acceso',
				subtitulo: _paso == _PasoInicioSesion.identificacion
					? 'Ingresa tu usuario para continuar'
					: _subtituloPasoPin(),
				icono: _paso == _PasoInicioSesion.identificacion
					? Icons.lock_person
					: PresentacionRol.icono(_usuarioIdentificado!.rol),
				contenido: _paso == _PasoInicioSesion.identificacion
					? _tarjetaIdentificacion(context)
					: _tarjetaContrasena(context),
				pie: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						if (_paso == _PasoInicioSesion.contrasena)
							TextButton.icon(
								onPressed: _validando ? null : _volverIdentificacion,
								icon: const Icon(Icons.arrow_back, size: 20.0),
								label: const Text('Cambiar usuario'),
							),
						TextButton.icon(
							onPressed: () => abrirInstalacionTecnica(context, ref),
							icon: const Icon(Icons.engineering, size: 18.0),
							label: const Text('Configuración técnica'),
						),
					],
				),
			),
		);
	}

	String _subtituloPasoPin() {
		final usuario = _usuarioIdentificado;
		if (usuario == null) {
			return 'Ingresa tu contraseña';
		}
		final rol = PermisosUsuario.etiquetaRol(usuario.rol);
		if (usuario.rol == RolUsuario.administrador) {
			return 'Hola ${usuario.nombre}. Como $rol podrás elegir la tienda después.';
		}
		return 'Hola ${usuario.nombre}. Acceso como $rol a tu tienda asignada.';
	}

	Widget _tarjetaIdentificacion(BuildContext context) {
		return Card(
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
			child: Padding(
				padding: const EdgeInsets.all(20.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						TextField(
							controller: _codigoController,
							focusNode: _codigoFocus,
							autofocus: true,
							keyboardType: TextInputType.text,
							textCapitalization: TextCapitalization.characters,
							autocorrect: false,
							enableSuggestions: false,
							textInputAction: TextInputAction.done,
							inputFormatters: [
								FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
							],
							decoration: InputDecoration(
								labelText: 'Usuario',
								hintText: 'Ej. ADM001 o CAJERO1',
								prefixIcon: const Icon(Icons.person_outline),
								border: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12.0),
								),
								filled: true,
							),
							onSubmitted: (_) => _continuarIdentificacion(),
							onChanged: (_) => setState(() => _mensajeError = null),
						),
						if (_mensajeError != null) ...[
							const SizedBox(height: 12.0),
							Text(
								_mensajeError!,
								style: const TextStyle(color: PosiaColors.cancelar),
								textAlign: TextAlign.center,
							),
						],
						const SizedBox(height: 20.0),
						SizedBox(
							height: 48.0,
							child: FilledButton(
								onPressed: _validando ? null : _continuarIdentificacion,
								child: _validando
									? const SizedBox(
										width: 22.0,
										height: 22.0,
										child: CircularProgressIndicator(strokeWidth: 2.0),
									)
									: const Text('Continuar'),
							),
						),
					],
				),
			),
		);
	}

	Widget _tarjetaContrasena(BuildContext context) {
		final usuario = _usuarioIdentificado!;
		final colorRol = PresentacionRol.color(usuario.rol);
		return Card(
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
			child: Padding(
				padding: const EdgeInsets.all(20.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							children: [
								CircleAvatar(
									backgroundColor: colorRol.withValues(alpha: 0.12),
									child: Icon(
										PresentacionRol.icono(usuario.rol),
										color: colorRol,
									),
								),
								const SizedBox(width: 12.0),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												usuario.nombre,
												style: Theme.of(context).textTheme.titleMedium?.copyWith(
													fontWeight: FontWeight.w600,
												),
											),
											const SizedBox(height: 4.0),
											InsigniaRol(rol: usuario.rol, compacto: true),
										],
									),
								),
							],
						),
						const SizedBox(height: 20.0),
						Text(
							'Contraseña',
							style: Theme.of(context).textTheme.titleSmall?.copyWith(
								fontWeight: FontWeight.w600,
							),
						),
						const SizedBox(height: 12.0),
						DecoratedBox(
							decoration: BoxDecoration(
								color: colorRol.withValues(alpha: 0.06),
								borderRadius: BorderRadius.circular(16.0),
								border: Border.all(color: colorRol.withValues(alpha: 0.25)),
							),
							child: Padding(
								padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
								child: Column(
									children: [
										if (_mensajeError != null)
											Padding(
												padding: const EdgeInsets.only(bottom: 12.0),
												child: Text(
													_mensajeError!,
													style: const TextStyle(color: PosiaColors.cancelar),
													textAlign: TextAlign.center,
												),
											),
										if (_validando)
											const Padding(
												padding: EdgeInsets.symmetric(vertical: 56.0),
												child: CircularProgressIndicator(),
											)
										else
											TecladoPinAdmin(
												pinActual: _pinIngresado,
												alPresionarDigito: _agregarDigito,
												alBorrar: _borrarDigito,
											),
									],
								),
							),
						),
					],
				),
			),
		);
	}

	Future<void> _continuarIdentificacion() async {
		final codigo = ValidadorCodigoUsuario.normalizar(_codigoController.text);
		final errorFormato = ValidadorCodigoUsuario.validar(codigo);
		if (errorFormato != null) {
			setState(() => _mensajeError = errorFormato);
			return;
		}
		setState(() {
			_validando = true;
			_mensajeError = null;
		});
		final auth = await ref.read(servicioAutenticacionProvider.future);
		final busqueda = await auth.buscarPerfilPorCodigo(codigo);
		if (!mounted) {
			return;
		}
		if (!busqueda.exitoso) {
			setState(() {
				_validando = false;
				_mensajeError = busqueda.motivoFallo?.mensajeUsuario ?? 'Usuario no encontrado';
			});
			return;
		}
		final usuario = busqueda.usuario!;
		setState(() {
			_validando = false;
			_usuarioIdentificado = usuario;
			_paso = _PasoInicioSesion.contrasena;
			_pinIngresado = '';
			_mensajeError = null;
		});
	}

	void _volverIdentificacion() {
		setState(() {
			_paso = _PasoInicioSesion.identificacion;
			_usuarioIdentificado = null;
			_pinIngresado = '';
			_mensajeError = null;
		});
	}

	void _agregarDigito(String digito) {
		if (_validando || _pinIngresado.length >= LONGITUD_PIN_ADMIN) {
			return;
		}
		setState(() {
			_pinIngresado = _pinIngresado + digito;
			_mensajeError = null;
		});
		if (_pinIngresado.length < LONGITUD_PIN_ADMIN) {
			return;
		}
		_validarAcceso();
	}

	void _borrarDigito() {
		if (_pinIngresado.isEmpty || _validando) {
			return;
		}
		setState(() {
			_pinIngresado = _pinIngresado.substring(0, _pinIngresado.length - 1);
			_mensajeError = null;
		});
	}

	Future<void> _validarAcceso() async {
		final codigo = ValidadorCodigoUsuario.normalizar(_codigoController.text);
		final pin = _pinIngresado;
		setState(() => _validando = true);

		final auth = await ref.read(servicioAutenticacionProvider.future);
		final intento = await auth.autenticar(codigo, pin);

		if (!intento.exitoso) {
			if (!mounted) {
				return;
			}
			setState(() {
				_validando = false;
				_pinIngresado = '';
				_mensajeError = intento.motivoFallo?.mensajeUsuario ?? 'Contraseña incorrecta';
			});
			return;
		}

		final resultado = intento.resultado!;
		final usuario = resultado.usuario;
		final tenantId = resultado.tenantId;

		try {
			await PosiaLocalDatabase.obtenerInstancia().establecerTenant(tenantId);
			final configRepo = await ref.read(configDispositivoRepoProvider.future);
			final config = await configRepo.obtenerConfigDispositivo();
			await configRepo.guardarConfigDispositivo(
				ConfigDispositivo(
					tenantId: tenantId,
					tiendaId: config.tiendaId,
					cajaId: config.cajaId,
					nombreCaja: config.nombreCaja,
				),
			);
			await auth.guardarUsuarioRemoto(resultado);

			ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);
			ref.invalidate(contenedorServiciosProvider);
			await ref.read(contenedorServiciosProvider.future);

			final servicio = await ref.read(servicioAdminProvider.future);
			await servicio.activarSesionTrasLogin(
				usuario,
				tenantId,
				tiendasDesdeHub: resultado.tiendas,
			);

			if (usuario.rol != RolUsuario.administrador) {
				final tiendaId = usuario.tiendaId;
				if (tiendaId == null) {
					throw StateError('Usuario sin tienda asignada');
				}
				ref.read(sesionTiendaProvider.notifier).confirmar(tiendaId);
			}

			ref.read(sesionUsuarioProvider.notifier).iniciar(usuario);
			final servicioCaja = await ref.read(servicioCajaProvider.future);
			await servicioCaja.asegurarVendedorDesdeUsuario(usuario);

			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						'Sesión iniciada · ${usuario.nombre} '
						'(${PermisosUsuario.etiquetaRol(usuario.rol)})',
					),
					backgroundColor: PresentacionRol.color(usuario.rol),
				),
			);
		} on Object catch (error) {
			if (!mounted) {
				return;
			}
			setState(() {
				_validando = false;
				_pinIngresado = '';
				_mensajeError = '$error';
			});
		}
	}
}
