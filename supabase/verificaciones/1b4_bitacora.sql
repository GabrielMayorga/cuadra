-- Pieza 1b-4: bitácora de auditoría del núcleo contable.
-- esperado: errores=1
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''
\set eB '''00000000-0000-0000-0000-00000000000b'''

\set como_dueno    'select set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000d1'', true);'
\set como_contador 'select set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true);'

\set dueno    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000d1'', true); end $$;'
\set contador 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true); end $$;'
\set cajero1  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c1'', true); end $$;'
\set cajeroB  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000b2'', true); end $$;'

begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A'), (:eB, 'Empresa B');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'dueno@example.test'),
  ('00000000-0000-0000-0000-0000000000c0', 'contador@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'cajero1@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'cajerob@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  ('00000000-0000-0000-0000-0000000000d1', :eA, 'Dueño A', 'dueno'),
  ('00000000-0000-0000-0000-0000000000c0', :eA, 'Contador A', 'contador'),
  ('00000000-0000-0000-0000-0000000000c1', :eA, 'Cajero A1', 'cajero'),
  ('00000000-0000-0000-0000-0000000000b2', :eB, 'Cajero B', 'cajero');

\echo '=== 1. Dueño crea una cuenta -> queda en bitacora (insert, sin datos_antes)'
:como_dueno
insert into public.cuentas (empresa_id, codigo, nombre, tipo, acepta_movimientos) values (:eA, '5', 'Gasto bitácora', 'gasto', true);
select id as cid from public.cuentas where empresa_id = :eA and codigo = '5' \gset
select tabla, operacion, registro_id = :'cid' as registro_ok, datos_antes is null as sin_antes, datos_despues is not null as con_despues, perfil_id
from public.bitacora where tabla = 'cuentas' and registro_id = :'cid' and operacion = 'insert';

\echo '=== 2. Contador renombra esa cuenta -> update con datos_antes y datos_despues distintos'
:como_contador
update public.cuentas set nombre = 'Gasto bitácora (renombrado)' where id = :'cid';
select operacion, datos_antes ->> 'nombre' as antes, datos_despues ->> 'nombre' as despues, perfil_id
from public.bitacora where tabla = 'cuentas' and registro_id = :'cid' and operacion = 'update';

\echo '=== 3. Dueño crea el periodo 2026-01 -> registro_id es "2026-01", no un uuid'
:como_dueno
insert into public.periodos (empresa_id, anio, mes) values (:eA, 2026, 1);
select tabla, operacion, registro_id, datos_antes is null as sin_antes
from public.bitacora where tabla = 'periodos' and registro_id = '2026-01' and operacion = 'insert';

\echo '=== 4. Contador cierra ese periodo -> update, datos_despues con estado cerrado'
:como_contador
update public.periodos set estado = 'cerrado', cerrado_en = now() where empresa_id = :eA and anio = 2026 and mes = 1;
select operacion, datos_antes ->> 'estado' as antes, datos_despues ->> 'estado' as despues
from public.bitacora where tabla = 'periodos' and registro_id = '2026-01' and operacion = 'update';

\echo '=== 5. Dueño y contador ven la bitácora de su empresa (4 filas cada uno)'
:dueno
select count(*) as dueno_ve from public.bitacora where empresa_id = :eA;
:contador
select count(*) as contador_ve from public.bitacora where empresa_id = :eA;

\echo '=== 6. Cajero de la misma empresa NO ve nada (0 filas, por rol)'
:cajero1
select count(*) as cajero_ve from public.bitacora where empresa_id = :eA;

\echo '=== 7. Cajero de la empresa B tampoco (0 filas, por rol y por empresa)'
:cajeroB
select count(*) as cajero_b_ve from public.bitacora where empresa_id = :eA;

\echo '=== 8. Dueño intenta corregir una fila a mano (UPDATE 0: sin politica, no ve la fila para tocarla)'
:dueno
update public.bitacora set datos_despues = '{}'::jsonb where tabla = 'cuentas' and registro_id = :'cid' and operacion = 'insert';

\echo '=== 9. Dueño intenta borrar una fila (DELETE 0: sin politica, no ve la fila para borrarla)'
:dueno
delete from public.bitacora where tabla = 'cuentas' and registro_id = :'cid';

\echo '=== 10. Contador intenta insertar en bitacora sin pasar por el trigger (ERROR 1)'
:contador
insert into public.bitacora (empresa_id, tabla, registro_id, operacion, datos_despues) values (:eA, 'cuentas', 'x', 'insert', '{}'::jsonb);

rollback;
