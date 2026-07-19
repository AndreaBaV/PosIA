/// Lote de promocion mayoreo compartido entre productos.
library;

/// Define umbral y precio unitario aplicables a un grupo de productos.
///
/// Los productos miembros suman cantidad en el carrito: al alcanzar
/// [cantidadMinima] todos reciben [precioUnitario].
class LotePromocion {
  const LotePromocion({
    required this.id,
    required this.codigoExterno,
    required this.cantidadMinima,
    required this.precioUnitario,
    this.nombre = '',
    this.activo = true,
    this.productoIds = const [],
  });

  /// Identificador interno (UUID).
  final String id;

  /// Codigo del archivo de importacion (ej. "1").
  final String codigoExterno;

  /// Nombre descriptivo opcional.
  final String nombre;

  /// Cantidad minima inclusive (piezas base) para activar el precio.
  final double cantidadMinima;

  /// Precio unitario de mayoreo del lote.
  final double precioUnitario;

  /// Indica si el lote esta activo.
  final bool activo;

  /// Productos miembros del lote (puede ir vacio si solo se consulta la escala).
  final List<String> productoIds;

  /// Placeholder creado por integridad FK (sync fuera de orden).
  ///
  /// No es un lote de negocio; no debe proyectarse a Neon. El stub copia el id
  /// en `codigoExterno`, cosa que un alta real nunca hace.
  bool get esStubFk =>
      nombre.trim() == 'Lote promoción' &&
      codigoExterno == id &&
      precioUnitario == 0.0 &&
      productoIds.isEmpty;

  LotePromocion copiarCon({
    String? id,
    String? codigoExterno,
    String? nombre,
    double? cantidadMinima,
    double? precioUnitario,
    bool? activo,
    List<String>? productoIds,
  }) {
    return LotePromocion(
      id: id ?? this.id,
      codigoExterno: codigoExterno ?? this.codigoExterno,
      nombre: nombre ?? this.nombre,
      cantidadMinima: cantidadMinima ?? this.cantidadMinima,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      activo: activo ?? this.activo,
      productoIds: productoIds ?? this.productoIds,
    );
  }
}
