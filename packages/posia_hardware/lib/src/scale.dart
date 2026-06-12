/// Contrato de bascula comercial.
///
/// Autor: Equipo POSIA
/// Matricula: POSIA-2026-001
/// Fecha creacion: 2026-06-07 18:30:00 (UTC-6)
/// Ultima modificacion: 2026-06-07 18:30:00 (UTC-6)
library;

/// Lee peso estable desde bascula conectada.
abstract class Scale {
	/// Flujo de peso en gramos cuando lectura es estable.
	Stream<double> get pesoEstableGramos;

	/// Conecta driver de bascula configurado.
	Future<void> conectar();

	/// Desconecta bascula y libera recursos.
	Future<void> desconectar();
}
