-- Pieza 6: políticas RLS.
-- esperado: errores=8
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''
\set eB '''00000000-0000-0000-0000-00000000000b'''
\set dueno    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000d1'', true); end $$;'
\set contador 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true); end $$;'
\set admin    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000ad'', true); end $$;'
\set encargado 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000e1'', true); end $$;'
\set cajero1  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c1'', true); end $$;'
\set cajeroB  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000b2'', true); end $$;'
\set conteos 'select (select count(*) from public.empresas) as empresas, (select count(*) from public.negocios) as negocios, (select count(*) from public.sucursales) as sucursales, (select count(*) from public.cajas) as cajas, (select count(*) from public.perfiles) as perfiles, (select count(*) from public.perfil_sucursales) as asignaciones, (select count(*) from public.tipos_cambio) as tc;'

begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A'), (:eB, 'Empresa B');
insert into public.negocios (id, empresa_id, nombre) values
  ('00000000-0000-0000-0000-000000000a01', :eA, 'Negocio A1'),
  ('00000000-0000-0000-0000-000000000a02', :eA, 'Negocio A2'),
  ('00000000-0000-0000-0000-000000000b01', :eB, 'Negocio B');
insert into public.sucursales (id, empresa_id, negocio_id, codigo, nombre) values
  ('00000000-0000-0000-0000-0000000a1a01', :eA, '00000000-0000-0000-0000-000000000a01', 'SA1', 'Suc A1'),
  ('00000000-0000-0000-0000-0000000a1a02', :eA, '00000000-0000-0000-0000-000000000a01', 'SA2', 'Suc A2'),
  ('00000000-0000-0000-0000-0000000a1a03', :eA, '00000000-0000-0000-0000-000000000a02', 'SA3', 'Suc A3'),
  ('00000000-0000-0000-0000-0000000b1b01', :eB, '00000000-0000-0000-0000-000000000b01', 'SB1', 'Suc B1');
insert into public.cajas (empresa_id, sucursal_id, numero, nombre) values
  (:eA, '00000000-0000-0000-0000-0000000a1a01', 1, 'Caja 1'),
  (:eA, '00000000-0000-0000-0000-0000000a1a01', 2, 'Caja 2'),
  (:eA, '00000000-0000-0000-0000-0000000a1a02', 1, 'Caja 1'),
  (:eB, '00000000-0000-0000-0000-0000000b1b01', 1, 'Caja 1');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'dueno@example.test'),
  ('00000000-0000-0000-0000-0000000000c0', 'contador@example.test'),
  ('00000000-0000-0000-0000-0000000000ad', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'encargado@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'cajero1@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'cajero3@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'cajerob@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  ('00000000-0000-0000-0000-0000000000d1', :eA, 'Dueño A', 'dueno'),
  ('00000000-0000-0000-0000-0000000000c0', :eA, 'Contador A', 'contador'),
  ('00000000-0000-0000-0000-0000000000ad', :eA, 'Admin A', 'admin'),
  ('00000000-0000-0000-0000-0000000000e1', :eA, 'Encargado A1', 'encargado'),
  ('00000000-0000-0000-0000-0000000000c1', :eA, 'Cajero A1', 'cajero'),
  ('00000000-0000-0000-0000-0000000000c3', :eA, 'Cajero A2', 'cajero'),
  ('00000000-0000-0000-0000-0000000000b2', :eB, 'Cajero B', 'cajero');
insert into public.perfil_sucursales (empresa_id, perfil_id, sucursal_id) values
  (:eA, '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000a1a01'),
  (:eA, '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000a1a01'),
  (:eA, '00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000a1a02'),
  (:eB, '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000b1b01');
insert into public.tipos_cambio (empresa_id, fecha, tc_oficial, tc_caja) values
  (:eA, '2026-10-16', 36.6243, 36.60), (:eB, '2026-10-16', 36.6243, 36.60);
update public.empresa_modulos set contratado = true where empresa_id = :eA and modulo = 'arqueo';

\echo '=== 1. Cajero A1 (suc A1): empresas 1 | negocios 1 | sucursales 1 | cajas 2 | perfiles 1 | asignaciones 1 | tc 1'
:cajero1
:conteos
\echo '=== 2. Contador (global A): 1 | 2 | 3 | 3 | 6 | 3 | 1'
:contador
:conteos
\echo '=== 3. Encargado A1: 1 | 1 | 1 | 2 | 2 | 2 | 1'
:encargado
:conteos
\echo '=== 4. Cajero de la empresa B ve SOLO lo suyo: 1 | 1 | 1 | 1 | 1 | 1 | 1'
:cajeroB
:conteos
\echo '=== 4b. Cajero B consulta cajas de la empresa A: 0'
select count(*) as cajas_de_A from public.cajas where empresa_id = :eA;

\echo '=== 5. Cajero intenta crear una caja (ERROR 1: row-level security)'
:cajero1
insert into public.cajas (empresa_id, sucursal_id, numero, nombre)
  values (:eA, '00000000-0000-0000-0000-0000000a1a01', 9, 'Intrusa');
\echo '=== 6. Cajero intenta registrar tipo de cambio (ERROR 2: row-level security)'
:cajero1
insert into public.tipos_cambio (empresa_id, fecha, tc_oficial, tc_caja) values (:eA, '2026-10-17', 36.70, 36.70);
\echo '=== 7a. Contador registra tipo de cambio (INSERT 0 1)'
:contador
insert into public.tipos_cambio (empresa_id, fecha, tc_oficial, tc_caja) values (:eA, '2026-10-17', 36.6300, 36.60);
\echo '=== 7b. Contador intenta crear una caja (ERROR 3: row-level security)'
:contador
insert into public.cajas (empresa_id, sucursal_id, numero, nombre)
  values (:eA, '00000000-0000-0000-0000-0000000a1a02', 2, 'Intrusa');
\echo '=== 8a. Admin crea una caja en su empresa (INSERT 0 1)'
:admin
insert into public.cajas (empresa_id, sucursal_id, numero, nombre)
  values (:eA, '00000000-0000-0000-0000-0000000a1a02', 2, 'Caja 2');
\echo '=== 8b. Admin intenta crear una caja en la empresa B (ERROR 4: row-level security)'
:admin
insert into public.cajas (empresa_id, sucursal_id, numero, nombre)
  values (:eB, '00000000-0000-0000-0000-0000000b1b01', 2, 'Intrusa');
\echo '=== 8c. Admin intenta corregir el tipo de cambio (UPDATE 0)'
:admin
update public.tipos_cambio set tc_caja = 40 where empresa_id = :eA;
\echo '=== 9a. Dueño edita el nombre de su empresa (UPDATE 1)'
:dueno
update public.empresas set nombre = 'Empresa A S.A.' where id = :eA;
\echo '=== 9b. Dueño intenta desactivar su empresa (ERROR 5: permission denied)'
:dueno
update public.empresas set activa = false where id = :eA;
\echo '=== 9c. Dueño intenta borrar cajas (ERROR 6: permission denied)'
:dueno
delete from public.cajas;
\echo '=== 9d. Dueño intenta crear una sucursal en la empresa B (ERROR 7: row-level security)'
:dueno
insert into public.sucursales (empresa_id, negocio_id, codigo, nombre)
  values (:eB, '00000000-0000-0000-0000-000000000b01', 'ROBA', 'Intrusa');
\echo '=== 9e. Dueño activa un módulo contratado (UPDATE 1)'
:dueno
update public.empresa_modulos set activo = true where empresa_id = :eA and modulo = 'arqueo';
\echo '=== 9f. ...y uno no contratado (ERROR 8: check constraint)'
update public.empresa_modulos set activo = true where empresa_id = :eA and modulo = 'planilla';
\echo '=== 10a. Cajero intenta editar su propio perfil (UPDATE 0)'
:cajero1
update public.perfiles set nombre = 'Hackeado' where id = '00000000-0000-0000-0000-0000000000c1';
\echo '=== 10b. Cajero intenta quitarse una asignación (DELETE 0)'
:cajero1
delete from public.perfil_sucursales where perfil_id = '00000000-0000-0000-0000-0000000000c1';
\echo '=== 10c. Admin quita la asignación del cajero 3 (DELETE 1)'
:admin
delete from public.perfil_sucursales where perfil_id = '00000000-0000-0000-0000-0000000000c3';

reset role;
\echo '=== 11a. Tablas de public SIN RLS (0 filas)'
select c.relname from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and not c.relrowsecurity;
\echo '=== 11b. Tablas con RLS sin políticas (0 filas; o solo tablas del núcleo contable mientras no exista la 1b-5)'
select c.relname from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid);
\echo '=== 11c. Total de políticas (22)'
select count(*) as politicas from pg_policies where schemaname = 'public';
rollback;
