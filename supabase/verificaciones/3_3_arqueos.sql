-- Pieza 3-3: arqueos con conteo ciego, transiciones y bitácora.
-- esperado: errores=20
-- Recordatorio: un UPDATE/DELETE sin política que lo permita NO lanza error: da "UPDATE 0"/"DELETE 0".
-- Solo un INSERT negado por RLS, un RAISE de trigger/función o la falta de GRANT dan ERROR.
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''
\set s1 '''00000000-0000-0000-0000-0000000f1a01'''
\set s2 '''00000000-0000-0000-0000-0000000f1a02'''
\set caja11 '''00000000-0000-0000-0000-00000cf1a011'''
\set caja12 '''00000000-0000-0000-0000-00000cf1a012'''
\set caja13 '''00000000-0000-0000-0000-00000cf1a013'''
\set caja21 '''00000000-0000-0000-0000-00000cf1a021'''

\set postgres 'reset role;'
\set dueno    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000d1'', true); end $$;'
\set contador 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true); end $$;'
\set admin    'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000ad'', true); end $$;'
\set cajeroA  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c1'', true); end $$;'
\set cajeroB  'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c3'', true); end $$;'
\set encargado 'reset role; set local role authenticated; do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000e1'', true); end $$;'

begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A');
insert into public.negocios (id, empresa_id, nombre) values
  ('00000000-0000-0000-0000-000000000f01', :eA, 'Negocio A1');
insert into public.sucursales (id, empresa_id, negocio_id, codigo, nombre) values
  (:s1, :eA, '00000000-0000-0000-0000-000000000f01', 'SA1', 'Suc A1'),
  (:s2, :eA, '00000000-0000-0000-0000-000000000f01', 'SA2', 'Suc A2');
insert into public.cajas (id, empresa_id, sucursal_id, numero, nombre, activa) values
  (:caja11, :eA, :s1, 1, 'Caja 1', true),
  (:caja12, :eA, :s1, 2, 'Caja 2 inactiva', false),
  (:caja13, :eA, :s1, 3, 'Caja 3', true),
  (:caja21, :eA, :s2, 1, 'Caja 1', true);
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000d1', 'dueno@example.test'),
  ('00000000-0000-0000-0000-0000000000c0', 'contador@example.test'),
  ('00000000-0000-0000-0000-0000000000ad', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'cajeroa@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'cajerob@example.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'encargado@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  ('00000000-0000-0000-0000-0000000000d1', :eA, 'Dueño A', 'dueno'),
  ('00000000-0000-0000-0000-0000000000c0', :eA, 'Contador A', 'contador'),
  ('00000000-0000-0000-0000-0000000000ad', :eA, 'Admin A', 'admin'),
  ('00000000-0000-0000-0000-0000000000c1', :eA, 'Cajero A', 'cajero'),
  ('00000000-0000-0000-0000-0000000000c3', :eA, 'Cajero B', 'cajero'),
  ('00000000-0000-0000-0000-0000000000e1', :eA, 'Encargado A', 'encargado');
insert into public.perfil_sucursales (empresa_id, perfil_id, sucursal_id) values
  (:eA, '00000000-0000-0000-0000-0000000000c1', :s1),
  (:eA, '00000000-0000-0000-0000-0000000000c3', :s2),
  (:eA, '00000000-0000-0000-0000-0000000000e1', :s1);
-- El billete de US$ 1 queda inactivo para la empresa: no se cuenta ni se acepta.
update public.empresa_denominaciones set activa = false
where empresa_id = :eA
  and denominacion_id = (select id from public.denominaciones where moneda = 'USD' and valor = 1.00);

-- "hoy" según la zona horaria de la empresa (única fuente: private.fecha_negocio).
select private.fecha_negocio(:eA) as hoy \gset

\echo '=== 1. Cajero A abre el arqueo de hoy sin mandar fecha (correlativo_ok t | estado abierto | abierto_por_ok t)'
:cajeroA
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja11);
select correlativo = 'SA1-C1-' || to_char(:'hoy'::date, 'YYYYMMDD') as correlativo_ok,
       fecha = :'hoy'::date as fecha_ok,
       estado,
       abierto_por = '00000000-0000-0000-0000-0000000000c1' as abierto_por_ok
from public.arqueos where caja_id = :caja11;
:postgres
select id as aid from public.arqueos where caja_id = :caja11 \gset

\echo '=== 2. Cajero A abre uno con fecha de ayer (ERROR 1: solo el arqueo de hoy)'
:cajeroA
insert into public.arqueos (empresa_id, caja_id, fecha) values (:eA, :caja11, :'hoy'::date - 1);

\echo '=== 3. Segundo arqueo de la misma caja el mismo día (ERROR 2: llave duplicada caja_id, fecha)'
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja11);

\echo '=== 4. Arqueo en caja inactiva (ERROR 3: la caja está inactiva)'
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja12);

-- 4b y 4c usan caja13 (activa, sucursal de A, sin arqueo hoy): sin el grant de columnas el insert pasaría.
\echo '=== 4b. Cajero A abre arqueo mandando estado = contado (ERROR 4: permission denied, sin grant de la columna estado)'
insert into public.arqueos (empresa_id, caja_id, estado) values (:eA, :caja13, 'contado');
\echo '=== 4c. Cajero A abre arqueo mandando un correlativo inventado (ERROR 5: permission denied, sin grant de la columna correlativo)'
insert into public.arqueos (empresa_id, caja_id, correlativo) values (:eA, :caja13, 'INVENTADO-1');

\echo '=== 5. Cajero B no ve el arqueo de A (0)'
:cajeroB
select count(*) as arqueos_visibles from public.arqueos;
\echo '=== 5b. Cajero B abre arqueo en la caja de la sucursal de A (ERROR 6: row-level security)'
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja11);

\echo '=== 6. El dueño intenta abrir un arqueo (ERROR 7: solo consulta)'
:dueno
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja21);

\echo '=== 6b. Encargado de la sucursal 1 abre arqueo en caja13 de su sucursal (OK, correlativo_ok t)'
:encargado
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja13);
select correlativo = 'SA1-C3-' || to_char(:'hoy'::date, 'YYYYMMDD') as correlativo_ok from public.arqueos where caja_id = :caja13;
\echo '=== 6c. Encargado de la sucursal 1 abre arqueo en la sucursal 2 (ERROR 8: row-level security)'
insert into public.arqueos (empresa_id, caja_id) values (:eA, :caja21);

\echo '=== 7. Cajero A registra cantidades: 2 líneas OK (INSERT 0 1 x2)'
:cajeroA
insert into public.arqueo_conteo (arqueo_id, empresa_id, denominacion_id, cantidad)
select :'aid', :eA, d.id, 3 from public.denominaciones d where d.moneda = 'NIO' and d.valor in (1000.00, 500.00);
\echo '=== 7b. Cantidad -1 (ERROR 9: viola check cantidad >= 0)'
insert into public.arqueo_conteo (arqueo_id, empresa_id, denominacion_id, cantidad)
select :'aid', :eA, d.id, -1 from public.denominaciones d where d.moneda = 'NIO' and d.valor = 200.00;
\echo '=== 7c. Denominación inactiva, US$ 1 (ERROR 10: no está activa para la empresa)'
insert into public.arqueo_conteo (arqueo_id, empresa_id, denominacion_id, cantidad)
select :'aid', :eA, d.id, 1 from public.denominaciones d where d.moneda = 'USD' and d.valor = 1.00;

-- NIO 200 está activa y el arqueo sigue abierto: el trigger deja pasar y quien rechaza es la RLS.
\echo '=== 7d. Cajero B inserta una línea en el conteo de A (ERROR 11: row-level security)'
:cajeroB
insert into public.arqueo_conteo (arqueo_id, empresa_id, denominacion_id, cantidad)
select :'aid', :eA, d.id, 5 from public.denominaciones d where d.moneda = 'NIO' and d.valor = 200.00;
\echo '=== 7e. Cajero B consulta las líneas del conteo de A (0)'
select count(*) as lineas_visibles from public.arqueo_conteo where arqueo_id = :'aid';
\echo '=== 7f. Cajero B envía el conteo de A con el arqueo abierto (ERROR 12: no es de tu sucursal)'
select public.enviar_conteo(:'aid');
\echo '=== 7g. El dueño envía el conteo de A (ERROR 13: tu rol no puede enviar el conteo)'
:dueno
select public.enviar_conteo(:'aid');

:cajeroA
\echo '=== 8. Envío con denominaciones faltantes (ERROR 14: lista las 15 que faltan, de NIO 200.00 a USD 5.00)'
select public.enviar_conteo(:'aid');

\echo '=== 9. Completa las activas que faltan (algunas en 0) y envía: INSERT 0 15, luego estado contado | contado_por_ok t | contado_en_ok t | 17 líneas, 5 en cero'
insert into public.arqueo_conteo (arqueo_id, empresa_id, denominacion_id, cantidad)
select :'aid', :eA, ed.denominacion_id, case when d.orden % 3 = 0 then 0 else 2 end
from public.empresa_denominaciones ed
join public.denominaciones d on d.id = ed.denominacion_id
where ed.empresa_id = :eA and ed.activa
  and not exists (select 1 from public.arqueo_conteo c where c.arqueo_id = :'aid' and c.denominacion_id = ed.denominacion_id);
select public.enviar_conteo(:'aid');
select estado,
       contado_por = '00000000-0000-0000-0000-0000000000c1' as contado_por_ok,
       contado_en is not null as contado_en_ok
from public.arqueos where id = :'aid';
select count(*) as lineas, count(*) filter (where cantidad = 0) as en_cero from public.arqueo_conteo where arqueo_id = :'aid';

\echo '=== 10. Cajero A cambia una cantidad ya enviada (ERROR 15: el conteo ya fue enviado)'
update public.arqueo_conteo set cantidad = 99 where arqueo_id = :'aid';
\echo '=== 10b. UPDATE directo a arqueos (ERROR 16: permission denied, sin grant)'
update public.arqueos set estado = 'abierto' where id = :'aid';

\echo '=== 11. Cajero A intenta reabrir (ERROR 17: solo contadora o admin)'
select public.reabrir_conteo(:'aid', 'quiero corregir');
\echo '=== 11b. Contador reabre sin motivo (ERROR 18: indica el motivo)'
:contador
select public.reabrir_conteo(:'aid', '   ');
\echo '=== 11c. Contador reabre con motivo (estado abierto | contado_por vacío | motivo guardado)'
select public.reabrir_conteo(:'aid', 'Billetes de C$ 200 mal contados');
select estado, contado_por is null as contado_por_vacio, contado_en is null as contado_en_vacio, reabierto_motivo
from public.arqueos where id = :'aid';

\echo '=== 12. Contador abre un arqueo de fecha pasada (OK, correlativo SA2-C1 con la fecha de hace 2 días)'
insert into public.arqueos (empresa_id, caja_id, fecha) values (:eA, :caja21, :'hoy'::date - 2);
select correlativo = 'SA2-C1-' || to_char(:'hoy'::date - 2, 'YYYYMMDD') as correlativo_ok from public.arqueos where caja_id = :caja21;
\echo '=== 12b. Contador abre uno de fecha futura (ERROR 19: fecha futura)'
insert into public.arqueos (empresa_id, caja_id, fecha) values (:eA, :caja21, :'hoy'::date + 2);
\echo '=== 12c. Admin abre uno de fecha pasada (OK) y ve los 4 arqueos de la empresa (arqueos_visibles 4)'
:admin
insert into public.arqueos (empresa_id, caja_id, fecha) values (:eA, :caja21, :'hoy'::date - 3);
select count(*) as arqueos_visibles from public.arqueos;

\echo '=== 13. Empresa sin ninguna denominación activa: su contador abre un arqueo (OK) y envía el conteo (ERROR 20: la empresa no tiene denominaciones activas)'
:postgres
insert into public.empresas (id, nombre) values ('00000000-0000-0000-0000-00000000000b', 'Empresa B');
insert into public.negocios (id, empresa_id, nombre) values
  ('00000000-0000-0000-0000-000000000f02', '00000000-0000-0000-0000-00000000000b', 'Negocio B1');
insert into public.sucursales (id, empresa_id, negocio_id, codigo, nombre) values
  ('00000000-0000-0000-0000-0000000f1b01', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000f02', 'SB1', 'Suc B1');
insert into public.cajas (id, empresa_id, sucursal_id, numero, nombre) values
  ('00000000-0000-0000-0000-00000cf1b011', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000f1b01', 1, 'Caja 1');
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000c9', 'contadorb@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  ('00000000-0000-0000-0000-0000000000c9', '00000000-0000-0000-0000-00000000000b', 'Contador B', 'contador');
update public.empresa_denominaciones set activa = false where empresa_id = '00000000-0000-0000-0000-00000000000b';
reset role; set local role authenticated; do $$ begin perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000c9', true); end $$;
insert into public.arqueos (empresa_id, caja_id) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000cf1b011');
select public.enviar_conteo((select id from public.arqueos));

\echo '=== 14. Bitácora (vista por el contador): arqueo_conteo insert Cajero A 17 | arqueos insert: Admin A 1, Cajero A 1, Contador A 1, Encargado A 1 | arqueos update: Cajero A 1 (envío), Contador A 1 (reapertura)'
:contador
select b.tabla, b.operacion, p.nombre as perfil, count(*) as filas
from public.bitacora b
left join public.perfiles p on p.id = b.perfil_id
where b.tabla in ('arqueos', 'arqueo_conteo')
group by b.tabla, b.operacion, p.nombre
order by b.tabla, b.operacion, p.nombre;

rollback;

-- Cuenta final: ERROR esperados = 20 (los numerados arriba).
