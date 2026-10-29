-- Pieza 1b-1: plan de cuentas.
-- esperado: errores=7
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''
\set eB '''00000000-0000-0000-0000-00000000000b'''
\set c1   '''00000000-0000-0000-0000-00000000c001'''
\set c11  '''00000000-0000-0000-0000-00000000c011'''
\set caja '''00000000-0000-0000-0000-00000000c111'''
begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A'), (:eB, 'Empresa B');
insert into public.cuentas (id, empresa_id, codigo, nombre, tipo, padre_id, acepta_movimientos, moneda) values
  (:c1,   :eA, '1',      'Activo',           'activo', null, false, 'NIO'),
  (:c11,  :eA, '1.1',    'Activo corriente', 'activo', :c1,  false, 'NIO'),
  (:caja, :eA, '1.1.01', 'Caja general C$',  'activo', :c11, true,  'NIO');
insert into public.cuentas (empresa_id, codigo, nombre, tipo, padre_id, moneda)
  values (:eA, '1.1.02', 'Caja general US$', 'activo', :c11, 'USD');
\echo '=== 0. Árbol creado: 4 cuentas (1 y 1.1 agrupadoras; 1.1.02 en USD)'
select codigo, nombre, tipo, acepta_movimientos, moneda from public.cuentas order by codigo;
\echo '=== 1. Subcuenta de gasto bajo activo (ERROR 1)'
insert into public.cuentas (empresa_id, codigo, nombre, tipo, padre_id) values (:eA, '1.1.03', 'Mal clasificada', 'gasto', :c11);
\echo '=== 2. Subcuenta bajo una cuenta que recibe movimientos (ERROR 2)'
insert into public.cuentas (empresa_id, codigo, nombre, tipo, padre_id) values (:eA, '1.1.01.1', 'Caja chica', 'activo', :caja);
\echo '=== 3. Código repetido (ERROR 3)'
insert into public.cuentas (empresa_id, codigo, nombre, tipo, padre_id) values (:eA, '1.1.01', 'Otra caja', 'activo', :c11);
\echo '=== 4. Código con letras (ERROR 4)'
insert into public.cuentas (empresa_id, codigo, nombre, tipo) values (:eA, 'ABC', 'Mal código', 'activo');
\echo '=== 5. Cuenta de B colgando de una cuenta de A (ERROR 5)'
insert into public.cuentas (empresa_id, codigo, nombre, tipo, padre_id) values (:eB, '1.1.09', 'Intrusa', 'activo', :c11);
\echo '=== 6. Cambiar el tipo de una cuenta existente (ERROR 6)'
update public.cuentas set tipo = 'gasto' where id = :caja;
\echo '=== 7. Agrupadora con subcuentas pasa a recibir movimientos (ERROR 7)'
update public.cuentas set acepta_movimientos = true where id = :c11;
\echo '=== 8. Renombrar una cuenta (UPDATE 1)'
update public.cuentas set nombre = 'Caja general córdobas' where id = :caja;
\echo '=== 9. Código con guiones (INSERT 0 1)'
insert into public.cuentas (empresa_id, codigo, nombre, tipo) values (:eA, '2-1', 'Pasivo corriente', 'pasivo');
rollback;
