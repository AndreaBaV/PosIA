/// Pruebas de validacion de precios contra costo.
library;

import 'package:test/test.dart';
import 'package:posia_core/posia_core.dart';

void main() {
  test('calcularPrecioMinimoVenta aplica margen sobre costo', () {
    expect(calcularPrecioMinimoVenta(100.0), 101.0);
    expect(calcularPrecioMinimoVenta(0.0), 0.01);
  });

  test('precioVentaEsValido rechaza precio bajo costo', () {
    expect(precioVentaEsValido(100.0, 100.0), false);
    expect(precioVentaEsValido(101.0, 100.0), true);
    expect(precioVentaEsValido(50.0, 100.0), false);
  });

  test('calcularPrecioVentaDesdeUtilidad sobre costo', () {
    expect(
      calcularPrecioVentaDesdeUtilidad(
        costoUnitario: 100.0,
        porcentajeUtilidad: 25.0,
        modo: ModoCalculoUtilidad.sobreCosto,
      ),
      125.0,
    );
  });

  test('calcularPrecioVentaDesdeUtilidad sobre precio venta', () {
    expect(
      calcularPrecioVentaDesdeUtilidad(
        costoUnitario: 75.0,
        porcentajeUtilidad: 25.0,
        modo: ModoCalculoUtilidad.sobrePrecioVenta,
      ),
      100.0,
    );
  });

  test('calcularUtilidadPorcentaje es inverso del calculo', () {
    const costo = 80.0;
    const precio = 100.0;
    expect(
      calcularUtilidadPorcentaje(
        costoUnitario: costo,
        precioVenta: precio,
        modo: ModoCalculoUtilidad.sobreCosto,
      ),
      25.0,
    );
    expect(
      calcularUtilidadPorcentaje(
        costoUnitario: costo,
        precioVenta: precio,
        modo: ModoCalculoUtilidad.sobrePrecioVenta,
      ),
      20.0,
    );
  });

  test('precioPresentacionEsValido valida precio total del paquete', () {
    expect(calcularPrecioMinimoPresentacion(10.0, 12.0), 121.2);
    expect(precioPresentacionEsValido(120.0, 10.0, 12.0), false);
    expect(precioPresentacionEsValido(121.2, 10.0, 12.0), true);
  });

  test(
    'calcularPrecioSugeridoPresentacion usa escala mayoreo si coincide factor',
    () {
      const escalas = [
        (cantidadMinima: 12.0, precioUnitario: 8.0),
        (cantidadMinima: 24.0, precioUnitario: 7.5),
      ];
      expect(
        calcularPrecioSugeridoPresentacion(
          factorABase: 12.0,
          precioMenudeo: 10.0,
          escalasMayoreo: escalas,
        ),
        96.0,
      );
      expect(
        calcularPrecioSugeridoPresentacion(
          factorABase: 20.0,
          precioMenudeo: 10.0,
          escalasMayoreo: escalas,
        ),
        200.0,
      );
    },
  );

  group('seleccionarEscalaMayoreoPorCantidad', () {
    const escalasPeso = [
      (cantidadMinima: 0.0, precioUnitario: 80.0),
      (cantidadMinima: 1.0, precioUnitario: 70.0),
    ];

    test('medio kilo usa tramo de fraccion', () {
      expect(
        resolverPrecioConEscalas(
          precioBase: 70.0,
          cantidad: 0.5,
          escalas: escalasPeso,
        ),
        80.0,
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 70.0,
                cantidad: 0.5,
                escalas: escalasPeso,
              ) *
              0.5,
        ),
        40.0,
      );
    });

    test('un kilo o mas usa tramo completo', () {
      expect(
        resolverPrecioConEscalas(
          precioBase: 80.0,
          cantidad: 1.0,
          escalas: escalasPeso,
        ),
        70.0,
      );
      expect(
        resolverPrecioConEscalas(
          precioBase: 80.0,
          cantidad: 1.5,
          escalas: escalasPeso,
        ),
        70.0,
      );
    });

    test('sin tramo aplicable usa precio base', () {
      expect(
        resolverPrecioConEscalas(
          precioBase: 70.0,
          cantidad: 0.5,
          escalas: const [],
        ),
        70.0,
      );
    });
  });

  group('empaque y fusion por peso', () {
    test('empaque gana sobre escala manual en mismo umbral', () {
      final fusionadas = fusionarEscalasMayoreo(
        escalasMayoreo: const [(cantidadMinima: 20.0, precioUnitario: 27.0)],
        escalasEmpaque: const [(cantidadMinima: 20.0, precioUnitario: 25.0)],
      );
      expect(fusionadas, hasLength(1));
      expect(fusionadas.first.precioUnitario, 25.0);
    });

    test('26 kg califica tramo de bulto 20 kg', () {
      final escalas = fusionarEscalasMayoreo(
        escalasMayoreo: const [],
        escalasEmpaque: const [(cantidadMinima: 20.0, precioUnitario: 25.0)],
      );
      expect(
        resolverPrecioConEscalas(
          precioBase: 27.0,
          cantidad: 26.0,
          escalas: escalas,
        ),
        25.0,
      );
    });

    test('granel con bulto no usa fusion promedio', () {
      expect(
        productoUsaFusionPromedioPeso(
          moduloVertical: ModuloVertical.general,
          escalas: const [(cantidadMinima: 20.0, precioUnitario: 25.0)],
        ),
        isFalse,
      );
    });

    test('cortes fraccionados si usan fusion promedio', () {
      expect(
        productoUsaFusionPromedioPeso(
          moduloVertical: ModuloVertical.general,
          escalas: construirEscalasDesdePreciosCorte(
            precioKilo: 30.0,
            precioMedio: 20.0,
          ),
        ),
        isTrue,
      );
    });
  });

  group('precios de corte por peso', () {
    test('construye escalas desde kilo, medio y cuarto', () {
      final escalas = construirEscalasDesdePreciosCorte(
        precioKilo: 30.0,
        precioMedio: 20.0,
        precioCuarto: 22.0,
      );
      expect(
        resolverPrecioConEscalas(
          precioBase: 30.0,
          cantidad: 0.25,
          escalas: escalas,
        ),
        88.0,
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 30.0,
                cantidad: 0.25,
                escalas: escalas,
              ) *
              0.25,
        ),
        22.0,
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 30.0,
                cantidad: 0.5,
                escalas: escalas,
              ) *
              0.5,
        ),
        20.0,
      );
      expect(
        resolverPrecioConEscalas(
          precioBase: 30.0,
          cantidad: 1.0,
          escalas: escalas,
        ),
        30.0,
      );
    });

    test('solo medio kilo aplica el mismo rate a cualquier fraccion', () {
      final escalas = construirEscalasDesdePreciosCorte(
        precioKilo: 30.0,
        precioMedio: 20.0,
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 30.0,
                cantidad: 0.25,
                escalas: escalas,
              ) *
              0.25,
        ),
        10.0,
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 30.0,
                cantidad: 0.5,
                escalas: escalas,
              ) *
              0.5,
        ),
        20.0,
      );
    });

    test('extrae precios de corte desde escalas almacenadas', () {
      final escalas = construirEscalasDesdePreciosCorte(
        precioKilo: 30.0,
        precioMedio: 20.0,
        precioCuarto: 22.0,
      );
      final cortes = extraerPreciosCorteDesdeEscalas(
        escalas: escalas,
        precioBase: 30.0,
      );
      expect(cortes.precioKilo, 30.0);
      expect(cortes.precioMedio, 20.0);
      expect(cortes.precioCuarto, 22.0);
      expect(cortes.cortes, hasLength(2));
    });

    test('extrae solo medio cuando no hay tramo de cuarto', () {
      final escalas = construirEscalasDesdePreciosCorte(
        precioKilo: 30.0,
        precioMedio: 20.0,
      );
      final cortes = extraerPreciosCorteDesdeEscalas(
        escalas: escalas,
        precioBase: 30.0,
      );
      expect(cortes.precioKilo, 30.0);
      expect(cortes.precioMedio, 20.0);
      expect(cortes.precioCuarto, isNull);
      expect(cortes.cortes, hasLength(1));
      expect(cortes.cortes.first.pesoKg, pesoMedioKilo);
    });

    test('soporta cortes arbitrarios como 0.1 kg con round-trip', () {
      final escalas = construirEscalasDesdeCortes(
        precioKilo: 200.0,
        cortes: const [
          (pesoKg: 0.1, precioCorte: 25.0),
          (pesoKg: 0.25, precioCorte: 40.0),
          (pesoKg: 0.5, precioCorte: 70.0),
        ],
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 200.0,
                cantidad: 0.1,
                escalas: escalas,
              ) *
              0.1,
        ),
        25.0,
      );
      expect(
        redondearMonto(
          resolverPrecioConEscalas(
                precioBase: 200.0,
                cantidad: 0.05,
                escalas: escalas,
              ) *
              0.05,
        ),
        12.5,
      );
      final extraidos = extraerCortesFraccionDesdeEscalas(escalas);
      expect(extraidos, hasLength(3));
      expect(extraidos[0].pesoKg, closeTo(0.1, 0.001));
      expect(extraidos[0].precioCorte, 25.0);
      expect(extraidos[1].pesoKg, closeTo(0.25, 0.001));
      expect(extraidos[1].precioCorte, 40.0);
      expect(extraidos[2].pesoKg, closeTo(0.5, 0.001));
      expect(extraidos[2].precioCorte, 70.0);
    });

    test('extrae formato legado sin marcador de peso en 0.25', () {
      final escalasLegadas = <EscalaMayoreoRef>[
        (cantidadMinima: 0.0, precioUnitario: 88.0),
        (cantidadMinima: 0.5, precioUnitario: 40.0),
        (cantidadMinima: 1.0, precioUnitario: 30.0),
      ];
      final cortes = extraerPreciosCorteDesdeEscalas(
        escalas: escalasLegadas,
        precioBase: 30.0,
      );
      expect(cortes.precioCuarto, 22.0);
      expect(cortes.precioMedio, 20.0);
    });
  });

  test('errorPrecioVentaDesdeTexto interpreta coma decimal', () {
    expect(errorPrecioVentaDesdeTexto('101,00', costoUnitario: 100.0), isNull);
    expect(
      errorPrecioVentaDesdeTexto('100,00', costoUnitario: 100.0),
      isNotNull,
    );
  });
}
