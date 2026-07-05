/// Interpreta texto en espanol mexicano a lineas de venta.
library;

import 'package:posia_core/posia_core.dart';

import 'intencion_comando_voz.dart';
import 'linea_comando_voz.dart';

/// Resultado del analisis sintactico de un comando hablado.
class InterpretacionVoz {
  const InterpretacionVoz({
    required this.intencion,
    required this.lineas,
    required this.textoLimpio,
    this.nombreClienteSolicitado,
    this.usarMostrador = false,
  });

  final IntencionComandoVoz intencion;
  final List<LineaComandoVoz> lineas;
  final String textoLimpio;

  /// Nombre hablado del cliente (sin resolver contra catalogo).
  final String? nombreClienteSolicitado;

  /// Indica venta a mostrador sin cliente asignado.
  final bool usarMostrador;
}

/// Convierte transcripcion STT a intencion y lineas de producto.
class InterpretadorComandosVoz {
  static const Map<String, double> _numeros = {
    'un': 1,
    'una': 1,
    'uno': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
    'once': 11,
    'doce': 12,
    'medio': 0.5,
    'media': 0.5,
    'mitad': 0.5,
  };

  static final RegExp _prefijosTicket = RegExp(
    r'^(?:genera(?:r)?\s+(?:el\s+)?ticket|'
    r'arma(?:r)?\s+(?:el\s+)?ticket|'
    r'vend[ií](?:\s+lo\s+siguiente)?|'
    r'agrega(?:r)?|'
    r'pon(?:er)?|'
    r'anota(?:r)?)\s*:?\s*',
    caseSensitive: false,
  );

  static final RegExp _inicioNuevaLinea = RegExp(
    r'(?=\s+(?:\d+|[\d]+[.,][\d]+|'
    r'un[ao]?|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|'
    r'medio|media|mitad)\b)',
    caseSensitive: false,
  );

  static final RegExp _mostrador = RegExp(
    r'\b(?:mostrador|sin\s+cliente|cliente\s+mostrador)\b',
    caseSensitive: false,
  );

  static final RegExp _mencionCliente = RegExp(
    r'(?:para\s+(?:el\s+)?cliente|a\s+nombre\s+de)\s+'
    r'(?<nombre>.+?)'
    r'(?:\s*:\s*|\s+(?=vendi|vende|agrega|agregar|pon|poner|anota|anotar|'
    r'\d|un[ao]?|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|'
    r'medio|media|mitad)\b)',
    caseSensitive: false,
  );

  static final RegExp _mencionClienteInicial = RegExp(
    r'^cliente\s+(?<nombre>.+?)'
    r'(?:\s*:\s*|\s+(?=vendi|vende|agrega|agregar|pon|poner|anota|anotar|'
    r'\d|un[ao]?|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|'
    r'medio|media|mitad)\b)',
    caseSensitive: false,
  );

  static final RegExp _patronLinea = RegExp(
    r'^(?:(?<cantidad>[\d]+(?:[.,]\d+)?|'
    r'un[ao]?|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|'
    r'medio|media|mitad)\s+)?'
    r'(?:(?<unidad>kilo(?:gramo)?s?|kg|gramo?s?|g|litro?s?|l|'
    r'caja?s?|cart[oó]n(?:es)?|pieza?s?|pza?s?|lata?s?)\s+(?:de\s+)?)?'
    r'(?<producto>.+)$',
    caseSensitive: false,
  );

  /// Analiza texto completo del comando de voz.
  InterpretacionVoz interpretar(String textoOriginal) {
    var texto = _normalizar(textoOriginal);
    if (texto.isEmpty) {
      return const InterpretacionVoz(
        intencion: IntencionComandoVoz.desconocido,
        lineas: [],
        textoLimpio: '',
      );
    }

    final intencion = _detectarIntencion(texto);
    if (intencion == IntencionComandoVoz.cobrar ||
        intencion == IntencionComandoVoz.vaciarCarrito) {
      return InterpretacionVoz(
        intencion: intencion,
        lineas: const [],
        textoLimpio: texto,
      );
    }

    final clienteExtraido = _extraerCliente(texto);
    texto = clienteExtraido.textoProductos;
    texto = texto.replaceFirst(_prefijosTicket, '');
    final segmentos = _dividirSegmentos(texto);
    final lineas = <LineaComandoVoz>[];
    for (final segmento in segmentos) {
      final linea = _parsearSegmento(segmento);
      if (linea != null) {
        lineas.add(linea);
      }
    }

    return InterpretacionVoz(
      intencion: lineas.isEmpty && !clienteExtraido.tieneCliente
          ? IntencionComandoVoz.desconocido
          : IntencionComandoVoz.agregarProductos,
      lineas: lineas,
      textoLimpio: texto,
      nombreClienteSolicitado: clienteExtraido.nombreCliente,
      usarMostrador: clienteExtraido.usarMostrador,
    );
  }

  /// Separa mencion de cliente del resto del comando de productos.
  ({
    String textoProductos,
    String? nombreCliente,
    bool usarMostrador,
    bool tieneCliente,
  })
  _extraerCliente(String texto) {
    var restante = texto.trim();
    var usarMostrador = false;
    String? nombreCliente;

    if (_mostrador.hasMatch(restante)) {
      usarMostrador = true;
      restante = restante.replaceAll(_mostrador, ' ').trim();
    }

    final match =
        _mencionCliente.firstMatch(restante) ??
        _mencionClienteInicial.firstMatch(restante);
    if (match != null) {
      nombreCliente = match.namedGroup('nombre')?.trim();
      restante =
          '${restante.substring(0, match.start)} '
                  '${restante.substring(match.end)}'
              .replaceAll(RegExp(r'\s{2,}'), ' ')
              .trim();
    }

    return (
      textoProductos: restante,
      nombreCliente: nombreCliente?.isNotEmpty == true ? nombreCliente : null,
      usarMostrador: usarMostrador,
      tieneCliente: usarMostrador || (nombreCliente?.isNotEmpty ?? false),
    );
  }

  IntencionComandoVoz _detectarIntencion(String texto) {
    if (RegExp(
      r'\b(?:cobrar|cobr[aá]|cobra|cierra(?:r)?\s+la\s+venta|efectivo|liquida(?:r)?)\b',
      caseSensitive: false,
    ).hasMatch(texto)) {
      return IntencionComandoVoz.cobrar;
    }
    if (RegExp(
      r'\b(?:vac[ií]a(?:r)?\s+(?:el\s+)?carrito|cancela(?:r)?\s+(?:la\s+)?venta)\b',
      caseSensitive: false,
    ).hasMatch(texto)) {
      return IntencionComandoVoz.vaciarCarrito;
    }
    return IntencionComandoVoz.agregarProductos;
  }

  List<String> _dividirSegmentos(String texto) {
    final primarios = texto
        .split(
          RegExp(r'\s+y\s+|\s+e\s+|,|;\s*|\s+adem[aá]s\s+|\s+tambi[eé]n\s+'),
        )
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final resultado = <String>[];
    for (final segmento in primarios) {
      final sinPrefijo = segmento.replaceFirst(
        RegExp(
          r'^(?:vendi|vende|agrega|agregar|pon|poner|anota|anotar)\s+',
          caseSensitive: false,
        ),
        '',
      );
      resultado.addAll(_dividirPorCantidades(sinPrefijo));
    }
    return resultado;
  }

  List<String> _dividirPorCantidades(String segmento) {
    final partes = segmento.split(_inicioNuevaLinea);
    return partes.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  LineaComandoVoz? _parsearSegmento(String segmento) {
    var limpio = segmento.trim();
    limpio = limpio.replaceFirst(
      RegExp(
        r'^(?:vendi|vende|agrega|agregar|pon|poner|anota|anotar)\s+',
        caseSensitive: false,
      ),
      '',
    );
    limpio = limpio.replaceFirst(
      RegExp(r'^(?:de|del|la|el)\s+', caseSensitive: false),
      '',
    );
    final match = _patronLinea.firstMatch(limpio);
    if (match == null) {
      return null;
    }
    final cantidadRaw = match.namedGroup('cantidad');
    final unidadRaw = match.namedGroup('unidad');
    final producto = match.namedGroup('producto')?.trim() ?? '';
    if (producto.isEmpty) {
      return null;
    }
    return LineaComandoVoz(
      nombreProducto: producto,
      cantidadHablada: _parsearCantidad(cantidadRaw),
      unidadHablada: _parsearUnidad(unidadRaw),
    );
  }

  double _parsearCantidad(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 1.0;
    }
    final normalizado = raw.toLowerCase().replaceAll(',', '.');
    final numero = double.tryParse(normalizado);
    if (numero != null) {
      return numero;
    }
    return _numeros[normalizado] ?? 1.0;
  }

  UnidadMedida? _parsearUnidad(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final u = raw.toLowerCase();
    if (u.startsWith('kilo') || u == 'kg' || u.startsWith('gram')) {
      return UnidadMedida.kilogramo;
    }
    if (u.startsWith('lit') || u == 'l') {
      return UnidadMedida.litro;
    }
    if (u.startsWith('caj') || u.startsWith('cart')) {
      return UnidadMedida.caja;
    }
    if (u.startsWith('lat')) {
      return UnidadMedida.pieza;
    }
    if (u.startsWith('piez') || u.startsWith('pza') || u.startsWith('unidad')) {
      return UnidadMedida.pieza;
    }
    return null;
  }

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }
}
