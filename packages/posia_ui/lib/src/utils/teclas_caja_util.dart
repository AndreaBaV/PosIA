/// Utilidades para atajos de teclado configurables en caja.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Valor historico por defecto (F12 suele estar bloqueada en Windows).
const String teclaCobrarPredeterminada = 'F2';

/// Identificadores de acciones asignables a atajos.
const String atajoAccionCobrar = 'cobrar';
const String atajoAccionCreditos = 'creditos';
const String atajoAccionAdmin = 'admin';
const String atajoAccionVaciarCarrito = 'vaciar_carrito';
const String atajoAccionPonerEspera = 'poner_espera';
const String atajoAccionCotizar = 'cotizar';
const String atajoAccionRecuperarEspera = 'recuperar_espera';

/// Metadatos de una accion configurable.
class DefinicionAtajoCaja {
	const DefinicionAtajoCaja({
		required this.id,
		required this.etiqueta,
		required this.descripcion,
		required this.valorPredeterminado,
	});

	final String id;
	final String etiqueta;
	final String descripcion;
	final String valorPredeterminado;
}

/// Acciones disponibles para personalizar en Admin.
const List<DefinicionAtajoCaja> definicionesAtajosCaja = [
	DefinicionAtajoCaja(
		id: atajoAccionCobrar,
		etiqueta: 'Cobrar',
		descripcion: 'Abrir el dialogo de cobro desde caja',
		valorPredeterminado: 'F2',
	),
	DefinicionAtajoCaja(
		id: atajoAccionCreditos,
		etiqueta: 'Creditos',
		descripcion: 'Abrir pendientes por cobrar (Admin)',
		valorPredeterminado: 'CTRL+T',
	),
	DefinicionAtajoCaja(
		id: atajoAccionAdmin,
		etiqueta: 'Panel Admin',
		descripcion: 'Cambiar a la pestana de administracion',
		valorPredeterminado: 'CTRL+SHIFT+A',
	),
	DefinicionAtajoCaja(
		id: atajoAccionPonerEspera,
		etiqueta: 'Poner en espera',
		descripcion: 'Apartar el carrito actual',
		valorPredeterminado: 'CTRL+P',
	),
	DefinicionAtajoCaja(
		id: atajoAccionRecuperarEspera,
		etiqueta: 'Recuperar en espera',
		descripcion: 'Mostrar tickets apartados',
		valorPredeterminado: 'CTRL+R',
	),
	DefinicionAtajoCaja(
		id: atajoAccionCotizar,
		etiqueta: 'Cotizar',
		descripcion: 'Generar cotizacion del carrito',
		valorPredeterminado: 'CTRL+Q',
	),
	DefinicionAtajoCaja(
		id: atajoAccionVaciarCarrito,
		etiqueta: 'Vaciar carrito',
		descripcion: 'Pedir confirmacion y vaciar el carrito',
		valorPredeterminado: 'CTRL+DELETE',
	),
];

/// Mapa de atajos persistido en configuracion local.
class AtajosCajaConfig {
	const AtajosCajaConfig(this.valores);

	final Map<String, String> valores;

	static AtajosCajaConfig predeterminados() {
		return AtajosCajaConfig({
			for (final def in definicionesAtajosCaja) def.id: def.valorPredeterminado,
		});
	}

	factory AtajosCajaConfig.desdeJson(String? json, {String? teclaCobrarLegacy}) {
		final base = predeterminados();
		if (json == null || json.trim().isEmpty) {
			if (teclaCobrarLegacy != null && teclaCobrarLegacy.trim().isNotEmpty) {
				return base.conAtajo(atajoAccionCobrar, teclaCobrarLegacy);
			}
			return base;
		}
		try {
			final decodificado = jsonDecode(json);
			if (decodificado is! Map) {
				return base;
			}
			final fusionado = Map<String, String>.from(base.valores);
			for (final entrada in decodificado.entries) {
				final clave = entrada.key.toString();
				final valor = entrada.value?.toString().trim().toUpperCase() ?? '';
				if (valor.isNotEmpty) {
					fusionado[clave] = valor;
				}
			}
			return AtajosCajaConfig(fusionado);
		} catch (_) {
			return base;
		}
	}

	String aJson() => jsonEncode(valores);

	String atajo(String accion) {
		final valor = valores[accion]?.trim().toUpperCase();
		if (valor != null && valor.isNotEmpty) {
			return valor;
		}
		return predeterminados().valores[accion] ?? '';
	}

	AtajosCajaConfig conAtajo(String accion, String atajo) {
		final copia = Map<String, String>.from(valores);
		copia[accion] = atajo.trim().toUpperCase();
		return AtajosCajaConfig(copia);
	}

	AtajosCajaConfig copiarCon(Map<String, String> cambios) {
		final copia = Map<String, String>.from(valores);
		for (final entrada in cambios.entries) {
			copia[entrada.key] = entrada.value.trim().toUpperCase();
		}
		return AtajosCajaConfig(copia);
	}
}

/// Representacion interna de un atajo con modificadores.
class _AtajoParseado {
	const _AtajoParseado({
		required this.ctrl,
		required this.alt,
		required this.shift,
		required this.meta,
		required this.tecla,
	});

	final bool ctrl;
	final bool alt;
	final bool shift;
	final bool meta;
	final LogicalKeyboardKey tecla;
}

_AtajoParseado _parsearAtajo(String? valor) {
	final texto = (valor ?? '').trim().toUpperCase();
	if (texto.isEmpty) {
		return const _AtajoParseado(
			ctrl: false,
			alt: false,
			shift: false,
			meta: false,
			tecla: LogicalKeyboardKey.f2,
		);
	}
	final partes = texto.split('+').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
	if (partes.isEmpty) {
		return const _AtajoParseado(
			ctrl: false,
			alt: false,
			shift: false,
			meta: false,
			tecla: LogicalKeyboardKey.f2,
		);
	}
	var ctrl = false;
	var alt = false;
	var shift = false;
	var meta = false;
	while (partes.length > 1 && _esModificador(partes.first)) {
		_aplicarModificador(partes.removeAt(0), (c, a, s, m) {
			ctrl = ctrl || c;
			alt = alt || a;
			shift = shift || s;
			meta = meta || m;
		});
	}
	final tecla = _resolverTeclaPrincipal(partes.join('+'));
	return _AtajoParseado(
		ctrl: ctrl,
		alt: alt,
		shift: shift,
		meta: meta,
		tecla: tecla,
	);
}

void _aplicarModificador(
	String parte,
	void Function(bool ctrl, bool alt, bool shift, bool meta) aplicar,
) {
	switch (parte) {
		case 'CTRL':
		case 'CONTROL':
		case 'CTL':
			aplicar(true, false, false, false);
		case 'ALT':
		case 'OPTION':
			aplicar(false, true, false, false);
		case 'SHIFT':
			aplicar(false, false, true, false);
		case 'META':
		case 'WIN':
		case 'CMD':
		case 'COMMAND':
			aplicar(false, false, false, true);
		default:
			break;
	}
}

bool _esModificador(String parte) {
	return switch (parte) {
		'CTRL' || 'CONTROL' || 'CTL' || 'ALT' || 'OPTION' || 'SHIFT' || 'META' || 'WIN' || 'CMD' || 'COMMAND' => true,
		_ => false,
	};
}

LogicalKeyboardKey _resolverTeclaPrincipal(String parte) {
	final texto = parte.trim().toUpperCase();
	if (texto.isEmpty) {
		return LogicalKeyboardKey.f2;
	}
	final funcion = RegExp(r'^F(\d{1,2})$').firstMatch(texto);
	if (funcion != null) {
		final numero = int.tryParse(funcion.group(1)!);
		if (numero != null && numero >= 1 && numero <= 24) {
			return switch (numero) {
				1 => LogicalKeyboardKey.f1,
				2 => LogicalKeyboardKey.f2,
				3 => LogicalKeyboardKey.f3,
				4 => LogicalKeyboardKey.f4,
				5 => LogicalKeyboardKey.f5,
				6 => LogicalKeyboardKey.f6,
				7 => LogicalKeyboardKey.f7,
				8 => LogicalKeyboardKey.f8,
				9 => LogicalKeyboardKey.f9,
				10 => LogicalKeyboardKey.f10,
				11 => LogicalKeyboardKey.f11,
				12 => LogicalKeyboardKey.f12,
				13 => LogicalKeyboardKey.f13,
				14 => LogicalKeyboardKey.f14,
				15 => LogicalKeyboardKey.f15,
				16 => LogicalKeyboardKey.f16,
				17 => LogicalKeyboardKey.f17,
				18 => LogicalKeyboardKey.f18,
				19 => LogicalKeyboardKey.f19,
				20 => LogicalKeyboardKey.f20,
				21 => LogicalKeyboardKey.f21,
				22 => LogicalKeyboardKey.f22,
				23 => LogicalKeyboardKey.f23,
				_ => LogicalKeyboardKey.f24,
			};
		}
	}
	return switch (texto) {
		'ESCAPE' || 'ESC' => LogicalKeyboardKey.escape,
		'ENTER' || 'RETURN' => LogicalKeyboardKey.enter,
		'DELETE' || 'DEL' => LogicalKeyboardKey.delete,
		'BACKSPACE' => LogicalKeyboardKey.backspace,
		'SPACE' || 'ESPACIO' => LogicalKeyboardKey.space,
		'TAB' => LogicalKeyboardKey.tab,
		'INSERT' || 'INS' => LogicalKeyboardKey.insert,
		'HOME' => LogicalKeyboardKey.home,
		'END' => LogicalKeyboardKey.end,
		'PAGEUP' || 'PGUP' => LogicalKeyboardKey.pageUp,
		'PAGEDOWN' || 'PGDN' => LogicalKeyboardKey.pageDown,
		_ => _buscarTeclaPorEtiqueta(texto),
	};
}

LogicalKeyboardKey _buscarTeclaPorEtiqueta(String etiqueta) {
	for (final tecla in LogicalKeyboardKey.knownLogicalKeys) {
		if (tecla.keyLabel.toUpperCase() == etiqueta) {
			return tecla;
		}
	}
	return LogicalKeyboardKey.f2;
}

bool _esTeclaModificadora(LogicalKeyboardKey tecla) {
	return tecla == LogicalKeyboardKey.controlLeft ||
		tecla == LogicalKeyboardKey.controlRight ||
		tecla == LogicalKeyboardKey.altLeft ||
		tecla == LogicalKeyboardKey.altRight ||
		tecla == LogicalKeyboardKey.shiftLeft ||
		tecla == LogicalKeyboardKey.shiftRight ||
		tecla == LogicalKeyboardKey.metaLeft ||
		tecla == LogicalKeyboardKey.metaRight;
}

/// Indica si el evento coincide con el atajo configurado.
bool coincideAtajoConfigurado(KeyEvent event, String? atajoConfig) {
	if (event is! KeyDownEvent) {
		return false;
	}
	if (_esTeclaModificadora(event.logicalKey)) {
		return false;
	}
	final esperado = _parsearAtajo(atajoConfig);
	if (event.logicalKey != esperado.tecla) {
		return false;
	}
	final teclado = HardwareKeyboard.instance;
	return esperado.ctrl == teclado.isControlPressed &&
		esperado.alt == teclado.isAltPressed &&
		esperado.shift == teclado.isShiftPressed &&
		esperado.meta == teclado.isMetaPressed;
}

/// Convierte un evento de teclado a cadena guardable (CTRL+T, F2, etc.).
String serializarAtajoDesdeEvento(KeyEvent event) {
	if (event is! KeyDownEvent || _esTeclaModificadora(event.logicalKey)) {
		return '';
	}
	final partes = <String>[];
	final teclado = HardwareKeyboard.instance;
	if (teclado.isControlPressed) {
		partes.add('CTRL');
	}
	if (teclado.isAltPressed) {
		partes.add('ALT');
	}
	if (teclado.isShiftPressed) {
		partes.add('SHIFT');
	}
	if (teclado.isMetaPressed) {
		partes.add('META');
	}
	partes.add(_etiquetaTeclaPrincipal(event.logicalKey));
	return partes.join('+');
}

String _etiquetaTeclaPrincipal(LogicalKeyboardKey tecla) {
	if (tecla == LogicalKeyboardKey.escape) {
		return 'ESCAPE';
	}
	if (tecla == LogicalKeyboardKey.enter || tecla == LogicalKeyboardKey.numpadEnter) {
		return 'ENTER';
	}
	if (tecla == LogicalKeyboardKey.delete) {
		return 'DELETE';
	}
	if (tecla == LogicalKeyboardKey.insert) {
		return 'INSERT';
	}
	final etiqueta = tecla.keyLabel.toUpperCase();
	if (etiqueta.isNotEmpty) {
		return etiqueta;
	}
	return 'F2';
}

/// Etiqueta legible del atajo para mostrar en UI.
String etiquetaAtajoConfigurado(String? valor) {
	final texto = (valor ?? '').trim().toUpperCase();
	return texto.isEmpty ? teclaCobrarPredeterminada : texto;
}

/// Compatibilidad con configuracion antigua (solo tecla cobrar).
LogicalKeyboardKey parsearTeclaConfigurada(String? valor) {
	return _parsearAtajo(valor ?? teclaCobrarPredeterminada).tecla;
}

/// Etiqueta legible de la tecla configurada (compatibilidad).
String etiquetaTeclaConfigurada(String? valor) {
	return etiquetaAtajoConfigurado(valor);
}

/// Indica si hay un dialogo modal con foco (no disparar atajos globales).
bool hayDialogoModalConFoco() {
	final foco = FocusManager.instance.primaryFocus;
	final contexto = foco?.context;
	if (contexto == null || !foco!.hasFocus) {
		return false;
	}
	if (contexto.findAncestorWidgetOfExactType<Dialog>() != null) {
		return true;
	}
	final ruta = ModalRoute.of(contexto);
	return ruta is PopupRoute;
}
