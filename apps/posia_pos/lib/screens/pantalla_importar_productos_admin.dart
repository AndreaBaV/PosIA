/// Pantalla para importar productos en lote desde CSV o Excel.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/admin_providers.dart';
import '../util/importador_productos.dart';

class PantallaImportarProductosAdmin extends ConsumerStatefulWidget {
  const PantallaImportarProductosAdmin({super.key});

  @override
  ConsumerState<PantallaImportarProductosAdmin> createState() =>
      _PantallaImportarProductosAdminState();
}

class _PantallaImportarProductosAdminState
    extends ConsumerState<PantallaImportarProductosAdmin> {
  AnalisisImportacionProductos? _analisis;
  String? _nombreArchivo;
  bool _importando = false;
  int _progresoActual = 0;
  int _progresoTotal = 0;
  ResultadoImportacionProductos? _resultado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar plantilla',
            onPressed: _descargarPlantilla,
          ),
        ],
      ),
      body: _importando ? _cuerpoProgreso() : _cuerpoPrincipal(),
      bottomNavigationBar: _analisis != null && !_importando
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: FilledButton.icon(
                  onPressed: _analisis!.filasValidas > 0 ? _importar : null,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(
                    'Importar ${_analisis!.filasValidas} producto(s)',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _cuerpoProgreso() {
    final fraccion = _progresoTotal > 0
        ? _progresoActual / _progresoTotal
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16.0),
            Text(
              'Importando productos... '
              '$_progresoActual / $_progresoTotal',
            ),
            if (fraccion != null) ...[
              const SizedBox(height: 12.0),
              LinearProgressIndicator(value: fraccion),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cuerpoPrincipal() {
    if (_resultado != null) {
      return _resumenResultado(_resultado!);
    }
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Importacion por lote',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  'Cargue un CSV o Excel (.xlsx). Hay dos plantillas: catalogo '
                  'general (pieza/caja) y por kilogramo (varias presentaciones '
                  'en gramos; el precio/kg viene de 1000 g o se deriva). '
                  'Si la categoria no existe se crea al importar; si falta la '
                  'columna se usa Abarrotes o la mas parecida. En Excel con '
                  'varias hojas, elija la hoja a importar (p. ej. Granel).',
                ),
                const SizedBox(height: 16.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    FilledButton.icon(
                      onPressed: _seleccionarArchivo,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Seleccionar archivo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _descargarPlantilla,
                      icon: const Icon(Icons.table_view),
                      label: const Text('Plantilla catalogo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _descargarPlantillaGranel,
                      icon: const Icon(Icons.scale),
                      label: const Text('Plantilla por kg'),
                    ),
                  ],
                ),
                if (_nombreArchivo != null) ...[
                  const SizedBox(height: 12.0),
                  Text(
                    'Archivo: $_nombreArchivo',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_analisis?.errorArchivo != null) ...[
          const SizedBox(height: 12.0),
          Card(
            color: PosiaColors.cancelar.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(Icons.error, color: PosiaColors.cancelar),
              title: Text(_analisis!.errorArchivo!),
            ),
          ),
        ],
        if (_analisis != null && _analisis!.errorArchivo == null) ...[
          const SizedBox(height: 12.0),
          _resumenAnalisis(_analisis!),
          const SizedBox(height: 8.0),
          ..._analisis!.filas.map(_tarjetaFila),
        ],
      ],
    );
  }

  Widget _resumenAnalisis(AnalisisImportacionProductos analisis) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _expandedResumen('Total', '${analisis.totalFilas}', Icons.list_alt),
            _expandedResumen(
              'Listos',
              '${analisis.filasValidas}',
              Icons.check_circle,
              color: PosiaColors.cobrar,
            ),
            _expandedResumen(
              'Con error',
              '${analisis.filasConError}',
              Icons.warning,
              color: analisis.filasConError > 0 ? PosiaColors.cancelar : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedResumen(
    String etiqueta,
    String valor,
    IconData icono, {
    Color? color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icono, color: color),
          const SizedBox(height: 4.0),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(etiqueta, style: const TextStyle(fontSize: 12.0)),
        ],
      ),
    );
  }

  Widget _tarjetaFila(FilaImportacionProducto fila) {
    final ok = fila.valida;
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ok
              ? PosiaColors.cobrar.withValues(alpha: 0.15)
              : PosiaColors.cancelar.withValues(alpha: 0.15),
          child: Icon(
            ok ? Icons.check : Icons.close,
            color: ok ? PosiaColors.cobrar : PosiaColors.cancelar,
            size: 20.0,
          ),
        ),
        title: Text('Fila ${fila.numeroFila}: ${fila.nombre}'),
        subtitle: ok
            ? Text(
                '${fila.solicitud!.codigoBarras.isEmpty ? "Sin codigo" : fila.solicitud!.codigoBarras} · '
                '${formatearMoneda(fila.solicitud!.precioBase)}'
                '${fila.solicitud!.categoriaACrear != null ? " · creará categoría «${fila.solicitud!.categoriaACrear}»" : ""}',
              )
            : Text(fila.errores.join('\n')),
        isThreeLine: !ok,
      ),
    );
  }

  Widget _resumenResultado(ResultadoImportacionProductos resultado) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          color: resultado.exitoTotal
              ? PosiaColors.cobrar.withValues(alpha: 0.08)
              : Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resultado.exitoTotal
                      ? 'Importacion completada'
                      : 'Importacion con advertencias',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text('${resultado.importados} producto(s) importados'),
                if (resultado.errores.isNotEmpty)
                  Text('${resultado.errores.length} error(es) al guardar'),
              ],
            ),
          ),
        ),
        ...resultado.errores.map(
          (e) => Card(
            child: ListTile(
              leading: Icon(Icons.error, color: PosiaColors.cancelar),
              title: Text('Fila ${e.numeroFila}: ${e.nombre}'),
              subtitle: Text(e.mensaje),
              isThreeLine: true,
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _resultado = null;
              _analisis = null;
              _nombreArchivo = null;
            });
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Importar otro archivo'),
        ),
      ],
    );
  }

  Future<void> _seleccionarArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'txt'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) {
      return;
    }
    final archivo = resultado.files.first;
    if (!mounted) {
      return;
    }
    setState(() {
      _resultado = null;
      _nombreArchivo = archivo.name;
    });
    await _analizarArchivoSeleccionado(archivo);
  }

  Future<String?> _elegirHojaSiAplica(PlatformFile archivo) async {
    final extension = _extensionArchivo(archivo.name).toLowerCase();
    if (extension != 'xlsx') {
      return null;
    }
    Uint8List? bytes = archivo.bytes;
    if (bytes == null && archivo.path != null) {
      bytes = await File(archivo.path!).readAsBytes();
    }
    if (bytes == null) {
      return null;
    }
    final hojas = ImportadorProductos.listarHojasXlsx(bytes);
    if (hojas.length <= 1) {
      return hojas.isEmpty ? null : hojas.first;
    }
    final preferida = hojas.where((h) => h.toLowerCase() == 'granel').firstOrNull;
    if (!mounted) {
      return preferida;
    }
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Elegir hoja'),
          children: [
            for (final hoja in hojas)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, hoja),
                child: Text(
                  hoja,
                  style: TextStyle(
                    fontWeight: hoja.toLowerCase() == 'granel'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
          ],
        );
      },
    ).then((elegida) => elegida ?? preferida);
  }

  Future<void> _analizarArchivoSeleccionado(PlatformFile archivo) async {
    final servicio = await ref.read(servicioAdminProvider.future);
    final categorias = await servicio.listarCategorias();
    final proveedores = await servicio.listarProveedores();
    final productos = await servicio.listarProductosCatalogo();
    final codigosExistentes = productos
        .where((p) => p.activo && p.codigoBarras.trim().isNotEmpty)
        .map((p) => p.codigoBarras.trim().toLowerCase())
        .toSet();

    final nombreHoja = await _elegirHojaSiAplica(archivo);

    AnalisisImportacionProductos analisis;
    if (archivo.bytes != null) {
      final extension = _extensionArchivo(archivo.name);
      analisis = ImportadorProductos.analizarBytes(
        bytes: archivo.bytes!,
        extension: extension,
        categorias: categorias,
        proveedores: proveedores,
        codigosBarrasExistentes: codigosExistentes,
        nombreHoja: nombreHoja,
      );
    } else if (archivo.path != null) {
      analisis = await ImportadorProductos.analizarArchivo(
        rutaArchivo: archivo.path!,
        categorias: categorias,
        proveedores: proveedores,
        codigosBarrasExistentes: codigosExistentes,
        nombreHoja: nombreHoja,
      );
    } else {
      analisis = const AnalisisImportacionProductos(
        filas: [],
        errorArchivo: 'No se pudo leer el archivo seleccionado',
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _analisis = analisis;
      if (nombreHoja != null && nombreHoja.isNotEmpty) {
        _nombreArchivo = '${archivo.name} · hoja "$nombreHoja"';
      }
    });
  }

  Future<void> _importar() async {
    final analisis = _analisis;
    if (analisis == null) {
      return;
    }
    final filasValidas = analisis.filas.where((f) => f.valida).toList();
    if (filasValidas.isEmpty) {
      return;
    }

    setState(() {
      _importando = true;
      _progresoActual = 0;
      _progresoTotal = filasValidas.length;
    });

    final servicio = await ref.read(servicioAdminProvider.future);
    final resultado = await servicio.importarProductosLote(
      filasValidas
          .map((f) => (numeroFila: f.numeroFila, solicitud: f.solicitud!))
          .toList(),
      alProgreso: (actual, total) {
        if (!mounted) {
          return;
        }
        setState(() {
          _progresoActual = actual;
          _progresoTotal = total;
        });
      },
    );

    ref.invalidate(productosCatalogoAdminProvider);
    ref.invalidate(categoriasFormularioAdminProvider);
    await refrescarDatosMaestros(ref);

    if (!mounted) {
      return;
    }
    setState(() {
      _importando = false;
      _resultado = resultado;
      _analisis = null;
    });
    PosiaNotificaciones.mostrarSnackBar(
      context,
      SnackBar(
        content: Text(
          resultado.exitoTotal
              ? '${resultado.importados} productos importados'
              : '${resultado.importados} importados, '
                    '${resultado.errores.length} con error',
        ),
        backgroundColor: resultado.exitoTotal
            ? PosiaColors.cobrar
            : Colors.orange,
      ),
    );
  }

  Future<void> _descargarPlantilla() async {
    await _guardarYCompartirPlantilla(
      contenido: ImportadorProductos.generarPlantillaCsv(),
      nombreArchivo: 'posia_plantilla_productos.csv',
      asunto: 'Plantilla importacion productos POSIA',
    );
  }

  Future<void> _descargarPlantillaGranel() async {
    await _guardarYCompartirPlantilla(
      contenido: ImportadorProductos.generarPlantillaGranelCsv(),
      nombreArchivo: 'posia_plantilla_productos_granel.csv',
      asunto: 'Plantilla importacion por kg POSIA',
    );
  }

  Future<void> _guardarYCompartirPlantilla({
    required String contenido,
    required String nombreArchivo,
    required String asunto,
  }) async {
    if (kIsWeb) {
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(
          content: Text('La descarga de plantilla no esta disponible en web'),
        ),
      );
      return;
    }
    final carpeta =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final ruta = '${carpeta.path}${Platform.pathSeparator}$nombreArchivo';
    await File(ruta).writeAsString(contenido);
    if (!mounted) {
      return;
    }
    await Share.shareXFiles([XFile(ruta)], subject: asunto);
  }

  String _extensionArchivo(String nombre) {
    final punto = nombre.lastIndexOf('.');
    if (punto < 0) {
      return '';
    }
    return nombre.substring(punto + 1);
  }
}
