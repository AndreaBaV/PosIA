/// Formulario completo de alta/edicion de producto con pestañas.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:posia_core/posia_core.dart';
import 'package:posia_database/posia_database.dart';
import 'package:posia_pricing/posia_pricing.dart';
import 'package:posia_ui/posia_ui.dart';
import 'package:posia_voice/posia_voice.dart';

import '../providers/admin_providers.dart';
import '../voz/servicio_voz_dispositivo.dart';
import '../widgets/panel_empaques_producto.dart';

class PantallaFormularioProducto extends ConsumerStatefulWidget {
  const PantallaFormularioProducto({this.productoExistente, super.key});

  final Producto? productoExistente;

  @override
  ConsumerState<PantallaFormularioProducto> createState() =>
      _PantallaFormularioProductoState();
}

class _PantallaFormularioProductoState
    extends ConsumerState<PantallaFormularioProducto>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _nombreController = TextEditingController();
  final _codigoController = TextEditingController();
  final _precioController = TextEditingController();
  final _costoController = TextEditingController(text: '0');
  final _notasController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minimoController = TextEditingController(text: '0');
  String? _categoriaId;
  UnidadMedida _unidad = UnidadMedida.pieza;
  String? _proveedorId;
  bool _activo = true;
  bool _permiteStockNegativo = true;
  final _escalas = <_EscalaEditable>[];
  final _cortesPeso = <_CortePesoEditable>[];
  List<EmpaqueProductoDraft> _empaquesPendientes = [];
  bool _guardando = false;
  final _interpretadorVoz = InterpretadorAltaProductoVoz();
  final _servicioVoz = ServicioVozDispositivo();
  bool _escuchandoVoz = false;
  bool _vozInicializada = false;
  bool _finalizandoVoz = false;
  String _transcripcionVoz = '';

  bool get _esEdicion => widget.productoExistente != null;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final p = widget.productoExistente;
    if (p != null) {
      _nombreController.text = p.nombre;
      _codigoController.text = p.codigoBarras;
      _precioController.text = p.precioBase.toStringAsFixed(2);
      _costoController.text = p.costoUnitario.toStringAsFixed(2);
      _notasController.text = p.notas;
      _categoriaId = p.categoriaId;
      _unidad = p.unidadMedida;
      _proveedorId = p.proveedorId;
      _activo = p.activo;
      _permiteStockNegativo = p.permiteStockNegativo;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cargarEscalas(p.id);
        _cargarStock(p.id);
      });
    }
  }

  Future<void> _cargarStock(String productoId) async {
    final servicio = await ref.read(servicioAdminProvider.future);
    final inventario = await servicio.obtenerInventarioConsolidado();
    for (final reg in inventario) {
      if (reg.productoId == productoId &&
          reg.tiendaId == servicio.tiendaActivaId) {
        if (!mounted) {
          return;
        }
        setState(() {
          _minimoController.text = reg.stockMinimo.toStringAsFixed(0);
          _stockController.text = reg.cantidad.toStringAsFixed(0);
        });
        break;
      }
    }
  }

  Future<void> _cargarEscalas(String productoId) async {
    final servicio = await ref.read(servicioAdminProvider.future);
    final escalas = await servicio.listarEscalasMayoreo(productoId);
    if (!mounted) {
      return;
    }
    setState(() {
      _escalas.clear();
      if (_vendePorPeso) {
        final cortes = extraerPreciosCorteDesdeEscalas(
          escalas: escalas.map(
            (e) => (
              cantidadMinima: e.cantidadMinima,
              precioUnitario: e.precioUnitario,
            ),
          ),
          precioBase:
              parsearPrecioTexto(_precioController.text) ??
              widget.productoExistente?.precioBase ??
              0.0,
        );
        if (cortes.precioKilo != null && cortes.precioKilo! > 0.0) {
          _precioController.text = cortes.precioKilo!.toStringAsFixed(2);
        }
        for (final corte in _cortesPeso) {
          corte.dispose();
        }
        _cortesPeso
          ..clear()
          ..addAll(
            cortes.cortes.map(
              (c) => _CortePesoEditable.desdeCorte(
                pesoKg: c.pesoKg,
                precioCorte: c.precioCorte,
                formatearPeso: _formatearCantidadEscala,
              ),
            ),
          );
        return;
      }
      for (final e in escalas) {
        _escalas.add(
          _EscalaEditable(
            cantidadController: TextEditingController(
              text: _formatearCantidadEscala(e.cantidadMinima),
            ),
            precioController: TextEditingController(
              text: e.precioUnitario.toStringAsFixed(2),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_servicioVoz.detener());
    _tabs.dispose();
    _nombreController.dispose();
    _codigoController.dispose();
    _precioController.dispose();
    _costoController.dispose();
    _notasController.dispose();
    _stockController.dispose();
    _minimoController.dispose();
    for (final corte in _cortesPeso) {
      corte.dispose();
    }
    for (final e in _escalas) {
      e.dispose();
    }
    super.dispose();
  }

  bool get _vendePorPeso => _unidad == UnidadMedida.kilogramo;

  String _formatearCantidadEscala(double cantidad) {
    if (cantidad == cantidad.roundToDouble()) {
      return cantidad.toStringAsFixed(0);
    }
    return cantidad
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  Widget _buildSeccionEscalas(double costo) {
    if (_vendePorPeso) {
      return _buildSeccionPreciosPorPeso(costo);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mayoreo por cantidad (opcional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4.0),
        Text(
          'Descuento al vender muchas unidades sueltas. '
          'Para vender en caja o bulto con precio fijo, use empaques más abajo.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
        ),
        const SizedBox(height: 8.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox.shrink(),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _escalas.add(_EscalaEditable.vacia())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar tramo'),
            ),
          ],
        ),
        ..._escalas.asMap().entries.map((entry) {
          final i = entry.key;
          final escala = entry.value;
          final cantidad =
              parsearPrecioTexto(escala.cantidadController.text) ?? -1.0;
          final precioE =
              parsearPrecioTexto(escala.precioController.text) ?? 0.0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: escala.cantidadController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cant. mínima',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: CampoPrecioVenta(
                          controller: escala.precioController,
                          costoUnitario: costo,
                          labelText: 'Precio unit.',
                          isDense: true,
                          prefixText: r'$ ',
                          obligatorio: false,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: PosiaColors.cancelar,
                        ),
                        onPressed: () => setState(() {
                          escala.dispose();
                          _escalas.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                  if (cantidad >= 0.0 && precioE > 0.0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                      child: Text(
                        describirTramoPrecio(
                          cantidadMinima: cantidad,
                          precioUnitario: precioE,
                          unidadMedida: _unidad,
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSeccionPreciosPorPeso(double costo) {
    final precioKilo = parsearPrecioTexto(_precioController.text) ?? 0.0;
    final cortes = _cortesPesoActuales();
    final vistaPrevia = precioKilo > 0.0
        ? describirVistaPreviaPreciosPeso(
            precioKilo: precioKilo,
            cortes: cortes,
          )
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presentaciones menores a 1 kg (opcional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        Text(
          'Agregue gramajes a granel (ej. 0.1, 0.25, 0.5 kg). '
          'Puede capturar el precio por kilo de ese tramo o el total '
          'que paga el cliente por ese peso; el otro se calcula solo.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0),
        ),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 4.0,
          runSpacing: 0.0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () =>
                  setState(() => _cortesPeso.add(_CortePesoEditable.vacio())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar presentación'),
            ),
            TextButton(
              onPressed: () => _agregarCorteRapido(0.1),
              child: const Text('+ 0.1 kg'),
            ),
            TextButton(
              onPressed: () => _agregarCorteRapido(pesoCuartoKilo),
              child: const Text('+ 0.25 kg'),
            ),
            TextButton(
              onPressed: () => _agregarCorteRapido(pesoMedioKilo),
              child: const Text('+ 0.5 kg'),
            ),
          ],
        ),
        ..._cortesPeso.asMap().entries.map((entry) {
          final i = entry.key;
          final corte = entry.value;
          final peso = parsearPrecioTexto(corte.pesoController.text) ?? 0.0;
          final costoCorte = costo > 0.0 && peso > 0.0
              ? redondearMonto(costo * peso)
              : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: corte.pesoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Peso (kg)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            corte.sincronizarDesdePeso();
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        flex: 3,
                        child: CampoPrecioVenta(
                          controller: corte.precioPorKgController,
                          costoUnitario: costo,
                          labelText: 'Precio / kg',
                          isDense: true,
                          obligatorio: false,
                          onChanged: (_) {
                            corte.sincronizarDesdePrecioPorKg();
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        flex: 3,
                        child: CampoPrecioVenta(
                          controller: corte.precioCorteController,
                          costoUnitario: costoCorte,
                          labelText: 'Precio del peso',
                          isDense: true,
                          obligatorio: false,
                          onChanged: (_) {
                            corte.sincronizarDesdePrecioCorte();
                            setState(() {});
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(
                          Icons.delete,
                          color: PosiaColors.cancelar,
                        ),
                        onPressed: () => setState(() {
                          corte.dispose();
                          _cortesPeso.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (vistaPrevia.isNotEmpty) ...[
          const SizedBox(height: 4.0),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Al vender en caja se cobrará:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6.0),
                Text(
                  vistaPrevia,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _agregarCorteRapido(double pesoKg) {
    final yaExiste = _cortesPeso.any((c) {
      final p = parsearPrecioTexto(c.pesoController.text);
      return p != null && (p - pesoKg).abs() < 0.001;
    });
    if (yaExiste) {
      return;
    }
    setState(() {
      _cortesPeso.add(
        _CortePesoEditable.vacio(
          pesoKg: pesoKg,
          formatearPeso: _formatearCantidadEscala,
        ),
      );
    });
  }

  List<PrecioCortePeso> _cortesPesoActuales() {
    final cortes = <PrecioCortePeso>[];
    for (final corte in _cortesPeso) {
      final peso = parsearPrecioTexto(corte.pesoController.text);
      final precioCorte = parsearPrecioTexto(corte.precioCorteController.text);
      if (peso == null ||
          peso <= 0.0 ||
          peso >= pesoKiloCompleto ||
          precioCorte == null ||
          precioCorte <= 0.0) {
        continue;
      }
      cortes.add((pesoKg: peso, precioCorte: precioCorte));
    }
    return cortes;
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasFormularioAdminProvider);
    final proveedoresAsync = ref.watch(proveedoresFormularioAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar producto' : 'Nuevo producto'),
        actions: [
          IconButton(
            tooltip: 'Cómo dictar un producto',
            onPressed: _mostrarAyudaVoz,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: _escuchandoVoz
                ? 'Detener dictado'
                : 'Dictar producto por voz',
            onPressed: _guardando ? null : _alternarEscuchaVoz,
            icon: Icon(
              _escuchandoVoz ? Icons.mic : Icons.mic_none,
              color: _escuchandoVoz ? PosiaColors.cobrar : null,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Precios y venta'),
            Tab(text: 'Inventario'),
          ],
        ),
      ),
      body: Stack(
        children: [
          categoriasAsync.when(
            data: (categorias) {
              final categoriasActivas = categorias.where((c) => c.activa);
              _categoriaId ??= categoriasActivas.firstOrNull?.id;
              return TabBarView(
                controller: _tabs,
                children: [
                  _pestanaGeneral(categorias, proveedoresAsync),
                  _pestanaPreciosYVenta(),
                  _pestanaInventario(),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
          if (_escuchandoVoz) _overlayVoz(context),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            onPressed: _guardando
                ? null
                : () => _guardar(categoriasAsync.value ?? []),
            icon: _guardando
                ? const SizedBox(
                    width: 18.0,
                    height: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : 'Guardar producto'),
          ),
        ),
      ),
    );
  }

  Widget _overlayVoz(BuildContext context) {
    return Positioned(
      left: 12.0,
      right: 12.0,
      bottom: 12.0,
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(16.0),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.mic, color: PosiaColors.cobrar),
                  const SizedBox(width: 8.0),
                  const Expanded(
                    child: Text(
                      'Dicta el producto — nombre, precio, costo…',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _finalizarEscuchaVoz,
                    child: const Text('Listo'),
                  ),
                ],
              ),
              if (_transcripcionVoz.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Text(
                  _transcripcionVoz,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13.0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pestanaGeneral(
    List<Categoria> categorias,
    AsyncValue<List<Proveedor>> proveedores,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          color: Colors.blueGrey.shade50,
          child: const ListTile(
            leading: Icon(Icons.mic),
            title: Text('Dictado por voz'),
            subtitle: Text(
              'Toca el micrófono arriba. Ejemplo: '
              '"Jitomate por kilo a 35 pesos categoría verdura stock 10"',
            ),
          ),
        ),
        const SizedBox(height: 12.0),
        TextField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12.0),
        TextField(
          controller: _codigoController,
          decoration: const InputDecoration(
            labelText: 'Código de barras',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12.0),
        Builder(
          builder: (context) {
            // Solo activas + la del producto si quedó huérfana (inactiva/borrada
            // del listado). Flutter exige exactamente 1 item con el value.
            final catsActivas = categorias.where((c) => c.activa).toList();
            final itemsCat = <Categoria>[...catsActivas];
            final idSel = _categoriaId;
            if (idSel != null &&
                idSel.isNotEmpty &&
                !itemsCat.any((c) => c.id == idSel)) {
              final huerfana = categorias.where((c) => c.id == idSel);
              itemsCat.addAll(huerfana);
            }
            final valorCat = (idSel != null &&
                    itemsCat.any((c) => c.id == idSel))
                ? idSel
                : itemsCat.firstOrNull?.id;
            return DropdownButtonFormField<String>(
              key: ValueKey('cat-$valorCat-${itemsCat.length}'),
              initialValue: valorCat,
              items: itemsCat
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoriaId = v),
              decoration: const InputDecoration(
                labelText: 'Categoría *',
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
        const SizedBox(height: 12.0),
        DropdownButtonFormField<UnidadMedida>(
          key: ValueKey('unidad-$_unidad'),
          initialValue: _unidad,
          items: UnidadMedida.values
              .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
              .toList(),
          onChanged: (v) => setState(() => _unidad = v ?? UnidadMedida.pieza),
          decoration: const InputDecoration(
            labelText: 'Unidad de venta',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12.0),
        proveedores.when(
          data: (lista) {
            final idsProv = lista.map((p) => p.id).toList();
            final idProv = _proveedorId;
            final valorProv =
                idProv == null || idsProv.contains(idProv) ? idProv : null;
            return DropdownButtonFormField<String?>(
              key: ValueKey('prov-$valorProv-${idsProv.length}'),
              initialValue: valorProv,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin proveedor'),
                ),
                ...lista.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                ),
              ],
              onChanged: (v) => setState(() => _proveedorId = v),
              decoration: const InputDecoration(
                labelText: 'Proveedor',
                border: OutlineInputBorder(),
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
        ),
        const SizedBox(height: 12.0),
        TextField(
          controller: _notasController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notas',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          title: const Text('Producto activo'),
          value: _activo,
          onChanged: (v) => setState(() => _activo = v),
        ),
      ],
    );
  }

  Widget _pestanaPreciosYVenta() {
    final costo =
        parsearPrecioTexto(_costoController.text) ??
        widget.productoExistente?.costoUnitario ??
        0.0;
    final precio =
        parsearPrecioTexto(_precioController.text) ??
        widget.productoExistente?.precioBase ??
        0.0;
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        TextField(
          controller: _costoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Costo de compra (MXN)',
            border: OutlineInputBorder(),
            prefixText: '\$ ',
            helperText: 'Precio al que compra el producto al proveedor',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12.0),
        CampoPrecioVenta(
          controller: _precioController,
          costoUnitario: costo,
          labelText: _vendePorPeso
              ? 'Precio del kilo completo (MXN) *'
              : 'Precio menudeo (MXN) *',
          onChanged: (_) => setState(() {}),
        ),
        if (_vendePorPeso)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Precio por 1 kg. Abajo puede fijar medio/cuarto de kilo '
              'o empaques (bulto 25 kg, etc.).',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.0),
            ),
          ),
        const SizedBox(height: 12.0),
        PanelCalculoUtilidad(
          costoUnitario: costo,
          precioController: _precioController,
          alCambiarPrecio: () => setState(() {}),
        ),
        const SizedBox(height: 16.0),
        _buildSeccionEscalas(costo),
        const Divider(height: 32.0),
        PanelEmpaquesProducto(
          incrustado: true,
          productoId: widget.productoExistente?.id,
          costoUnitario: costo,
          precioMenudeo: precio,
          unidadMedida: _unidad,
          escalasMayoreo: _escalasMayoreoActuales(),
          empaquesPendientes: _empaquesPendientes,
          alCambiarEmpaquesPendientes: (lista) =>
              setState(() => _empaquesPendientes = lista),
        ),
      ],
    );
  }

  List<EscalaMayoreoRef> _escalasMayoreoActuales() {
    if (_vendePorPeso) {
      final precioKilo = parsearPrecioTexto(_precioController.text) ?? 0.0;
      return construirEscalasDesdeCortes(
        precioKilo: precioKilo,
        cortes: _cortesPesoActuales(),
      );
    }
    return _escalas
        .map((e) {
          final cant = parsearPrecioTexto(e.cantidadController.text) ?? 0.0;
          final precioE = parsearPrecioTexto(e.precioController.text) ?? 0.0;
          return (cantidadMinima: cant, precioUnitario: precioE);
        })
        .where((e) => e.cantidadMinima >= 0.0 && e.precioUnitario > 0.0)
        .toList();
  }

  Widget _pestanaInventario() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (_esEdicion)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Stock inicial solo aplica al crear producto'),
          )
        else ...[
          TextField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stock inicial',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12.0),
        ],
        TextField(
          controller: _minimoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stock mínimo (alerta)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12.0),
        SwitchListTile(
          title: const Text('Permitir stock negativo'),
          subtitle: const Text('Vender aunque no haya existencia'),
          value: _permiteStockNegativo,
          onChanged: (v) => setState(() => _permiteStockNegativo = v),
        ),
      ],
    );
  }

  List<EscalaMayoreo> _parseEscalas(String productoId) {
    if (_vendePorPeso) {
      final precioKilo = parsearPrecioTexto(_precioController.text) ?? 0.0;
      return construirEscalasDesdeCortes(
            precioKilo: precioKilo,
            cortes: _cortesPesoActuales(),
          )
          .map(
            (e) => EscalaMayoreo(
              productoId: productoId,
              cantidadMinima: e.cantidadMinima,
              precioUnitario: e.precioUnitario,
            ),
          )
          .toList();
    }
    return _escalas
        .map((e) {
          final cant = parsearPrecioTexto(e.cantidadController.text) ?? 0.0;
          final precio = parsearPrecioTexto(e.precioController.text) ?? 0.0;
          return EscalaMayoreo(
            productoId: productoId,
            cantidadMinima: cant,
            precioUnitario: precio,
          );
        })
        .where((e) => e.cantidadMinima >= 0.0 && e.precioUnitario > 0.0)
        .toList();
  }

  Future<({int? piezasPorCaja, int? unidadesPorBulto})> _resolverEmpaqueLegacy(
    ServicioAdmin servicio,
  ) async {
    final tipos = await servicio.listarTiposPresentacion();
    if (_esEdicion) {
      final presentaciones = await servicio.listarPresentacionesProducto(
        widget.productoExistente!.id,
      );
      return derivarEmpaqueLegacy(presentaciones: presentaciones, tipos: tipos);
    }
    final simuladas = _empaquesPendientes
        .map(
          (e) => PresentacionProducto(
            id: '',
            productoId: '',
            tipoPresentacionId: e.tipoPresentacionId,
            nombre: e.nombre,
            factorABase: e.factorABase,
            esPresentacionBase: false,
            codigoBarras: e.codigoBarras,
            precio: e.precio,
            activo: true,
          ),
        )
        .toList();
    return derivarEmpaqueLegacy(presentaciones: simuladas, tipos: tipos);
  }

  Future<void> _guardar(List<Categoria> categorias) async {
    final nombre = _nombreController.text.trim();
    final categoriaValida =
        _categoriaId != null &&
        categorias.any((c) => c.activa && c.id == _categoriaId);
    if (nombre.isEmpty || !categoriaValida) {
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(
          content: Text('Nombre y categoría son obligatorios'),
          backgroundColor: PosiaColors.cancelar,
        ),
      );
      return;
    }
    final costo = parsearPrecioTexto(_costoController.text) ?? 0.0;
    final errorMenudeo = errorPrecioVentaDesdeTexto(
      _precioController.text,
      costoUnitario: costo,
    );
    if (errorMenudeo != null) {
      PosiaNotificaciones.mostrarSnackBar(
        context,
        SnackBar(
          content: Text(errorMenudeo),
          backgroundColor: PosiaColors.cancelar,
        ),
      );
      return;
    }
    for (final escala in _vendePorPeso ? const <_EscalaEditable>[] : _escalas) {
      if (escala.precioController.text.trim().isEmpty) {
        continue;
      }
      final errorEscala = errorPrecioVentaDesdeTexto(
        escala.precioController.text,
        costoUnitario: costo,
      );
      if (errorEscala != null) {
        PosiaNotificaciones.mostrarSnackBar(
          context,
          SnackBar(
            content: Text('Mayoreo: $errorEscala'),
            backgroundColor: PosiaColors.cancelar,
          ),
        );
        return;
      }
    }
    if (_vendePorPeso) {
      for (final corte in _cortesPeso) {
        final pesoTexto = corte.pesoController.text.trim();
        final precioTexto = corte.precioCorteController.text.trim();
        final porKgTexto = corte.precioPorKgController.text.trim();
        if (pesoTexto.isEmpty && precioTexto.isEmpty && porKgTexto.isEmpty) {
          continue;
        }
        final peso = parsearPrecioTexto(pesoTexto);
        if (peso == null || peso <= 0.0 || peso >= pesoKiloCompleto) {
          PosiaNotificaciones.mostrarSnackBar(
            context,
            SnackBar(
              content: Text(
                'Cada presentación a granel debe tener un peso '
                'entre 0 y 1 kg (ej. 0.1).',
              ),
              backgroundColor: PosiaColors.cancelar,
            ),
          );
          return;
        }
        if (precioTexto.isEmpty && porKgTexto.isEmpty) {
          PosiaNotificaciones.mostrarSnackBar(
            context,
            const SnackBar(
              content: Text(
                'Indique el precio por kg o el precio del peso '
                'en cada presentación.',
              ),
              backgroundColor: PosiaColors.cancelar,
            ),
          );
          return;
        }
        final errorCorte = errorPrecioPresentacionDesdeTexto(
          corte.precioCorteController.text,
          costoUnitario: costo,
          factorABase: peso,
          obligatorio: false,
        );
        if (errorCorte != null) {
          PosiaNotificaciones.mostrarSnackBar(
            context,
            SnackBar(
              content: Text(
                '${_formatearCantidadEscala(peso)} kg: $errorCorte',
              ),
              backgroundColor: PosiaColors.cancelar,
            ),
          );
          return;
        }
      }
    }
    setState(() => _guardando = true);
    try {
      final servicio = await ref.read(servicioAdminProvider.future);
      final precio = parsearPrecioTexto(_precioController.text) ?? 0.0;
      final empaqueLegacy = await _resolverEmpaqueLegacy(servicio);
      if (_esEdicion) {
        final base = widget.productoExistente!;
        final actualizado = base.copiarCon(
          nombre: nombre,
          codigoBarras: _codigoController.text.trim(),
          precioBase: precio,
          costoUnitario: costo,
          categoriaId: _categoriaId,
          unidadMedida: _unidad,
          piezasPorCaja: empaqueLegacy.piezasPorCaja,
          unidadesPorBulto: empaqueLegacy.unidadesPorBulto,
          proveedorId: _proveedorId,
          notas: _notasController.text.trim(),
          activo: _activo,
          permiteStockNegativo: _permiteStockNegativo,
        );
        await servicio.actualizarProducto(
          actualizado,
          escalasMayoreo: _parseEscalas(actualizado.id),
        );
        await servicio.sincronizarPresentacionesProducto(actualizado.id);
        final minimo = double.tryParse(_minimoController.text) ?? 0.0;
        await servicio.configurarStockMinimo(actualizado.id, minimo);
      } else {
        final codigo = _codigoController.text.trim();
        if (codigo.isNotEmpty) {
          final existente = await servicio.buscarProductoPorCodigoBarras(
            codigo,
          );
          if (existente != null && mounted) {
            final editar = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Producto ya registrado'),
                content: Text(
                  'El codigo de barras "$codigo" ya pertenece a '
                  '"${existente.nombre}" '
                  '(${formatearMoneda(existente.precioBase)}).\n\n'
                  'Para cambiar el precio, edite ese producto. '
                  'No cree un producto nuevo con el mismo codigo.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Editar producto'),
                  ),
                ],
              ),
            );
            if (!mounted) {
              return;
            }
            if (editar == true) {
              Navigator.pop(context);
              await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      PantallaFormularioProducto(productoExistente: existente),
                ),
              );
              return;
            }
            return;
          }
        }
        final escalasNuevas = _parseEscalas('');
        final legacyAlta = _empaquesPendientes.isNotEmpty
            ? (piezasPorCaja: null, unidadesPorBulto: null)
            : empaqueLegacy;
        final producto = await servicio.registrarProductoCompleto(
          AltaProductoRequest(
            nombre: nombre,
            codigoBarras: _codigoController.text.trim(),
            precioBase: precio,
            costoUnitario: costo,
            categoriaId: _categoriaId!,
            unidadMedida: _unidad,
            piezasPorCaja: legacyAlta.piezasPorCaja,
            unidadesPorBulto: legacyAlta.unidadesPorBulto,
            proveedorId: _proveedorId,
            notas: _notasController.text.trim(),
            activo: _activo,
            stockInicial: double.tryParse(_stockController.text) ?? 0.0,
            stockMinimo: double.tryParse(_minimoController.text) ?? 0.0,
            escalasMayoreo: escalasNuevas,
            permiteStockNegativo: _permiteStockNegativo,
          ),
        );
        if (_empaquesPendientes.isNotEmpty) {
          await guardarEmpaquesPendientes(
            servicio: servicio,
            productoId: producto.id,
            empaques: _empaquesPendientes,
          );
          await servicio.actualizarProducto(
            producto.copiarCon(
              piezasPorCaja: empaqueLegacy.piezasPorCaja,
              unidadesPorBulto: empaqueLegacy.unidadesPorBulto,
            ),
          );
        }
      }
      await refrescarDatosMaestros(ref);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on StateError catch (e) {
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        SnackBar(
          content: Text(e.message),
          backgroundColor: PosiaColors.cancelar,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  bool get _vozDisponibleEnPlataforma => Platform.isAndroid || Platform.isIOS;

  Future<void> _mostrarAyudaVoz() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dictar producto por voz'),
        content: const SingleChildScrollView(
          child: Text(
            'Disponible en iPhone y Android.\n\n'
            '1. Toca el micrófono.\n'
            '2. Di el producto en una sola frase.\n'
            '3. Revisa el resumen y confirma.\n'
            '4. Corrige lo necesario y guarda.\n\n'
            'Ejemplos:\n'
            '• Coca Cola precio 25 costo 18 categoría refrescos stock 40\n'
            '• Jitomate por kilo a 35 pesos medio kilo 20 cuarto 12\n'
            '• Arroz código 750123 precio 28.50 mayoreo desde 10 a 25\n'
            '• Leche precio veintiocho proveedor Nestlé mínimo 5\n\n'
            'Puedes dictar nombre, código, categoría, proveedor, '
            'unidad, costo, precio, medio/cuarto kilo, stock, mínimo, '
            'mayoreo y notas. Si una categoría o proveedor no existe, '
            'el resto se aplica y te avisa para elegirlo a mano.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<bool> _asegurarPermisosVozAndroid() async {
    var mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      mic = await Permission.microphone.request();
    }
    if (!mic.isGranted) {
      if (!mounted) {
        return false;
      }
      if (mic.isPermanentlyDenied) {
        await _mostrarDialogoIrAjustes(
          'Micrófono bloqueado',
          'Actívalo en Ajustes → Aplicaciones → La Fortuna → Micrófono.',
        );
      } else {
        PosiaNotificaciones.mostrarSnackBar(
          context,
          const SnackBar(
            content: Text('Micrófono requerido'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _mostrarAyudaPermisosVozIos() async {
    await _mostrarDialogoIrAjustes(
      'Micrófono bloqueado',
      'Para dictar productos, La Fortuna necesita acceso al micrófono y al '
          'reconocimiento de voz.\n\n'
          '1. Toca el micrófono otra vez y acepta cuando iOS lo pida.\n'
          '2. Si ya lo rechazaste: Ajustes → La Fortuna → activa Micrófono y '
          'Reconocimiento de voz.',
    );
  }

  Future<void> _mostrarDialogoIrAjustes(String titulo, String mensaje) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Future<void> _alternarEscuchaVoz() async {
    if (_escuchandoVoz) {
      await _finalizarEscuchaVoz();
      return;
    }
    if (!_vozDisponibleEnPlataforma) {
      if (!mounted) {
        return;
      }
      PosiaNotificaciones.mostrarSnackBar(
        context,
        const SnackBar(
          content: Text(
            'El dictado por voz está disponible en iPhone y Android.',
          ),
        ),
      );
      return;
    }
    if (!Platform.isIOS) {
      final permisosOk = await _asegurarPermisosVozAndroid();
      if (!permisosOk) {
        return;
      }
    }
    if (!_vozInicializada) {
      final ok = await _servicioVoz.inicializar();
      _vozInicializada = ok;
      if (!ok) {
        if (!mounted) {
          return;
        }
        if (Platform.isIOS) {
          await _mostrarAyudaPermisosVozIos();
        } else {
          PosiaNotificaciones.mostrarSnackBar(
            context,
            SnackBar(
              content: Text(
                _servicioVoz.ultimoError ??
                    'Voz no disponible en este dispositivo',
              ),
            ),
          );
        }
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _escuchandoVoz = true;
      _transcripcionVoz = '';
    });
    await _servicioVoz.escuchar(
      onTranscripcion: (texto, esFinal) {
        if (!mounted) {
          return;
        }
        setState(() => _transcripcionVoz = texto);
        if (esFinal && texto.trim().isNotEmpty) {
          unawaited(_finalizarEscuchaVoz(procesarTexto: texto));
        }
      },
    );
  }

  Future<void> _finalizarEscuchaVoz({String? procesarTexto}) async {
    if (_finalizandoVoz) {
      return;
    }
    _finalizandoVoz = true;
    try {
      final texto = (procesarTexto ?? _transcripcionVoz).trim();
      await _servicioVoz.detener();
      if (!mounted) {
        return;
      }
      setState(() {
        _escuchandoVoz = false;
        _transcripcionVoz = texto;
      });
      if (texto.isNotEmpty) {
        await _aplicarDictadoProducto(texto);
      } else if (mounted) {
        setState(() => _transcripcionVoz = '');
      }
    } finally {
      _finalizandoVoz = false;
    }
  }

  Future<void> _aplicarDictadoProducto(String texto) async {
    final borrador = _interpretadorVoz.interpretar(texto);
    if (!mounted) {
      return;
    }
    if (!borrador.tieneDatos) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No entendí el dictado'),
          content: const Text(
            'Di algo como:\n\n'
            '• "Coca Cola precio 25 costo 18 categoría refrescos stock 40"\n'
            '• "Jitomate por kilo a 35 pesos medio kilo 20"\n'
            '• "Arroz código 750123 precio 28.50 mayoreo desde 10 a 25"',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() => _transcripcionVoz = '');
      }
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Aplicar dictado?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"$texto"',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12.0),
              ...borrador.lineasResumen.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• $l'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar al formulario'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) {
      setState(() => _transcripcionVoz = '');
      return;
    }
    final categorias = ref.read(categoriasFormularioAdminProvider).value ?? [];
    final proveedores =
        ref.read(proveedoresFormularioAdminProvider).value ?? [];
    final avisos = <String>[];
    setState(() {
      avisos.addAll(
        _rellenarDesdeBorrador(
          borrador,
          categorias: categorias,
          proveedores: proveedores,
        ),
      );
      _irAPestanaSegunBorrador(borrador);
      _transcripcionVoz = '';
    });
    if (!mounted) {
      return;
    }
    final mensaje = avisos.isEmpty
        ? 'Dictado aplicado. Revisa los campos y guarda.'
        : 'Dictado aplicado. ${avisos.join(' ')}';
    PosiaNotificaciones.mostrarSnackBar(
      context,
      SnackBar(
        content: Text(mensaje),
        duration: Duration(seconds: avisos.isEmpty ? 3 : 5),
        backgroundColor: avisos.isEmpty ? null : Colors.orange.shade800,
      ),
    );
  }

  void _irAPestanaSegunBorrador(BorradorProductoVoz borrador) {
    final campos = borrador.camposDetectados;
    final soloInventario = campos.every((c) => c == 'stock' || c == 'minimo');
    if (soloInventario && campos.isNotEmpty) {
      _tabs.animateTo(3);
      return;
    }
    final tocaPrecios = campos.any(
      (c) =>
          c == 'precio' ||
          c == 'costo' ||
          c == 'medio' ||
          c == 'cuarto' ||
          c == 'escalas',
    );
    final tocaGeneral = campos.any(
      (c) =>
          c == 'nombre' ||
          c == 'codigo' ||
          c == 'categoria' ||
          c == 'proveedor' ||
          c == 'unidad' ||
          c == 'notas',
    );
    if (tocaPrecios && !tocaGeneral) {
      _tabs.animateTo(1);
    } else {
      _tabs.animateTo(0);
    }
  }

  /// Rellena el formulario. Devuelve avisos (categoria/proveedor no encontrados).
  List<String> _rellenarDesdeBorrador(
    BorradorProductoVoz borrador, {
    required List<Categoria> categorias,
    required List<Proveedor> proveedores,
  }) {
    final avisos = <String>[];
    if (borrador.nombre != null && borrador.nombre!.trim().isNotEmpty) {
      _nombreController.text = borrador.nombre!.trim();
    }
    if (borrador.codigoBarras != null &&
        borrador.codigoBarras!.trim().isNotEmpty) {
      _codigoController.text = borrador.codigoBarras!.trim();
    }
    if (borrador.unidadMedida != null) {
      _unidad = borrador.unidadMedida!;
    }
    if (borrador.precioBase != null) {
      _precioController.text = borrador.precioBase!.toStringAsFixed(2);
    }
    if (borrador.costoUnitario != null) {
      _costoController.text = borrador.costoUnitario!.toStringAsFixed(2);
    }
    if (borrador.stockInicial != null && !_esEdicion) {
      _stockController.text = _formatearCantidadEscala(borrador.stockInicial!);
    }
    if (borrador.stockMinimo != null) {
      _minimoController.text = _formatearCantidadEscala(borrador.stockMinimo!);
    }
    if (borrador.notas != null && borrador.notas!.trim().isNotEmpty) {
      _notasController.text = borrador.notas!.trim();
    }
    if (borrador.precioMedioKilo != null || borrador.precioCuartoKilo != null) {
      for (final corte in _cortesPeso) {
        corte.dispose();
      }
      _cortesPeso.clear();
      if (borrador.precioCuartoKilo != null) {
        _cortesPeso.add(
          _CortePesoEditable.desdeCorte(
            pesoKg: pesoCuartoKilo,
            precioCorte: borrador.precioCuartoKilo!,
            formatearPeso: _formatearCantidadEscala,
          ),
        );
      }
      if (borrador.precioMedioKilo != null) {
        _cortesPeso.add(
          _CortePesoEditable.desdeCorte(
            pesoKg: pesoMedioKilo,
            precioCorte: borrador.precioMedioKilo!,
            formatearPeso: _formatearCantidadEscala,
          ),
        );
      }
    }
    if (borrador.nombreCategoria != null) {
      final id = _resolverIdPorNombre(
        borrador.nombreCategoria!,
        categorias.map((c) => (id: c.id, nombre: c.nombre, activa: c.activa)),
      );
      if (id != null) {
        _categoriaId = id;
      } else {
        avisos.add(
          'No hallé la categoría "${borrador.nombreCategoria}". Elígela manualmente.',
        );
      }
    }
    if (borrador.nombreProveedor != null) {
      final id = _resolverIdPorNombre(
        borrador.nombreProveedor!,
        proveedores.map((p) => (id: p.id, nombre: p.nombre, activa: true)),
      );
      if (id != null) {
        _proveedorId = id;
      } else {
        avisos.add(
          'No hallé el proveedor "${borrador.nombreProveedor}". Elígelo manualmente.',
        );
      }
    }
    if (borrador.escalasMayoreo.isNotEmpty && !_vendePorPeso) {
      for (final e in _escalas) {
        e.dispose();
      }
      _escalas
        ..clear()
        ..addAll(
          borrador.escalasMayoreo.map(
            (e) => _EscalaEditable(
              cantidadController: TextEditingController(
                text: _formatearCantidadEscala(e.cantidadMinima),
              ),
              precioController: TextEditingController(
                text: e.precioUnitario.toStringAsFixed(2),
              ),
            ),
          ),
        );
    }
    return avisos;
  }

  String? _resolverIdPorNombre(
    String hablado,
    Iterable<({String id, String nombre, bool activa})> catalogo,
  ) {
    final q = normalizarTextoBusqueda(hablado).trim();
    if (q.isEmpty) {
      return null;
    }
    String? exacto;
    String? parcial;
    var empatesParciales = 0;
    for (final item in catalogo) {
      if (!item.activa) {
        continue;
      }
      final n = normalizarTextoBusqueda(item.nombre).trim();
      if (n == q) {
        exacto = item.id;
        break;
      }
      if (n.contains(q) || q.contains(n)) {
        empatesParciales++;
        parcial ??= item.id;
      }
    }
    if (exacto != null) {
      return exacto;
    }
    // Solo aceptar parcial si no hay ambiguedad.
    if (empatesParciales == 1) {
      return parcial;
    }
    return null;
  }
}

class _EscalaEditable {
  _EscalaEditable({
    required this.cantidadController,
    required this.precioController,
  });

  factory _EscalaEditable.vacia() {
    return _EscalaEditable(
      cantidadController: TextEditingController(),
      precioController: TextEditingController(),
    );
  }

  final TextEditingController cantidadController;
  final TextEditingController precioController;

  void dispose() {
    cantidadController.dispose();
    precioController.dispose();
  }
}

class _CortePesoEditable {
  _CortePesoEditable({
    required this.pesoController,
    required this.precioPorKgController,
    required this.precioCorteController,
  });

  factory _CortePesoEditable.vacio({
    double? pesoKg,
    String Function(double)? formatearPeso,
  }) {
    final formatear =
        formatearPeso ??
        (double v) => v == v.roundToDouble()
            ? v.toStringAsFixed(0)
            : v
                  .toStringAsFixed(3)
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), '');
    return _CortePesoEditable(
      pesoController: TextEditingController(
        text: pesoKg != null ? formatear(pesoKg) : '',
      ),
      precioPorKgController: TextEditingController(),
      precioCorteController: TextEditingController(),
    );
  }

  factory _CortePesoEditable.desdeCorte({
    required double pesoKg,
    required double precioCorte,
    required String Function(double) formatearPeso,
  }) {
    final porKg = precioPorKgDesdePrecioCorte(
      precioCorte: precioCorte,
      pesoKg: pesoKg,
    );
    return _CortePesoEditable(
      pesoController: TextEditingController(text: formatearPeso(pesoKg)),
      precioPorKgController: TextEditingController(
        text: porKg.toStringAsFixed(2),
      ),
      precioCorteController: TextEditingController(
        text: precioCorte.toStringAsFixed(2),
      ),
    );
  }

  final TextEditingController pesoController;
  final TextEditingController precioPorKgController;
  final TextEditingController precioCorteController;
  bool _sincronizando = false;

  void sincronizarDesdePrecioPorKg() {
    if (_sincronizando) {
      return;
    }
    final peso = parsearPrecioTexto(pesoController.text);
    final porKg = parsearPrecioTexto(precioPorKgController.text);
    if (peso == null || peso <= 0.0 || porKg == null || porKg <= 0.0) {
      return;
    }
    _sincronizando = true;
    precioCorteController.text = precioCorteDesdePrecioPorKg(
      precioPorKg: porKg,
      pesoKg: peso,
    ).toStringAsFixed(2);
    _sincronizando = false;
  }

  void sincronizarDesdePrecioCorte() {
    if (_sincronizando) {
      return;
    }
    final peso = parsearPrecioTexto(pesoController.text);
    final corte = parsearPrecioTexto(precioCorteController.text);
    if (peso == null || peso <= 0.0 || corte == null || corte <= 0.0) {
      return;
    }
    _sincronizando = true;
    precioPorKgController.text = precioPorKgDesdePrecioCorte(
      precioCorte: corte,
      pesoKg: peso,
    ).toStringAsFixed(2);
    _sincronizando = false;
  }

  void sincronizarDesdePeso() {
    if (_sincronizando) {
      return;
    }
    final peso = parsearPrecioTexto(pesoController.text);
    if (peso == null || peso <= 0.0) {
      return;
    }
    final porKg = parsearPrecioTexto(precioPorKgController.text);
    if (porKg != null && porKg > 0.0) {
      _sincronizando = true;
      precioCorteController.text = precioCorteDesdePrecioPorKg(
        precioPorKg: porKg,
        pesoKg: peso,
      ).toStringAsFixed(2);
      _sincronizando = false;
      return;
    }
    final corte = parsearPrecioTexto(precioCorteController.text);
    if (corte != null && corte > 0.0) {
      _sincronizando = true;
      precioPorKgController.text = precioPorKgDesdePrecioCorte(
        precioCorte: corte,
        pesoKg: peso,
      ).toStringAsFixed(2);
      _sincronizando = false;
    }
  }

  void dispose() {
    pesoController.dispose();
    precioPorKgController.dispose();
    precioCorteController.dispose();
  }
}
