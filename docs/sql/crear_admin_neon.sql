-- Primer administrador en Neon (ejecutar en SQL Editor de Neon).
-- Genera pin_hash y pin_salt con:
--   dart run packages/posia_core/tool/gen_admin_pin.dart
-- (edita el PIN en ese script antes de ejecutarlo)

INSERT INTO users (
  id,
  tenant_id,
  nombre,
  codigo,
  rol,
  tienda_id,
  activo,
  pin_hash,
  pin_salt,
  creado_en,
  actualizado_en
) VALUES (
  gen_random_uuid()::text,
  '',
  'Arturo',
  '1000',
  'administrador',
  NULL,
  1,
  'REEMPLAZA_PIN_HASH',
  'REEMPLAZA_PIN_SALT',
  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
);
