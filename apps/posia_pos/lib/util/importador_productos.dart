/// Importacion masiva de productos desde CSV o Excel (.xlsx).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';

import 'lector_xlsx.dart';

/// Fila parseada del archivo con validacion previa a la importacion.
class FilaImportacionProducto {
  const FilaImportacionProducto({
    required this.numeroFila,
    required this.nombre,
    required this.errores,
    this.solicitud,
  });

  final int numeroFila;
  final String nombre;
  final List<String> errores;
  final AltaProductoRequest? solicitud;

  bool get valida => errores.isEmpty && solicitud != null;
}

/// Resultado del analisis de un archivo de importacion.
class AnalisisImportacionProductos {
  const AnalisisImportacionProductos({required this.filas, this.errorArchivo});

  final List<FilaImportacionProducto> filas;
  final String? errorArchivo;

  int get totalFilas => filas.length;

  int get filasValidas => filas.where((f) => f.valida).length;

  int get filasConError => filas.where((f) => !f.valida).length;

  bool get archivoValido => errorArchivo == null && filas.isNotEmpty;
}

/// Utilidad para leer plantillas y archivos de productos.
class ImportadorProductos {
  const ImportadorProductos._();

  /// Categoria asignada cuando la columna falta o la celda esta vacia.
  static const categoriaPorDefecto = 'abarrotes';

  static const encabezadosPlantilla = [
    'nombre',
    'codigo_barras',
    'precio_base',
    'costo_unitario',
    'categoria',
    'unidad_medida',
    'stock_inicial',
    'stock_minimo',
    'proveedor',
    'notas',
    'piezas_por_caja',
    'precio_caja',
    'codigo_caja',
    'lote_promocion',
    'unidades_por_bulto',
    'permite_stock_negativo',
  ];

  /// Plantilla para productos por kg con varias presentaciones en gramos.
  /// La categoria es libre (puede ser mixta); lo fijo es unidad kilogramo.
  static const encabezadosPlantillaGranel = [
    'nombre',
    'presentacion_gramos',
    'precio',
    'categoria',
  ];

  static const _aliasColumnas = <String, List<String>>{
    'nombre': ['nombre', 'name', 'producto', 'articulo', 'descripcion'],
    'codigo_barras': [
      'codigo_barras',
      'codigo barras',
      'codigobarras',
      'barcode',
      'sku',
      'ean',
      'upc',
    ],
    'precio_base': [
      'precio_base',
      'precio',
      'precio venta',
      'precio_venta',
      'price',
      'pvp',
    ],
    'presentacion_gramos': [
      'presentacion_gramos',
      'presentacion en gramos',
      'gramos',
      'gr',
      'g',
    ],
    'costo_unitario': ['costo_unitario', 'costo', 'cost', 'costo unitario'],
    'categoria': [
      'categoria',
      'categoría',
      'category',
      'departamento',
      'rubro',
    ],
    'unidad_medida': ['unidad_medida', 'unidad', 'unit', 'uom', 'medida'],
    'stock_inicial': [
      'stock_inicial',
      'stock',
      'existencia',
      'existencias',
      'cantidad',
      'inventario',
    ],
    'stock_minimo': ['stock_minimo', 'minimo', 'stock minimo', 'min'],
    'proveedor': ['proveedor', 'supplier', 'vendor'],
    'notas': ['notas', 'notes', 'comentarios', 'observaciones'],
    'piezas_por_caja': [
      'piezas_por_caja',
      'piezas caja',
      'piezas por caja',
      'piezas_caja',
      'piezascaja',
    ],
    'precio_caja': [
      'precio_caja',
      'precio caja',
      'preciocaja',
      'precio_de_caja',
    ],
    'codigo_caja': [
      'codigo_caja',
      'codigo caja',
      'codigocaja',
      'barcode_caja',
      'upc_caja',
    ],
    'lote_promocion': [
      'lote_promocion',
      'lote promocion',
      'promocion',
      'grupo_promocion',
      'grupo promocion',
    ],
    'unidades_por_bulto': [
      'unidades_por_bulto',
      'unidades bulto',
      'unidades por bulto',
    ],
    'permite_stock_negativo': [
      'permite_stock_negativo',
      'stock negativo',
      'stock_negativo',
    ],
  };

  static String generarPlantillaCsv() {
    final ejemplo = [
      'Coca-Cola 600ml',
      '7501055300034',
      '18.50',
      '12.00',
      'Bebidas',
      'pieza',
      '24',
      '6',
      '',
      '',
      '24',
      '400',
      '',
      '',
      '',
      'no',
    ];
    return [
      encabezadosPlantilla.join(','),
      ejemplo.map(_escaparCsv).join(','),
    ].join('\n');
  }

  /// Plantilla CSV: una fila por presentacion; nombre vacio = misma mercancia.
  /// Categoria opcional/mixta; unidad siempre kilogramo.
  static String generarPlantillaGranelCsv() {
    final ejemplos = [
      ['Paprika', '100', '15', 'Especias'],
      ['', '250', '35', 'Especias'],
      ['Sandia Miguelito', '250', '18', 'Dulces'],
      ['', '1000', '72', 'Dulces'],
      ['Ejemplo sin kilo (500g)', '500', '40', 'Abarrotes'],
    ];
    return [
      encabezadosPlantillaGranel.join(','),
      ...ejemplos.map((f) => f.map(_escaparCsv).join(',')),
    ].join('\n');
  }

  /// Lista nombres de hojas si el archivo es .xlsx.
  static List<String> listarHojasXlsx(Uint8List bytes) =>
      LectorXlsx.listarNombresHojas(bytes);

  static Future<AnalisisImportacionProductos> analizarArchivo({
    required String rutaArchivo,
    required List<Categoria> categorias,
    required List<Proveedor> proveedores,
    required Set<String> codigosBarrasExistentes,
    String? nombreHoja,
  }) async {
    final archivo = File(rutaArchivo);
    if (!await archivo.exists()) {
      return const AnalisisImportacionProductos(
        filas: [],
        errorArchivo: 'No se encontro el archivo seleccionado',
      );
    }
    final bytes = await archivo.readAsBytes();
    return analizarBytes(
      bytes: bytes,
      extension: _extension(rutaArchivo),
      categorias: categorias,
      proveedores: proveedores,
      codigosBarrasExistentes: codigosBarrasExistentes,
      nombreHoja: nombreHoja,
    );
  }

  static AnalisisImportacionProductos analizarBytes({
    required Uint8List bytes,
    required String extension,
    required List<Categoria> categorias,
    required List<Proveedor> proveedores,
    required Set<String> codigosBarrasExistentes,
    String? nombreHoja,
  }) {
    try {
      final filasCrudas = _leerFilas(bytes, extension, nombreHoja: nombreHoja);
      if (filasCrudas.isEmpty) {
        return const AnalisisImportacionProductos(
          filas: [],
          errorArchivo: 'El archivo esta vacio',
        );
      }
      final encabezados = filasCrudas.first
          .map((c) => normalizarTextoBusqueda(c.trim()))
          .toList();
      final mapaColumnas = _mapearColumnas(encabezados);
      if (!mapaColumnas.containsKey('nombre')) {
        return const AnalisisImportacionProductos(
          filas: [],
          errorArchivo:
              'Falta la columna "nombre". Descargue la plantilla e intente de nuevo.',
        );
      }
      if (!mapaColumnas.containsKey('precio_base')) {
        return const AnalisisImportacionProductos(
          filas: [],
          errorArchivo:
              'Falta la columna "precio" (precio_base). '
              'Descargue la plantilla e intente de nuevo.',
        );
      }

      final categoriasPorNombre = {
        for (final c in categorias.where((c) => c.activa))
          normalizarTextoBusqueda(c.nombre): c,
      };
      final proveedoresPorNombre = {
        for (final p in proveedores.where((p) => p.activo))
          normalizarTextoBusqueda(p.nombre): p,
      };

  
      if (mapaColumnas.containsKey('presentacion_gramos')) {
        return _analizarGranel(
          filasCrudas: filasCrudas,
          mapaColumnas: mapaColumnas,
          categoriasPorNombre: categoriasPorNombre,
        );
      }

      final codigosEnArchivo = <String>{};
      final filas = <FilaImportacionProducto>[];
      final metaLotes = <String, ({double cantidadMinima, double precioUnitario})>{};

      for (var i = 1; i < filasCrudas.length; i++) {
        final numeroFila = i + 1;
        final celdas = filasCrudas[i];
        if (_filaVacia(celdas)) {
          continue;
        }
        final valores = _valoresFila(celdas, mapaColumnas);
        final errores = <String>[];
        final nombre = valores['nombre']?.trim() ?? '';
        if (nombre.isEmpty) {
          errores.add('El nombre es obligatorio');
        }

        final categoriaTexto = valores['categoria']?.trim() ?? '';
        final resolucionCategoria = _resolverCategoria(
          texto: categoriaTexto.isEmpty ? null : categoriaTexto,
          categoriasPorNombre: categoriasPorNombre,
        );

        final precioTexto = valores['precio_base']?.trim() ?? '';
        final precioBase = parsearPrecioTexto(precioTexto);
        final costoTexto = valores['costo_unitario']?.trim() ?? '';
        final costo = parsearPrecioTexto(costoTexto) ?? 0.0;
        if (precioBase == null) {
          errores.add('Precio base invalido: "$precioTexto"');
        } else {
          final errorPrecio = errorPrecioVentaDesdeTexto(
            precioTexto,
            costoUnitario: costo,
          );
          if (errorPrecio != null) {
            errores.add(errorPrecio);
          }
        }

        final codigoBarras = valores['codigo_barras']?.trim() ?? '';
        if (codigoBarras.isNotEmpty) {
          final codigoNorm = codigoBarras.toLowerCase();
          if (codigosBarrasExistentes.contains(codigoNorm)) {
            errores.add(
              'Codigo de barras ya existe en el catalogo: $codigoBarras',
            );
          }
          if (codigosEnArchivo.contains(codigoNorm)) {
            errores.add(
              'Codigo de barras duplicado en el archivo: $codigoBarras',
            );
          } else {
            codigosEnArchivo.add(codigoNorm);
          }
        }

        final unidad = _parsearUnidadMedida(valores['unidad_medida']);
        if (unidad == null) {
          errores.add(
            'Unidad invalida: "${valores['unidad_medida']}". '
            'Use: pieza, kilogramo, litro o caja',
          );
        }

        final stockInicial = _parsearCantidad(
          valores['stock_inicial'],
          nombreCampo: 'stock_inicial',
          errores: errores,
        );
        final stockMinimo = _parsearCantidad(
          valores['stock_minimo'],
          nombreCampo: 'stock_minimo',
          errores: errores,
          porDefecto: 0.0,
        );

        String? proveedorId;
        final proveedorTexto = valores['proveedor']?.trim() ?? '';
        if (proveedorTexto.isNotEmpty) {
          final proveedor =
              proveedoresPorNombre[normalizarTextoBusqueda(proveedorTexto)];
          if (proveedor == null) {
            errores.add('Proveedor no encontrado: "$proveedorTexto"');
          } else {
            proveedorId = proveedor.id;
          }
        }

        int? piezasPorCaja;
        final piezasTexto = valores['piezas_por_caja']?.trim() ?? '';
        if (piezasTexto.isNotEmpty) {
          final piezas = int.tryParse(piezasTexto.replaceAll(',', '.'));
          if (piezas == null || piezas <= 0) {
            errores.add('piezas_por_caja invalido: "$piezasTexto"');
          } else {
            piezasPorCaja = piezas;
          }
        }

        double? precioCaja;
        final precioCajaTexto = valores['precio_caja']?.trim() ?? '';
        if (precioCajaTexto.isNotEmpty) {
          precioCaja = parsearPrecioTexto(precioCajaTexto);
          if (precioCaja == null || precioCaja <= 0) {
            errores.add('precio_caja invalido: "$precioCajaTexto"');
            precioCaja = null;
          }
        }

        final codigoCaja = valores['codigo_caja']?.trim() ?? '';
        if (codigoCaja.isNotEmpty) {
          final codigoNorm = codigoCaja.toLowerCase();
          if (codigosBarrasExistentes.contains(codigoNorm) ||
              codigosEnArchivo.contains(codigoNorm)) {
            errores.add('Codigo de caja duplicado: $codigoCaja');
          } else {
            codigosEnArchivo.add(codigoNorm);
          }
        }

        final lotePromocionCodigo = valores['lote_promocion']?.trim();
        final tieneLote =
            lotePromocionCodigo != null && lotePromocionCodigo.isNotEmpty;
        if (tieneLote) {
          if (piezasPorCaja == null || piezasPorCaja <= 0) {
            errores.add(
              'lote_promocion "$lotePromocionCodigo" requiere piezas_caja',
            );
          }
          if (precioCaja == null || precioCaja <= 0) {
            errores.add(
              'lote_promocion "$lotePromocionCodigo" requiere precio_caja',
            );
          }
          if (piezasPorCaja != null &&
              piezasPorCaja > 0 &&
              precioCaja != null &&
              precioCaja > 0) {
            final precioUnitario = redondearMonto(precioCaja / piezasPorCaja);
            final meta = metaLotes[lotePromocionCodigo];
            if (meta == null) {
              metaLotes[lotePromocionCodigo] = (
                cantidadMinima: piezasPorCaja.toDouble(),
                precioUnitario: precioUnitario,
              );
            } else if (meta.cantidadMinima != piezasPorCaja.toDouble() ||
                meta.precioUnitario != precioUnitario) {
              errores.add(
                'lote_promocion "$lotePromocionCodigo" con piezas/precio '
                'distintos a otras filas del mismo lote',
              );
            }
          }
        }

        int? unidadesPorBulto;
        final bultoTexto = valores['unidades_por_bulto']?.trim() ?? '';
        if (bultoTexto.isNotEmpty) {
          final bulto = int.tryParse(bultoTexto.replaceAll(',', '.'));
          if (bulto == null || bulto <= 0) {
            errores.add('unidades_por_bulto invalido: "$bultoTexto"');
          } else {
            unidadesPorBulto = bulto;
          }
        }

        final permiteNegativo = _parsearBool(
          valores['permite_stock_negativo'],
          valorPorDefecto: true,
        );

        AltaProductoRequest? solicitud;
        if (errores.isEmpty &&
            resolucionCategoria != null &&
            precioBase != null &&
            unidad != null &&
            stockInicial != null &&
            stockMinimo != null) {
          solicitud = AltaProductoRequest(
            nombre: nombre,
            codigoBarras: codigoBarras,
            precioBase: precioBase,
            categoriaId: resolucionCategoria.categoriaId,
            unidadMedida: unidad,
            piezasPorCaja: piezasPorCaja,
            unidadesPorBulto: unidadesPorBulto,
            proveedorId: proveedorId,
            notas: valores['notas']?.trim() ?? '',
            stockInicial: stockInicial,
            stockMinimo: stockMinimo,
            costoUnitario: costo,
            permiteStockNegativo: permiteNegativo,
            precioCaja: precioCaja,
            codigoCaja: codigoCaja,
            lotePromocionCodigo: tieneLote ? lotePromocionCodigo : null,
            categoriaACrear: resolucionCategoria.categoriaACrear,
          );
        }

        filas.add(
          FilaImportacionProducto(
            numeroFila: numeroFila,
            nombre: nombre.isEmpty ? '(sin nombre)' : nombre,
            errores: errores,
            solicitud: solicitud,
          ),
        );
      }

      if (filas.isEmpty) {
        return const AnalisisImportacionProductos(
          filas: [],
          errorArchivo: 'No hay filas de productos para importar',
        );
      }
      return AnalisisImportacionProductos(filas: filas);
    } on FormatException catch (e) {
      return AnalisisImportacionProductos(
        filas: const [],
        errorArchivo: e.message,
      );
    } catch (e) {
      return AnalisisImportacionProductos(
        filas: const [],
        errorArchivo: 'No se pudo leer el archivo: $e',
      );
    }
  }

  static List<List<String>> _leerFilas(
    Uint8List bytes,
    String extension, {
    String? nombreHoja,
  }) {
    final ext = extension.toLowerCase();
    if (ext == 'csv' || ext == 'txt') {
      final texto = _decodificarTexto(bytes);
      return _parsearCsv(texto);
    }
    if (ext == 'xlsx') {
      return LectorXlsx.leerFilas(bytes, nombreHoja: nombreHoja);
    }
    throw FormatException('Formato no soportado (.$ext). Use .csv o .xlsx');
  }

  /// Agrupa filas granel (nombre vacio = misma mercancia) y deriva precio/kg.
  static AnalisisImportacionProductos _analizarGranel({
    required List<List<String>> filasCrudas,
    required Map<String, int> mapaColumnas,
    required Map<String, Categoria> categoriasPorNombre,
  }) {
    final grupos = <({
      int numeroFila,
      String nombre,
      String categoriaTexto,
      List<(double gramos, double precio)> presentaciones,
    })>[];

    String? nombreActual;
    String categoriaActual = '';
    int filaInicio = 0;
    var presentacionesActuales = <(double, double)>[];

    void cerrarGrupo() {
      final nombre = nombreActual;
      if (nombre == null || presentacionesActuales.isEmpty) {
        return;
      }
      grupos.add((
        numeroFila: filaInicio,
        nombre: nombre,
        categoriaTexto: categoriaActual,
        presentaciones: List<(double, double)>.from(presentacionesActuales),
      ));
    }

    for (var i = 1; i < filasCrudas.length; i++) {
      final numeroFila = i + 1;
      final celdas = filasCrudas[i];
      if (_filaVacia(celdas)) {
        continue;
      }
      final valores = _valoresFila(celdas, mapaColumnas);
      final nombre = valores['nombre']?.trim() ?? '';
      final gramos = parsearPrecioTexto(
        valores['presentacion_gramos']?.trim() ?? '',
      );
      final precio = parsearPrecioTexto(valores['precio_base']?.trim() ?? '');
      final categoriaTexto = valores['categoria']?.trim() ?? '';

      if (nombre.isNotEmpty) {
        cerrarGrupo();
        nombreActual = nombre;
        categoriaActual = categoriaTexto;
        filaInicio = numeroFila;
        presentacionesActuales = [];
      } else if (nombreActual == null) {
        grupos.add((
          numeroFila: numeroFila,
          nombre: '(sin nombre)',
          categoriaTexto: categoriaTexto,
          presentaciones: const [],
        ));
        continue;
      } else if (categoriaTexto.isNotEmpty && categoriaActual.isEmpty) {
        categoriaActual = categoriaTexto;
      }

      if (gramos == null || gramos <= 0 || precio == null || precio < 0) {
        continue;
      }
      presentacionesActuales.add((gramos, precio));
    }
    cerrarGrupo();

    if (grupos.isEmpty) {
      return const AnalisisImportacionProductos(
        filas: [],
        errorArchivo: 'No hay productos granel para importar',
      );
    }

    final filas = <FilaImportacionProducto>[];
    for (final grupo in grupos) {
      final errores = <String>[];
      if (grupo.nombre == '(sin nombre)' || grupo.nombre.trim().isEmpty) {
        errores.add('El nombre es obligatorio');
      }
      if (grupo.presentaciones.isEmpty) {
        errores.add('Falta al menos una presentacion con gramos y precio');
      }

      final resolucionCategoria = _resolverCategoria(
        texto: grupo.categoriaTexto.isEmpty ? null : grupo.categoriaTexto,
        categoriasPorNombre: categoriasPorNombre,
      );

      AltaProductoRequest? solicitud;
      if (errores.isEmpty && resolucionCategoria != null) {
        final precioKilo = _precioKiloDesdePresentaciones(grupo.presentaciones);
        final presentaciones = <PresentacionImportacionSolicitud>[
          PresentacionImportacionSolicitud(
            nombre: '1 kg',
            factorABase: 1,
            precio: precioKilo,
            esPresentacionBase: true,
          ),
        ];
        for (final (gramos, precio) in grupo.presentaciones) {
          if ((gramos - 1000).abs() < 0.01) {
            continue;
          }
          final etiqueta = gramos == gramos.roundToDouble()
              ? '${gramos.round()} g'
              : '$gramos g';
          presentaciones.add(
            PresentacionImportacionSolicitud(
              nombre: etiqueta,
              factorABase: double.parse((gramos / 1000.0).toStringAsFixed(6)),
              precio: precio,
            ),
          );
        }
        solicitud = AltaProductoRequest(
          nombre: grupo.nombre,
          codigoBarras: '',
          precioBase: precioKilo,
          categoriaId: resolucionCategoria.categoriaId,
          unidadMedida: UnidadMedida.kilogramo,
          notas: 'importacion:kg',
          presentaciones: presentaciones,
          categoriaACrear: resolucionCategoria.categoriaACrear,
        );
      }

      filas.add(
        FilaImportacionProducto(
          numeroFila: grupo.numeroFila,
          nombre: grupo.nombre,
          errores: errores,
          solicitud: solicitud,
        ),
      );
    }

    return AnalisisImportacionProductos(filas: filas);
  }

  /// Precio por kilo: usa 1000 g si existe; si no, proyecta desde la mayor.
  static double _precioKiloDesdePresentaciones(
    List<(double gramos, double precio)> presentaciones,
  ) {
    for (final (gramos, precio) in presentaciones) {
      if ((gramos - 1000).abs() < 0.01) {
        return redondearMonto(precio);
      }
    }
    final (gramosMax, precioMax) = presentaciones.reduce(
      (a, b) => a.$1 >= b.$1 ? a : b,
    );
    return redondearMonto(precioMax * (1000.0 / gramosMax));
  }

  static String _extension(String ruta) {
    final punto = ruta.lastIndexOf('.');
    if (punto < 0 || punto == ruta.length - 1) {
      return '';
    }
    return ruta.substring(punto + 1);
  }

  static String _decodificarTexto(Uint8List bytes) {
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      return utf8.decode(data);
    } on FormatException {
      // Excel en Windows suele exportar CSV en Latin-1 (ISO-8859-1).
      return latin1.decode(data);
    }
  }

  static List<List<String>> _parsearCsv(String texto) {
    final filas = <List<String>>[];
    final filaActual = <String>[];
    final celda = StringBuffer();
    var entreComillas = false;

    for (var i = 0; i < texto.length; i++) {
      final c = texto[i];
      if (entreComillas) {
        if (c == '"') {
          if (i + 1 < texto.length && texto[i + 1] == '"') {
            celda.write('"');
            i++;
          } else {
            entreComillas = false;
          }
        } else {
          celda.write(c);
        }
        continue;
      }
      if (c == '"') {
        entreComillas = true;
      } else if (c == ',') {
        filaActual.add(celda.toString());
        celda.clear();
      } else if (c == '\n') {
        filaActual.add(celda.toString());
        celda.clear();
        if (filaActual.any((v) => v.trim().isNotEmpty)) {
          filas.add(List<String>.from(filaActual));
        }
        filaActual.clear();
      } else if (c != '\r') {
        celda.write(c);
      }
    }
    filaActual.add(celda.toString());
    if (filaActual.any((v) => v.trim().isNotEmpty)) {
      filas.add(filaActual);
    }
    return filas;
  }

  static Map<String, int> _mapearColumnas(List<String> encabezados) {
    final mapa = <String, int>{};
    for (var i = 0; i < encabezados.length; i++) {
      final encabezado = encabezados[i];
      for (final entrada in _aliasColumnas.entries) {
        if (entrada.value.contains(encabezado)) {
          mapa.putIfAbsent(entrada.key, () => i);
        }
      }
    }
    return mapa;
  }

  static Map<String, String?> _valoresFila(
    List<String> celdas,
    Map<String, int> mapaColumnas,
  ) {
    final valores = <String, String?>{};
    for (final entrada in mapaColumnas.entries) {
      final indice = entrada.value;
      valores[entrada.key] = indice < celdas.length ? celdas[indice] : '';
    }
    return valores;
  }

  static bool _filaVacia(List<String> celdas) =>
      celdas.every((c) => c.trim().isEmpty);

  static UnidadMedida? _parsearUnidadMedida(String? texto) {
    if (texto == null || texto.trim().isEmpty) {
      return UnidadMedida.pieza;
    }
    final norm = normalizarTextoBusqueda(texto.trim());
    for (final unidad in UnidadMedida.values) {
      if (normalizarTextoBusqueda(unidad.name) == norm) {
        return unidad;
      }
    }
    const alias = <String, UnidadMedida>{
      'pz': UnidadMedida.pieza,
      'pza': UnidadMedida.pieza,
      'piezas': UnidadMedida.pieza,
      'unidad': UnidadMedida.pieza,
      'kg': UnidadMedida.kilogramo,
      'kilo': UnidadMedida.kilogramo,
      'kilos': UnidadMedida.kilogramo,
      'kilogramos': UnidadMedida.kilogramo,
      'l': UnidadMedida.litro,
      'lt': UnidadMedida.litro,
      'litros': UnidadMedida.litro,
      'litro': UnidadMedida.litro,
    };
    return alias[norm];
  }

  static double? _parsearCantidad(
    String? texto, {
    required String nombreCampo,
    required List<String> errores,
    double porDefecto = 0.0,
  }) {
    if (texto == null || texto.trim().isEmpty) {
      return porDefecto;
    }
    final valor = parsearPrecioTexto(texto.trim());
    if (valor == null || valor < 0.0) {
      errores.add('$nombreCampo invalido: "$texto"');
      return null;
    }
    return valor;
  }

  static bool _parsearBool(String? texto, {bool valorPorDefecto = false}) {
    if (texto == null || texto.trim().isEmpty) {
      return valorPorDefecto;
    }
    final norm = normalizarTextoBusqueda(texto.trim());
    return {'si', 's', 'true', '1', 'yes', 'verdadero'}.contains(norm);
  }

  /// Resuelve categoria existente, marca creacion, o cae a la mas parecida a
  /// abarrotes cuando la columna viene vacia.
  static ({String categoriaId, String? categoriaACrear})? _resolverCategoria({
    required String? texto,
    required Map<String, Categoria> categoriasPorNombre,
    String categoriaPorDefectoNombre = categoriaPorDefecto,
  }) {
    final textoLimpio = texto?.trim() ?? '';
    final usaDefecto = textoLimpio.isEmpty;
    final clave = usaDefecto
        ? normalizarTextoBusqueda(categoriaPorDefectoNombre)
        : normalizarTextoBusqueda(textoLimpio);

    final exacta = categoriasPorNombre[clave];
    if (exacta != null) {
      return (categoriaId: exacta.id, categoriaACrear: null);
    }

    if (usaDefecto) {
      final parecida = _categoriaMasParecida(
        categoriaPorDefectoNombre,
        categoriasPorNombre,
      );
      if (parecida != null) {
        return (categoriaId: parecida.id, categoriaACrear: null);
      }
      // Catalogo vacio: se creara "Abarrotes" al importar.
      return (
        categoriaId: '',
        categoriaACrear: _tituloCategoria(categoriaPorDefectoNombre),
      );
    }

    // Categoria nombrada inexistente: se crea al importar.
    return (categoriaId: '', categoriaACrear: textoLimpio);
  }

  static Categoria? _categoriaMasParecida(
    String objetivo,
    Map<String, Categoria> categoriasPorNombre,
  ) {
    if (categoriasPorNombre.isEmpty) {
      return null;
    }
    final objetivoNorm = normalizarTextoBusqueda(objetivo);
    Categoria? mejorPorContencion;
    for (final entrada in categoriasPorNombre.entries) {
      if (entrada.key.contains(objetivoNorm) ||
          objetivoNorm.contains(entrada.key)) {
        mejorPorContencion = entrada.value;
        break;
      }
    }
    if (mejorPorContencion != null) {
      return mejorPorContencion;
    }

    Categoria? mejor;
    var mejorDist = 1 << 30;
    for (final entrada in categoriasPorNombre.entries) {
      final dist = _distanciaLevenshtein(objetivoNorm, entrada.key);
      if (dist < mejorDist) {
        mejorDist = dist;
        mejor = entrada.value;
      }
    }
    return mejor;
  }

  static int _distanciaLevenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    final filas = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      filas[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      filas[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        filas[i][j] = [
          filas[i - 1][j] + 1,
          filas[i][j - 1] + 1,
          filas[i - 1][j - 1] + costo,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return filas[a.length][b.length];
  }

  static String _tituloCategoria(String texto) {
    final t = texto.trim();
    if (t.isEmpty) {
      return 'Abarrotes';
    }
    return t[0].toUpperCase() + t.substring(1).toLowerCase();
  }

  static String _escaparCsv(String texto) {
    if (texto.contains(',') || texto.contains('"') || texto.contains('\n')) {
      return '"${texto.replaceAll('"', '""')}"';
    }
    return texto;
  }
}
