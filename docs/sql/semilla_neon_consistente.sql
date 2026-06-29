-- POSIA · Semilla Neon consistente (esquema actual: sin tenant_id, pin_credencial, id = codigo)
--
-- Ejecutar en SQL Editor de Neon (todo el bloque).
-- PINs de prueba:
--   ADM001 → 7291
--   SUP001 → 5847
--   EMP001 → 3068
--
-- Regenerar pin_credencial si cambias PINs:
--   dart run packages/posia_core/tool/gen_admin_pin.dart <PIN>

BEGIN;

-- ── 1. Alinear esquema (legacy multi-tenant / pin_hash+pin_salt) ─────────────
ALTER TABLE stores DROP COLUMN IF EXISTS tenant_id;
ALTER TABLE users DROP COLUMN IF EXISTS tenant_id;
ALTER TABLE sync_events DROP COLUMN IF EXISTS tenant_id;

ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_credencial TEXT;

UPDATE users
SET pin_credencial = pin_salt || ':' || pin_hash
WHERE (pin_credencial IS NULL OR pin_credencial = '')
  AND pin_hash IS NOT NULL
  AND pin_salt IS NOT NULL;

ALTER TABLE users DROP COLUMN IF EXISTS pin_hash;
ALTER TABLE users DROP COLUMN IF EXISTS pin_salt;

DROP INDEX IF EXISTS idx_stores_tenant;
DROP INDEX IF EXISTS idx_users_tenant_codigo;
DROP INDEX IF EXISTS idx_sync_events_tenant_seq;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_codigo_unico ON users(codigo);
CREATE INDEX IF NOT EXISTS idx_users_codigo ON users(codigo);

-- ── 2. Limpiar semilla operativa (conserva sync_events históricos) ───────────
DELETE FROM users;
DELETE FROM almacenes;
DELETE FROM stores;

-- ── 3. Tiendas (IDs legibles) ───────────────────────────────────────────────
INSERT INTO stores (id, nombre, direccion, activa) VALUES
  ('tienda-norte',  'Tienda Norte',  'Av. Norte 100',  1),
  ('tienda-centro', 'Tienda Centro', 'Av. Centro 200', 1),
  ('tienda-sur',    'Tienda Sur',    'Av. Sur 300',    1);

-- ── 4. Almacenes (vinculados a tienda) ────────────────────────────────────────
INSERT INTO almacenes (id, nombre, tienda_id, activo) VALUES
  ('alm-norte',  'Almacén Norte',  'tienda-norte',  1),
  ('alm-centro', 'Almacén Centro', 'tienda-centro', 1),
  ('alm-sur',    'Almacén Sur',    'tienda-sur',    1);

-- ── 5. Usuarios (id = codigo, pin_credencial compacto) ──────────────────────
INSERT INTO users (
  id, nombre, codigo, rol, tienda_id, activo,
  pin_credencial, creado_en, actualizado_en
) VALUES
  (
    'ADM001', 'Arturo',  'ADM001', 'administrador', NULL,            1,
    'khPTll7PhDK0',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  ),
  (
    'SUP001', 'Pedrito', 'SUP001', 'supervisor',    'tienda-centro', 1,
    'fK42pih8L15n',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  ),
  (
    'EMP001', 'Juanito', 'EMP001', 'empleado',      'tienda-centro', 1,
    'T50KlPXwF-iL',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  );

COMMIT;

-- ── 6. Verificación ─────────────────────────────────────────────────────────
SELECT id, nombre, activa FROM stores ORDER BY id;
SELECT id, nombre, tienda_id, activo FROM almacenes ORDER BY id;
SELECT id, codigo, rol, tienda_id, activo,
       length(pin_credencial) AS pin_len
FROM users ORDER BY codigo;
