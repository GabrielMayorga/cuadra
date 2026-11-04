-- Pieza 3-2: denominaciones (catálogo global y activas por empresa).
-- esperado: errores=4
-- Recordatorio: un UPDATE/DELETE sin política que lo permita NO lanza error: da "UPDATE 0"/"DELETE 0".
-- Solo un INSERT negado por RLS, o la falta de GRANT, da ERROR.
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''
\set eB '''00000000-0000-0000-0000-00000000000b'''
\set eC '''00000000-0000-0000-0000-00000000000c'''

\set postgres 'reset role;'
\set dueno    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000d1'', true); end $$;'
\set contador 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true); end $$;'
\set cajero   'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c1'', true); end $$;'
\set cajeroB  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000b2'', true); end $$;'
\set resumen 'select count(*) as filas, count(*) filter (where activa) as activas, count(*) filter (where not activa) as inactivas, count(distinct empresa_id) as empresas from public.empresa_denominaciones;'

begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A'), (:eB, 'Empresa B');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'dueno@example.test'),
  ('00000000-0000-0000-0000-0000000000c0', 'contador@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'cajero@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'cajerob@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  ('00000000-0000-0000-0000-0000000000d1', :eA, 'Dueño A', 'dueno'),
  ('00000000-0000-0000-0000-0000000000c0', :eA, 'Contador A', 'contador'),
  ('00000000-0000-0000-0000-0000000000c1', :eA, 'Cajero A', 'cajero'),
  ('00000000-0000-0000-0000-0000000000b2', :eB, 'Cajero B', 'cajero');

\echo '=== 1. El catálogo tiene 18 (total 18 | NIO 12 | USD 6 | billetes 13 | monedas 5), leído por el cajero'
:cajero
select count(*) as total,
       count(*) filter (where moneda = 'NIO') as nio,
       count(*) filter (where moneda = 'USD') as usd,
       count(*) filter (where tipo = 'billete') as billetes,
       count(*) filter (where tipo = 'moneda') as monedas
from public.denominaciones;

\echo '=== 2. Empresa nueva recibe 18 activas por el trigger (C: 18 | 18 | 0), vista como postgres'
:postgres
insert into public.empresas (id, nombre) values (:eC, 'Empresa C');
select count(*) as filas, count(*) filter (where activa) as activas, count(*) filter (where not activa) as inactivas
from public.empresa_denominaciones where empresa_id = :eC;

\echo '=== 3. Cajero A lee las 18 de su empresa (filas 18 | activas 18 | inactivas 0 | empresas 1)'
:cajero
:resumen

\echo '=== 4. Cajero B no ve las de A: solo las suyas (filas 18 | empresas 1) y de A ve 0'
:cajeroB
:resumen
select count(*) as filas_de_a_visibles from public.empresa_denominaciones where empresa_id = :eA;

\echo '=== 5. Dueño desactiva el billete de C$ 1000 (UPDATE 1)'
:dueno
update public.empresa_denominaciones set activa = false
where empresa_id = :eA
  and denominacion_id = (select id from public.denominaciones where moneda = 'NIO' and valor = 1000.00);
\echo '    Dueño ve (filas 18 | activas 17 | inactivas 1 | empresas 1)'
:resumen

\echo '=== 6. Contador intenta desactivar otra (UPDATE 0: RLS no da error)'
:contador
update public.empresa_denominaciones set activa = false
where empresa_id = :eA
  and denominacion_id = (select id from public.denominaciones where moneda = 'NIO' and valor = 500.00);

\echo '=== 7. Cajero intenta desactivar otra (UPDATE 0: RLS no da error)'
:cajero
update public.empresa_denominaciones set activa = false
where empresa_id = :eA
  and denominacion_id = (select id from public.denominaciones where moneda = 'NIO' and valor = 500.00);
\echo '    Cajero sigue viendo (filas 18 | activas 17 | inactivas 1 | empresas 1): solo cambió la del dueño'
:resumen

\echo '=== 8. Dueño de A intenta desactivar una de la empresa B (UPDATE 0)'
:dueno
update public.empresa_denominaciones set activa = false where empresa_id = :eB;
:postgres
\echo '    Empresa B intacta como postgres (filas 18 | activas 18 | inactivas 0)'
select count(*) as filas, count(*) filter (where activa) as activas, count(*) filter (where not activa) as inactivas
from public.empresa_denominaciones where empresa_id = :eB;

\echo '=== 9. Dueño intenta insertar en empresa_denominaciones (ERROR 1: sin GRANT de insert)'
:dueno
insert into public.empresa_denominaciones (empresa_id, denominacion_id) values (:eA, 1);

\echo '=== 10. Dueño intenta borrar de empresa_denominaciones (ERROR 2: sin GRANT de delete)'
:dueno
delete from public.empresa_denominaciones where empresa_id = :eA;

\echo '=== 11. Dueño intenta cambiar denominacion_id, no solo "activa" (ERROR 3: sin GRANT de columna)'
:dueno
update public.empresa_denominaciones set denominacion_id = 2 where empresa_id = :eA and denominacion_id = 1;

\echo '=== 12. Dueño intenta insertar en el catálogo global (ERROR 4: sin GRANT de insert)'
:dueno
insert into public.denominaciones (moneda, valor, tipo, orden) values ('NIO', 2.00, 'moneda', 99);

\echo '=== 13. Tras los intentos, A sigue igual como postgres (filas 18 | activas 17 | inactivas 1) y catálogo 18'
:postgres
select count(*) as filas, count(*) filter (where activa) as activas, count(*) filter (where not activa) as inactivas
from public.empresa_denominaciones where empresa_id = :eA;
select count(*) as catalogo from public.denominaciones;

rollback;
