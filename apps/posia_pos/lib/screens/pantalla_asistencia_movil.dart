/// Asistencia móvil: PIN, GPS y biometría.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_ui/posia_ui.dart';

import '../providers/app_providers.dart';
import '../services/gestor_acceso_biometrico.dart';
import '../util/teclado_util.dart';
import '../util/ubicacion_util.dart';

class PantallaAsistenciaMovil extends ConsumerStatefulWidget {
  const PantallaAsistenciaMovil({super.key});

  @override
  ConsumerState<PantallaAsistenciaMovil> createState() =>
      _PantallaAsistenciaMovilState();
}

class _PantallaAsistenciaMovilState
    extends ConsumerState<PantallaAsistenciaMovil> {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  final _gestorBiometria = GestorAccesoBiometrico();
  RegistroAsistencia? _entradaAbierta;
  bool _cargando = false;
  Timer? _prefetchPin;
  bool _prefetchEnCurso = false;

  @override
  void initState() {
    super.initState();
    _pinFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarEstado());
    // Baja PINs recien generados en admin sin esperar el ciclo de 60 s.
    _prefetchPin = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_prefetchDesafioPin());
    });
    unawaited(_prefetchDesafioPin());
  }

  @override
  void dispose() {
    _prefetchPin?.cancel();
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _prefetchDesafioPin() async {
    if (!mounted || _entradaAbierta != null || _prefetchEnCurso) {
      return;
    }
    _prefetchEnCurso = true;
    try {
      final contenedor = await ref.read(contenedorServiciosProvider.future);
      final sync = contenedor.syncOrchestrator;
      // Atajo al espejo del hub; el pull completo es respaldo si la ruta
      // aun no esta desplegada.
      final ok = await sync.traerDesafioAsistenciaActivo();
      if (!ok) {
        await sync.traerCambiosRapido();
      }
    } on Object {
      // Best-effort: al marcar se reintenta.
    } finally {
      _prefetchEnCurso = false;
    }
  }

  Future<void> _cargarEstado() async {
    final usuario = ref.read(sesionUsuarioProvider);
    if (usuario == null) {
      return;
    }
    final contenedor = await ref.read(contenedorServiciosProvider.future);
    final abierta = await contenedor.servicioAsistencia?.obtenerEntradaAbierta(
      usuario.id,
    );
    if (mounted) {
      setState(() => _entradaAbierta = abierta);
    }
  }

  Future<Position?> _obtenerUbicacion() async {
    try {
      return await obtenerUbicacionActual();
    } on StateError {
      rethrow;
    }
  }

  Future<void> _entradaConPin() async {
    final usuario = ref.read(sesionUsuarioProvider);
    if (usuario == null) {
      return;
    }
    setState(() => _cargando = true);
    try {
      final pos = await _obtenerUbicacion();
      if (pos == null) {
        return;
      }
      final contenedor = await ref.read(contenedorServiciosProvider.future);
      final asistencia = contenedor.servicioAsistencia;
      if (asistencia == null) {
        throw StateError('Servicio de asistencia no disponible');
      }
      await asistencia.registrarEntradaConPin(
        usuarioId: usuario.id,
        pin: _pinController.text.trim(),
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
      _pinController.clear();
      await _cargarEstado();
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(
          content: Text('Entrada registrada'),
          backgroundColor: PosiaColors.cobrar,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        SnackBar(
          content: Text('$error'),
          backgroundColor: PosiaColors.cancelar,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _entradaBiometrica() async {
    final usuario = ref.read(sesionUsuarioProvider);
    if (usuario == null) {
      return;
    }
    final puede = await _gestorBiometria.estaDisponible();
    if (!puede) {
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(content: Text('Biometría no disponible')),
      );
      return;
    }
    final ok = await _gestorBiometria.autenticarDispositivo(
      'Confirma tu identidad',
    );
    if (!ok) {
      return;
    }
    setState(() => _cargando = true);
    try {
      final pos = await _obtenerUbicacion();
      if (pos == null) {
        return;
      }
      final contenedor = await ref.read(contenedorServiciosProvider.future);
      final asistencia = contenedor.servicioAsistencia;
      if (asistencia == null) {
        throw StateError('Servicio de asistencia no disponible');
      }
      await asistencia.registrarEntradaBiometrica(
        usuarioId: usuario.id,
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
      await _cargarEstado();
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(
          content: Text('Entrada registrada'),
          backgroundColor: PosiaColors.cobrar,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        SnackBar(
          content: Text('$error'),
          backgroundColor: PosiaColors.cancelar,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _registrarSalida() async {
    final usuario = ref.read(sesionUsuarioProvider);
    if (usuario == null) {
      return;
    }
    setState(() => _cargando = true);
    try {
      final contenedor = await ref.read(contenedorServiciosProvider.future);
      final asistencia = contenedor.servicioAsistencia;
      if (asistencia == null) {
        throw StateError('Servicio de asistencia no disponible');
      }
      await asistencia.registrarSalida(usuario.id);
      await _cargarEstado();
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(
          content: Text('Salida registrada'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        SnackBar(
          content: Text('$error'),
          backgroundColor: PosiaColors.cancelar,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final abierta = _entradaAbierta;
    return GestureDetector(
      onTap: () => ocultarTeclado(context),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Asistencia')),
        body: CuerpoScrollTeclado(
          padding: const EdgeInsets.all(16.0),
          alinearAlCentroCuandoCabe: true,
          child: abierta != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: PosiaColors.cobrar,
                      size: 72.0,
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      abierta.entradaEn.toLocal().toString().substring(11, 16),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24.0),
                    FilledButton.icon(
                      onPressed: _cargando ? null : _registrarSalida,
                      icon: const Icon(Icons.logout),
                      label: const Text('Salida'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _cargando ? null : _entradaBiometrica,
                      icon: const Icon(Icons.fingerprint, size: 28.0),
                      label: const Text('Entrada biométrica'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56.0),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(
                            'o',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                    TextField(
                      controller: _pinController,
                      focusNode: _pinFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24.0,
                        letterSpacing: 8.0,
                        fontWeight: FontWeight.bold,
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 120.0),
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: FilledButton(
                        onPressed: _cargando ? null : _entradaConPin,
                        child: _cargando
                            ? const SizedBox(
                                height: 20.0,
                                width: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              )
                            : const Text('Entrada con PIN'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
