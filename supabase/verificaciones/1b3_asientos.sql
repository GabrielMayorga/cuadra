-- Pieza 1b-3: asientos en partida doble (arqueo real del 16 oct).
-- esperado: errores=12
\set ON_ERROR_ROLLBACK on
\set eA       '''00000000-0000-0000-0000-00000000000a'''
\set neg      '''00000000-0000-0000-0000-000000000a01'''
\set suc      '''00000000-0000-0000-0000-0000000a1a01'''
\set uC       '''00000000-0000-0000-0000-0000000000c0'''
\set uK       '''00000000-0000-0000-0000-0000000000c1'''
\set g1       '''00000000-0000-0000-0000-00000000c001'''
\set g11      '''00000000-0000-0000-0000-00000000c011'''
\set cajaC    '''00000000-0000-0000-0000-00000000c111'''
\set cajaU    '''00000000-0000-0000-0000-00000000c112'''
\set g4       '''00000000-0000-0000-0000-00000000c004'''
\set ventas   '''00000000-0000-0000-0000-00000000c041'''
\set sobrante '''00000000-0000-0000-0000-00000000c042'''
\set a1       '''00000000-0000-0000-0000-0000000a5e01'''
\set a2       '''00000000-0000-0000-0000-0000000a5e02'''
\set a3       '''00000000-0000-0000-0000-0000000a5e03'''
\set contadora 'do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c0'', true); end $$;'
\set cajero    'do $$ begin perform set_config(''request.jwt.claim.sub'', ''00000000-0000-0000-0000-0000000000c1'', true); end $$;'
begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A');
insert into public.negocios (id, empresa_id, nombre) values (:neg, :eA, 'Veterinaria Demo');
insert into public.sucursales (id, empresa_id, negocio_id, codigo, nombre) values (:suc, :eA, :neg, 'RAMA', 'El Rama');
insert into auth.users (id, email) values (:uC, 'contadora@example.test'), (:uK, 'cajero@example.test');
insert into public.perfiles (id, empresa_id, nombre, rol) values
  (:uC, :eA, 'Contadora Demo', 'contador'), (:uK, :eA, 'Cajero Demo', 'cajero');
insert into public.cuentas (id, empresa_id, codigo, nombre, tipo, padre_id, acepta_movimientos, moneda) values
  (:g1,       :eA, '1',      'Activo',            'activo',  null, false, 'NIO'),
  (:g11,      :eA, '1.1',    'Activo corriente',  'activo',  :g1,  false, 'NIO'),
  (:cajaC,    :eA, '1.1.01', 'Caja C$',           'activo',  :g11, true,  'NIO'),
  (:cajaU,    :eA, '1.1.02', 'Caja US$',          'activo',  :g11, true,  'USD'),
  (:g4,       :eA, '4',      'Ingresos',          'ingreso', null, false, 'NIO'),
  (:ventas,   :eA, '4.1',    'Ventas',            'ingreso', :g4,  true,  'NIO'),
  (:sobrante, :eA, '4.2',    'Sobrantes de caja', 'ingreso', :g4,  true,  'NIO');
:contadora
\echo '=== 1. Asiento del arqueo en borrador con 4 líneas (INSERT 0 1 / INSERT 0 4)'
insert into public.asientos (id, empresa_id, fecha, descripcion) values (:a1, :eA, '2026-10-16', 'Arqueo RAMA-C2-20261016');
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, sucursal_id, moneda, monto_original, tipo_cambio, debe, haber) values
  (:a1, :eA, :cajaU,    :suc, 'USD',  1540.00, 36.60, 56364.00,        0),
  (:a1, :eA, :cajaC,    :suc, 'NIO', 22900.00,     1, 22900.00,        0),
  (:a1, :eA, :ventas,   :suc, 'NIO', 79184.94,     1,        0, 79184.94),
  (:a1, :eA, :sobrante, :suc, 'NIO',    79.06,     1,        0,    79.06);
\echo '=== 2. Negocio llenado desde la sucursal (4)'
select count(*) as lineas_con_negocio from public.asiento_lineas where asiento_id = :a1 and negocio_id = :neg;
\echo '=== 3. US$ 100 x 36.60 como C$ 3,600 (ERROR 1)'
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, moneda, monto_original, tipo_cambio, debe) values (:a1, :eA, :cajaU, 'USD', 100.00, 36.60, 3600.00);
\echo '=== 4. Línea en cuenta agrupadora (ERROR 2)'
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, monto_original, debe) values (:a1, :eA, :g11, 10, 10);
\echo '=== 5. Córdobas en la cuenta de dólares (ERROR 3)'
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, monto_original, debe) values (:a1, :eA, :cajaU, 10, 10);
\echo '=== 6. Debe y haber a la vez (ERROR 4)'
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, monto_original, debe, haber) values (:a1, :eA, :cajaC, 10, 10, 10);
\echo '=== 7. Contabilizar un asiento descuadrado (ERROR 5)'
insert into public.asientos (id, empresa_id, fecha, descripcion) values (:a2, :eA, '2026-10-16', 'Descuadrado');
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, monto_original, debe, haber) values
  (:a2, :eA, :cajaC, 100, 100, 0), (:a2, :eA, :ventas, 90, 0, 90);
update public.asientos set estado = 'contabilizado' where id = :a2;
\echo '=== 8. Contabilizar el arqueo -> 2026 | 1 | contabilizado | t'
update public.asientos set estado = 'contabilizado' where id = :a1;
select ejercicio, numero, estado, contabilizado_por = :uC as por_contadora from public.asientos where id = :a1;
\echo '=== 9. Editar el asiento contabilizado (ERROR 6)'
update public.asientos set descripcion = 'Cambiado' where id = :a1;
\echo '=== 10. Agregarle una línea (ERROR 7)'
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, monto_original, debe) values (:a1, :eA, :cajaC, 1, 1);
\echo '=== 11. Borrarlo (ERROR 8)'
delete from public.asientos where id = :a1;
\echo '=== 12. El cajero intenta revertirlo (ERROR 9)'
:cajero
select public.revertir_asiento(:a1, '2026-10-20', 'Prueba');
\echo '=== 13. La contadora lo revierte (t)'
:contadora
select public.revertir_asiento(:a1, '2026-10-20', 'Conteo de dólares mal registrado') is not null as revertido;
\echo '=== 14. Libro diario: 1 manual y 2 reversion, ambos 79264.00 | 79264.00'
select a.numero, a.origen, sum(l.debe) as debe, sum(l.haber) as haber
  from public.asientos a join public.asiento_lineas l on l.asiento_id = a.id
 where a.estado = 'contabilizado' group by a.numero, a.origen order by a.numero;
\echo '=== 15. Saldos tras la reversión: todas las cuentas en 0.00'
select c.codigo, sum(l.debe - l.haber) as saldo
  from public.asiento_lineas l
  join public.asientos a on a.id = l.asiento_id and a.estado = 'contabilizado'
  join public.cuentas c on c.id = l.cuenta_id
 group by c.codigo order by c.codigo;
\echo '=== 16. Revertirlo otra vez (ERROR 10)'
select public.revertir_asiento(:a1, '2026-10-21', 'Otra vez');
\echo '=== 17. Caja con movimientos pasa a agrupadora (ERROR 11)'
update public.cuentas set acepta_movimientos = false where id = :cajaC;
\echo '=== 18. Cerrar octubre (UPDATE 1) y contabilizar un asiento del 25 oct (ERROR 12)'
insert into public.periodos (empresa_id, anio, mes) values (:eA, 2026, 10);
update public.periodos set estado = 'cerrado' where empresa_id = :eA and anio = 2026 and mes = 10;
insert into public.asientos (id, empresa_id, fecha, descripcion) values (:a3, :eA, '2026-10-25', 'Tardío');
insert into public.asiento_lineas (asiento_id, empresa_id, cuenta_id, monto_original, debe, haber) values
  (:a3, :eA, :cajaC, 50, 50, 0), (:a3, :eA, :ventas, 50, 0, 50);
update public.asientos set estado = 'contabilizado' where id = :a3;
\echo '=== 19. Correlativo sin huecos: {1,2} | borradores 2'
select array_agg(numero order by numero) filter (where estado = 'contabilizado') as numeros,
       count(*) filter (where estado = 'borrador') as borradores
  from public.asientos where empresa_id = :eA;
rollback;
