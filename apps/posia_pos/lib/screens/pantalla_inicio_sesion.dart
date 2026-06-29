/// Inicio de sesion: usuario, contrasena, Face ID y activacion por rol.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/admin_providers.dart';
import '../services/gestor_acceso_biometrico.dart';
import '../services/servicio_inicio_sesion.dart';
import '../util/plataforma_util.dart';
import '../util/teclado_util.dart';
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
	final _gestorBiometria = GestorAccesoBiometrico();
	_PasoInicioSesion _paso = _PasoInicioSesion.identificacion;
	Usuario? _usuarioIdentificado;
	String _pinIngresado = '';
	String? _mensajeError;
	bool _validando = false;
	bool _biometriaDisponible = false;
	String _etiquetaBiometria = 'Biometría';
	List<PerfilAccesoBiometrico> _perfilesBiometricos = [];
	bool _intentoBiometricoAutomatico = false;

	@override
	void initState() {
		super.initState();
		_codigoFocus.addListener(() => setState(() {}));
		WidgetsBinding.instance.addPostFrameCallback((_) => _prepararBiometria());
	}

	@override
	void dispose() {
		_codigoController.dispose();
		_codigoFocus.dispose();
		super.dispose();
	}

	Future<void> _prepararBiometria() async {
		if (!esPlataformaMovilNativa()) {
			return;
		}
		final configRepo = await ref.read(configDispositivoRepoProvider.future);
		await configRepo.obtenerConfigDispositivo();
		final disponible = await _gestorBiometria.estaDisponible();
		final perfiles = await _gestorBiometria.listarPerfiles();
		final etiqueta = await _gestorBiometria.etiquetaBiometria();
		if (!mounted) {
			return;
		}
		setState(() {
			_biometriaDisponible = disponible;
			_perfilesBiometricos = perfiles;
			_etiquetaBiometria = etiqueta;
		});
		if (disponible && perfiles.length == 1 && !_intentoBiometricoAutomatico) {
			_intentoBiometricoAutomatico = true;
			await _iniciarConBiometria(perfiles.first.usuarioId);
		}
	}

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			onTap: () => ocultarTeclado(context),
			child: Scaffold(
				backgroundColor: PosiaColors.fondo,
				body: MarcoAutenticacion(
					titulo: _paso == _PasoInicioSesion.identificacion
						? 'Iniciar sesión'
						: _usuarioIdentificado!.nombre,
					subtitulo: _paso == _PasoInicioSesion.identificacion
						? (_biometriaDisponible && _perfilesBiometricos.isNotEmpty
							? ''
							: 'Código de usuario')
						: '',
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
									label: const Text('Atrás'),
								),
							TextButton.icon(
								onPressed: () => abrirInstalacionTecnica(context, ref),
								icon: const Icon(Icons.engineering, size: 18.0),
								label: const Text('Técnico'),
							),
						],
					),
				),
			),
		);
	}

	Widget _tarjetaIdentificacion(BuildContext context) {
		return Card(
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
			child: Padding(
				padding: const EdgeInsets.all(20.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						if (_biometriaDisponible && _perfilesBiometricos.isNotEmpty) ...[
							_seccionAccesoBiometrico(context),
							Padding(
								padding: const EdgeInsets.symmetric(vertical: 12.0),
								child: Row(
									children: [
										Expanded(child: Divider(color: Colors.grey.shade300)),
										Padding(
											padding: const EdgeInsets.symmetric(horizontal: 10.0),
											child: Text(
												'o',
												style: TextStyle(color: Colors.grey.shade500, fontSize: 13.0),
											),
										),
										Expanded(child: Divider(color: Colors.grey.shade300)),
									],
								),
							),
						],
						TextField(
							controller: _codigoController,
							focusNode: _codigoFocus,
							autofocus: _perfilesBiometricos.isEmpty,
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
								hintText: 'ADM001',
								prefixIcon: const Icon(Icons.person_outline),
								suffixIcon: _codigoFocus.hasFocus
									? IconButton(
										icon: const Icon(Icons.keyboard_hide),
										tooltip: 'Ocultar teclado',
										onPressed: () => ocultarTeclado(context),
									)
									: null,
								border: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12.0),
								),
								filled: true,
							),
							onSubmitted: (_) {
								ocultarTeclado(context);
								_continuarIdentificacion();
							},
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

	Widget _seccionAccesoBiometrico(BuildContext context) {
		if (_perfilesBiometricos.length == 1) {
			final perfil = _perfilesBiometricos.first;
			return SizedBox(
				width: double.infinity,
				height: 52.0,
				child: FilledButton.tonalIcon(
					onPressed: _validando ? null : () => _iniciarConBiometria(perfil.usuarioId),
					icon: const Icon(Icons.face_unlock_outlined),
					label: Text(perfil.nombre),
				),
			);
		}
		return Column(
			children: _perfilesBiometricos.map((perfil) {
				return Padding(
					padding: const EdgeInsets.only(bottom: 8.0),
					child: ListTile(
						shape: RoundedRectangleBorder(
							borderRadius: BorderRadius.circular(12.0),
							side: BorderSide(color: Colors.grey.shade300),
						),
						leading: CircleAvatar(
							backgroundColor: PosiaColors.cobrar.withValues(alpha: 0.12),
							child: const Icon(Icons.face_unlock_outlined, color: PosiaColors.cobrar),
						),
						title: Text(perfil.nombre),
						trailing: const Icon(Icons.chevron_right),
						onTap: _validando ? null : () => _iniciarConBiometria(perfil.usuarioId),
					),
				);
			}).toList(),
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
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								CircleAvatar(
									backgroundColor: colorRol.withValues(alpha: 0.12),
									radius: 28.0,
									child: Icon(
										PresentacionRol.icono(usuario.rol),
										color: colorRol,
										size: 28.0,
									),
								),
							],
						),
						const SizedBox(height: 8.0),
						Center(child: InsigniaRol(rol: usuario.rol, compacto: true)),
						const SizedBox(height: 16.0),
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
												autofocusTeclado: true,
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

	Future<void> _iniciarConBiometria(String usuarioId) async {
		setState(() {
			_validando = true;
			_mensajeError = null;
		});
		try {
			final perfil = await _gestorBiometria.autenticarYRecuperar(
				usuarioId: usuarioId,
			);
			if (perfil == null) {
				if (mounted) {
					setState(() => _mensajeError = '$_etiquetaBiometria no disponible');
				}
				return;
			}
			final auth = await ref.read(servicioAutenticacionProvider.future);
			final intento = await auth.autenticar(perfil.codigo, perfil.pin);
			if (!intento.exitoso) {
				if (!mounted) {
					return;
				}
				await _gestorBiometria.eliminarPerfil(perfil.usuarioId);
				await _prepararBiometria();
				setState(() {
					_mensajeError = intento.motivoFallo?.mensajeUsuario ??
						'PIN desactualizado';
				});
				return;
			}
			final usuario = await ServicioInicioSesion.completar(
				ref,
				intento.resultado!,
				pinPlano: perfil.pin,
			);
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('Hola, ${usuario.nombre}'),
					backgroundColor: PresentacionRol.color(usuario.rol),
					duration: const Duration(seconds: 2),
				),
			);
		} on Object catch (error) {
			if (mounted) {
				setState(() => _mensajeError = '$error');
			}
		} finally {
			if (mounted) {
				setState(() => _validando = false);
			}
		}
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
		try {
			final auth = await ref.read(servicioAutenticacionProvider.future);
			final busqueda = await auth.buscarPerfilPorCodigo(codigo);
			if (!mounted) {
				return;
			}
			if (!busqueda.exitoso) {
				setState(() {
					_mensajeError = busqueda.motivoFallo?.mensajeUsuario ?? 'Usuario no encontrado';
				});
				return;
			}
			final usuario = busqueda.usuario!;
			setState(() {
				_usuarioIdentificado = usuario;
				_paso = _PasoInicioSesion.contrasena;
				_pinIngresado = '';
				_mensajeError = null;
			});
		} finally {
			if (mounted) {
				setState(() => _validando = false);
			}
		}
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

		try {
			final auth = await ref.read(servicioAutenticacionProvider.future);
			final intento = await auth.autenticar(codigo, pin);

			if (!intento.exitoso) {
				if (!mounted) {
					return;
				}
				setState(() {
					_pinIngresado = '';
					_mensajeError = intento.motivoFallo?.mensajeUsuario ?? 'Contraseña incorrecta';
				});
				return;
			}

			final registrarBiometria = esPlataformaMovilNativa();
			final usuario = await ServicioInicioSesion.completar(
				ref,
				intento.resultado!,
				pinPlano: pin,
				registrarBiometria: registrarBiometria,
			);

			if (!mounted) {
				return;
			}
			if (registrarBiometria) {
				await _prepararBiometria();
			}
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						registrarBiometria && _biometriaDisponible
							? 'Hola, ${usuario.nombre}'
							: 'Hola, ${usuario.nombre}',
					),
					backgroundColor: PresentacionRol.color(usuario.rol),
					duration: const Duration(seconds: 2),
				),
			);
		} on Object catch (error) {
			if (!mounted) {
				return;
			}
			setState(() {
				_pinIngresado = '';
				_mensajeError = '$error';
			});
		} finally {
			if (mounted) {
				setState(() => _validando = false);
			}
		}
	}
}
