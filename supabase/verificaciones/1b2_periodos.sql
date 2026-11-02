-- Pieza 1b-2: periodos contables.
-- esperado: errores=5
\set ON_ERROR_ROLLBACK on
\set eA '''00000000-0000-0000-0000-00000000000a'''
begin;
insert into public.empresas (id, nombre) values (:eA, 'Empresa A');
insert into public.periodos (empresa_id, anio, mes) values (:eA, 2026, 9), (:eA, 2026, 10), (:eA, 2026, 11);
\echo '=== 1. Cerrar octubre con septiembre abierto (ERROR 1)'
update public.periodos set estado = 'cerrado' where empresa_id = :eA and anio = 2026 and mes = 10;
\echo '=== 2. Cerrar septiembre y luego octubre (UPDATE 1 y UPDATE 1)'
update public.periodos set estado = 'cerrado' where empresa_id = :eA and anio = 2026 and mes = 9;
update public.periodos set estado = 'cerrado' where empresa_id = :eA and anio = 2026 and mes = 10;
\echo '=== 3. Reabrir septiembre con octubre cerrado (ERROR 2)'
update public.periodos set estado = 'abierto' where empresa_id = :eA and anio = 2026 and mes = 9;
\echo '=== 4. Bloquear noviembre, que sigue abierto (ERROR 3)'
update public.periodos set estado = 'bloqueado' where empresa_id = :eA and anio = 2026 and mes = 11;
\echo '=== 5. Bloquear septiembre (UPDATE 1) y luego reabrirlo (ERROR 4)'
update public.periodos set estado = 'bloqueado' where empresa_id = :eA and anio = 2026 and mes = 9;
update public.periodos set estado = 'abierto' where empresa_id = :eA and anio = 2026 and mes = 9;
\echo '=== 6. Crear un periodo ya cerrado (ERROR 5)'
insert into public.periodos (empresa_id, anio, mes, estado) values (:eA, 2026, 12, 'cerrado');
\echo '=== 7. Estado final: 9 bloqueado t | 10 cerrado t | 11 abierto f'
select mes, estado, cerrado_en is not null as tiene_fecha_cierre from public.periodos where empresa_id = :eA order by mes;
\echo '=== 8. ¿Se puede registrar? oct=f | nov=t | ago=f | dic=t'
select private.periodo_abierto(:eA, '2026-10-15') as oct, private.periodo_abierto(:eA, '2026-11-02') as nov,
       private.periodo_abierto(:eA, '2026-08-10') as ago, private.periodo_abierto(:eA, '2026-12-01') as dic;
rollback;
