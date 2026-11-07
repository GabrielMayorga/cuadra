-- Seed de DESARROLLO. Se aplica automáticamente con `supabase db reset`.
-- Nombres de ejemplo; UUIDs fijos y legibles para poder referenciarlos en scripts y pruebas.
-- Los usuarios de Auth y sus perfiles los crea scripts/crear-usuarios-dev.ts (pnpm db:seed-usuarios).

-- ---------- empresa ----------
insert into public.empresas (id, nombre, ruc) values
  ('de000000-0000-0000-0000-00000000e001', 'Comercial Ejemplo S.A.', 'J0000000000001');

-- ---------- negocios ----------
insert into public.negocios (id, empresa_id, nombre) values
  ('de000000-0000-0000-0000-000000000a01', 'de000000-0000-0000-0000-00000000e001', 'Ferretería Ejemplo'),
  ('de000000-0000-0000-0000-000000000a02', 'de000000-0000-0000-0000-00000000e001', 'Cafetería Ejemplo');

-- ---------- sucursales ----------
insert into public.sucursales (id, empresa_id, negocio_id, codigo, nombre) values
  ('de000000-0000-0000-0000-0000000a1a01', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-000000000a01', 'FER1', 'Ferretería Centro'),
  ('de000000-0000-0000-0000-0000000a1a02', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-000000000a01', 'FER2', 'Ferretería Norte'),
  ('de000000-0000-0000-0000-0000000a2a01', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-000000000a02', 'CAF1', 'Cafetería Plaza'),
  ('de000000-0000-0000-0000-0000000a2a02', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-000000000a02', 'CAF2', 'Cafetería Sur');

-- ---------- cajas (7) ----------
insert into public.cajas (id, empresa_id, sucursal_id, numero, nombre) values
  ('de000000-0000-0000-0000-00000ca1a011', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a1a01', 1, 'Caja 1'),
  ('de000000-0000-0000-0000-00000ca1a012', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a1a01', 2, 'Caja 2'),
  ('de000000-0000-0000-0000-00000ca1a021', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a1a02', 1, 'Caja 1'),
  ('de000000-0000-0000-0000-00000ca2a011', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a2a01', 1, 'Caja 1'),
  ('de000000-0000-0000-0000-00000ca2a012', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a2a01', 2, 'Caja 2'),
  ('de000000-0000-0000-0000-00000ca2a021', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a2a02', 1, 'Caja 1'),
  ('de000000-0000-0000-0000-00000ca2a022', 'de000000-0000-0000-0000-00000000e001', 'de000000-0000-0000-0000-0000000a2a02', 2, 'Caja 2');

-- ---------- módulos ----------
-- El trigger de empresas ya creó una fila por módulo del catálogo (sin contratar).
update public.empresa_modulos
   set contratado = true, activo = true
 where empresa_id = 'de000000-0000-0000-0000-00000000e001';
