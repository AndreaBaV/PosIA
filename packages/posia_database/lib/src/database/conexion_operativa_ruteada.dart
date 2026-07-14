/// Conexion SQLite que enruta lecturas y escrituras a conexiones distintas.
///
/// En modo WAL, una conexion de escritura y una de solo-lectura pueden operar
/// concurrentemente: el escritor (sync/ventas) no bloquea a los lectores de la
/// UI (paneles, reportes) y viceversa. Este envoltorio expone una unica
/// [Database] para no tener que modificar los ~25 repositorios: las consultas
/// (`query`/`rawQuery`/cursores) van a la conexion de lectura y las mutaciones,
/// transacciones y DDL a la de escritura.
library;

import 'package:sqflite/sqflite.dart';

/// [Database] compuesta: lecturas a [_lectura], escrituras a [_escritura].
///
/// Las conexiones subyacentes se pueden reemplazar en caliente (p. ej. tras
/// reabrir la BD por migracion) sin invalidar los repositorios/servicios que
/// ya tienen una referencia a este envoltorio.
class ConexionOperativaRuteada implements Database {
  ConexionOperativaRuteada({
    required Database escritura,
    required Database lectura,
  }) : _escritura = escritura,
       _lectura = lectura;

  Database _escritura;
  Database _lectura;

  /// Sustituye las conexiones cerradas por unas recien abiertas.
  void reemplazarConexiones({
    required Database escritura,
    required Database lectura,
  }) {
    _escritura = escritura;
    _lectura = lectura;
  }

  // --- Lecturas: conexion de solo-lectura (snapshot WAL) ---

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _lectura.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _lectura.rawQuery(sql, arguments);
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    return _lectura.queryCursor(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      bufferSize: bufferSize,
    );
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    return _lectura.rawQueryCursor(sql, arguments, bufferSize: bufferSize);
  }

  // --- Escrituras, DDL y transacciones: conexion de escritura ---

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _escritura.execute(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _escritura.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    return _escritura.rawInsert(sql, arguments);
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _escritura.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    return _escritura.rawUpdate(sql, arguments);
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _escritura.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    return _escritura.rawDelete(sql, arguments);
  }

  @override
  Batch batch() => _escritura.batch();

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    return _escritura.transaction(action, exclusive: exclusive);
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) {
    return _escritura.readTransaction(action);
  }

  // --- Metadatos y ciclo de vida ---

  @override
  Database get database => _escritura;

  @override
  String get path => _escritura.path;

  @override
  bool get isOpen => _escritura.isOpen;

  @override
  Future<void> close() async {
    await _lectura.close();
    await _escritura.close();
  }

  @override
  @Deprecated('Dev only')
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) {
    // ignore: deprecated_member_use
    return _escritura.devInvokeMethod<T>(method, arguments);
  }

  @override
  @Deprecated('Dev only')
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) {
    // ignore: deprecated_member_use
    return _escritura.devInvokeSqlMethod<T>(method, sql, arguments);
  }
}
