-- Pieza 1b-5: RLS del núcleo contable.
-- esperado: errores=5
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''

\set dueno    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000d1'', true); end $$;'
\set contador 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true); end $$;'
\set admin    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000ad'', true); end $$;'
\set cajero   'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c1'', true); end $$;'

begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A');
insert into public.negocios (id, empresa_id, nombre) values ('00000000-0000-0000-0000-000000000a01', :eA, 'Negocio A');
insert into public.sucursales (id, empresa_id, negocio_id, codigo, nombre) values ('00000000-0000-0000-0000-0000000a1a01', :eA, '00000000-0000-0000-0000-000000000a01', 'SA1', 'Suc A1');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'dueno@example.test'),
  ('00000000-0000-0000-0000-0000000000c0', 'contador@example.test'),
  ('00000000-0000-0000-0000-0000000000ad', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'cajero@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  ('00000000-0000-0000-0000-0000000000d1', :eA, 'Dueño A', 'dueno'),
  ('00000000-0000-0000-0000-0000000000c0', :eA, 'Contador A', 'contador'),
  ('00000000-0000-0000-0000-0000000000ad', :eA, 'Admin A', 'admin'),
  ('00000000-0000-0000-0000-0000000000c1', :eA, 'Cajero A', 'cajero');

\echo '=== 1. Contador crea la cuenta 5 (INSERT 0 1)'
:contador
insert into public.cuentas (empresa_id, codigo, nombre, tipo, acepta_movimientos, moneda) values (:eA, '5', 'Gasto prueba', 'gasto', true, 'NIO');
select id as c5 from public.cuentas where empresa_id = :eA and codigo = '5' \gset

\echo '=== 2. Dueño intenta crear una cuenta (ERROR 1)'
:dueno
insert into public.cuentas (empresa_id, codigo, nombre, tipo, acepta_movimientos, moneda) values (:eA, '6', 'No debería', 'gasto', true, 'NIO');

\echo '=== 3. Admin intenta crear una cuenta (ERROR 2)'
:admin
insert into public.cuentas (empresa_id, codigo, nombre, tipo, acepta_movimientos, moneda) values (:eA, '7', 'No debería', 'gasto', true, 'NIO');

\echo '=== 4. Cajero no ve ninguna cuenta (0)'
:cajero
select count(*) as cajero_ve from public.cuentas where empresa_id = :eA;

\echo '=== 5. Dueño sí ve la cuenta (1)'
:dueno
select count(*) as dueno_ve from public.cuentas where empresa_id = :eA;

\echo '=== 6. Admin sí ve la cuenta (1)'
:admin
select count(*) as admin_ve from public.cuentas where empresa_id = :eA;

\echo '=== 7. Contador renombra la cuenta (UPDATE 1)'
:contador
update public.cuentas set nombre = 'Gasto prueba (editado)' where id = :'c5';

\echo '=== 8. Dueño intenta renombrarla (UPDATE 0: sin politica, no ve la fila)'
:dueno
update public.cuentas set nombre = 'Hackeado' where id = :'c5';

\echo '=== 9. Contador crea y borra una cuenta sin movimientos (INSERT 0 1 / DELETE 1)'
:contador
insert into public.cuentas (empresa_id, codigo, nombre, tipo, acepta_movimientos, moneda) values (:eA, '9', 'Desechable', 'gasto', true, 'NIO');
delete from public.cuentas where empresa_id = :eA and codigo = '9';

\echo '=== 10. Dueño intenta crear un periodo (ERROR 4)'
:dueno
insert into public.periodos (empresa_id, anio, mes) values (:eA, 2026, 2);

\echo '=== 11. Contador crea el periodo (INSERT 0 1)'
:contador
insert into public.periodos (empresa_id, anio, mes) values (:eA, 2026, 2);

\echo '=== 12. Cajero no ve ningún periodo (0)'
:cajero
select count(*) as cajero_ve from public.periodos where empresa_id = :eA;

\echo '=== 13. Admin sí ve el periodo (1)'
:admin
select count(*) as admin_ve from public.periodos where empresa_id = :eA;

\echo '=== 14. Ni el contador borra un periodo (ERROR por falta de GRANT DELETE, ni siquiera llega a RLS)'
:contador
delete from public.periodos where empresa_id = :eA and anio = 2026 and mes = 2;

\echo '=== 15. Contador registra un asiento balanceado con dos lineas (INSERT 0 1 / INSERT 0 2)'
:contador
insert into public.cuentas (empresa_id, codigo, nombre, tipo, acepta_movimientos, moneda) values
  (:eA, '90', 'Caja prueba', 'activo', true, 'NIO'),
  (:eA, '91', 'Ventas prueba', 'ingreso', true, 'NIO');
select id as cc from public.cuentas where empresa_id = :eA and codigo = '90' \gset
select id as cv from public.cuentas where empresa_id = :eA and codigo = '91' \gset
insert into public.asientos (empresa_id, fecha, descripcion) values (:eA, '2026-02-01', 'Asiento de prueba RLS');
select id as asi from public.asientos where empresa_id = :eA and descripcion = 'Asiento de prueba RLS' \gset
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, sucursal_id, moneda, monto_original, tipo_cambio, debe, haber) values
  (:'asi', :eA, :'cc', '00000000-0000-0000-0000-0000000a1a01', 'NIO', 100.00, 1.00, 100.00, 0),
  (:'asi', :eA, :'cv', '00000000-0000-0000-0000-0000000a1a01', 'NIO', 100.00, 1.00, 0, 100.00);

\echo '=== 16. Dueño intenta crear un asiento (ERROR 5)'
:dueno
insert into public.asientos (empresa_id, fecha, descripcion) values (:eA, '2026-02-02', 'No debería existir');

\echo '=== 17. Cajero no ve el asiento (0)'
:cajero
select count(*) as cajero_ve from public.asientos where empresa_id = :eA;

\echo '=== 18. Admin sí ve el asiento (1)'
:admin
select count(*) as admin_ve from public.asientos where empresa_id = :eA;

\echo '=== 19. Contador borra el asiento en borrador: primero sus lineas, luego el asiento (DELETE 2 / DELETE 1)'
:contador
delete from public.asiento_lineas where asiento_id = :'asi';
delete from public.asientos where id = :'asi';

rollback;
