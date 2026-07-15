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

enum _PasoInicioSesion { identificacion, contrasena }

/// Pantalla de autenticacion con flujo por rol.
class PantallaInicioSesion extends ConsumerStatefulWidget {
  const PantallaInicioSesion({super.key});

  @override
  ConsumerState<PantallaInicioSesion> createState() =>
      _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends ConsumerState<PantallaInicioSesion> {
  final _codigoController = TextEditingController();
  final _codigoFocus = FocusNode();
  final _pinController = TextEditingController();
  final _gestorBiometria = GestorAccesoBiometrico();
  _PasoInicioSesion _paso = _PasoInicioSesion.identificacion;
  Usuario? _usuarioIdentificado;
  String? _mensajeError;
  bool _validando = false;
  bool _biometriaDisponible = false;
  List<PerfilAccesoBiometrico> _perfilesBiometricos = [];
  bool _intentoBiometricoAutomatico = false;

  @override
  void initState() {
    super.initState();
    _codigoFocus.addListener(() => setState(() {}));
    _pinController.addListener(_revisarPinCompleto);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepararBiometria());
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _codigoFocus.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _revisarPinCompleto() {
    if (_validando || _paso != _PasoInicioSesion.contrasena) {
      return;
    }
    if (_pinController.text.length >= LONGITUD_PIN_ADMIN) {
      _validarAcceso();
    }
  }

  Future<void> _prepararBiometria() async {
    if (!esPlataformaMovilNativa()) {
      return;
    }
    final configRepo = await ref.read(configDispositivoRepoProvider.future);
    await configRepo.obtenerConfigDispositivo();
    final disponible = await _gestorBiometria.estaDisponible();
    final perfiles = await _gestorBiometria.listarPerfiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _biometriaDisponible = disponible;
      _perfilesBiometricos = perfiles;
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
          pie: _paso == _PasoInicioSesion.contrasena
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton.icon(
                      onPressed: _validando ? null : _volverIdentificacion,
                      icon: const Icon(Icons.arrow_back, size: 20.0),
                      label: const Text('Atrás'),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
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
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13.0,
                        ),
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
                prefixIcon: const Icon(Icons.person_outline),
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
          onPressed: _validando
              ? null
              : () => _iniciarConBiometria(perfil.usuarioId),
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
              child: const Icon(
                Icons.face_unlock_outlined,
                color: PosiaColors.cobrar,
              ),
            ),
            title: Text(perfil.nombre),
            trailing: const Icon(Icons.chevron_right),
            onTap: _validando
                ? null
                : () => _iniciarConBiometria(perfil.usuarioId),
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
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: CircularProgressIndicator(),
              )
            else
              CampoSecreto(
                controller: _pinController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: LONGITUD_PIN_ADMIN,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: '',
                  helperText: 'Enter confirma · Esc atrás',
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
          _mensajeError = intento.mensajeUsuario;
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
      PosiaNotificaciones.mostrarSnackBar(
        context,
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
          _mensajeError = busqueda.mensajeUsuario;
        });
        return;
      }
      final usuario = busqueda.usuario!;
      setState(() {
        _usuarioIdentificado = usuario;
        _paso = _PasoInicioSesion.contrasena;
        _pinController.clear();
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
      _pinController.clear();
      _mensajeError = null;
    });
  }

  Future<void> _validarAcceso() async {
    final codigo = ValidadorCodigoUsuario.normalizar(_codigoController.text);
    final pin = _pinController.text;
    setState(() => _validando = true);

    try {
      final auth = await ref.read(servicioAutenticacionProvider.future);
      final intento = await auth.autenticar(codigo, pin);

      if (!intento.exitoso) {
        if (!mounted) {
          return;
        }
        setState(() {
          _pinController.clear();
          _mensajeError = intento.mensajeUsuario;
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
      PosiaNotificaciones.mostrarSnackBar(
        context,
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
        _pinController.clear();
        _mensajeError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() => _validando = false);
      }
    }
  }
}
