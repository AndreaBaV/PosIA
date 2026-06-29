-- Primer administrador en Neon (ejecutar en SQL Editor de Neon).
-- Genera pin_credencial con:
--   dart run packages/posia_core/tool/gen_admin_pin.dart 7291

INSERT INTO users (
  id,
  nombre,
  codigo,
  rol,
  tienda_id,
  activo,
  pin_credencial,
  creado_en,
  actualizado_en
) VALUES (
  'ADM001',
  'Arturo',
  'ADM001',
  'administrador',
  NULL,
  1,
  'REEMPLAZA_PIN_CREDENCIAL',
  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
);
