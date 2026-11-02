-- Pieza 1b-5: RLS del núcleo contable.
-- Dueño, contador y admin ven cuentas/periodos/asientos/asiento_lineas de
-- su empresa. Solo el contador crea, edita y borra en estas tablas; las
-- reglas finas (código inmutable, periodo cerrado, asiento contabilizado,
-- etc.) ya las aplican los triggers de validación de 1b-1/1b-2/1b-3 — esto
-- solo decide quién puede intentarlo. Nadie borra un periodo, ni el
-- contador: una vez creado, se cierra o se bloquea, nunca desaparece.

alter table public.cuentas enable row level security;
alter table public.periodos enable row level security;
alter table public.asientos enable row level security;
alter table public.asiento_lineas enable row level security;

create policy cuentas_select on public.cuentas
  for select
  using (empresa_id = private.empresa_id() and private.tiene_rol('dueno', 'contador', 'admin'));

create policy cuentas_insert on public.cuentas
  for insert
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy cuentas_update on public.cuentas
  for update
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'))
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy cuentas_delete on public.cuentas
  for delete
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy periodos_select on public.periodos
  for select
  using (empresa_id = private.empresa_id() and private.tiene_rol('dueno', 'contador', 'admin'));

create policy periodos_insert on public.periodos
  for insert
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy periodos_update on public.periodos
  for update
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'))
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

-- Sin política de delete: ni el contador borra un periodo.

create policy asientos_select on public.asientos
  for select
  using (empresa_id = private.empresa_id() and private.tiene_rol('dueno', 'contador', 'admin'));

create policy asientos_insert on public.asientos
  for insert
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy asientos_update on public.asientos
  for update
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'))
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy asientos_delete on public.asientos
  for delete
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy asiento_lineas_select on public.asiento_lineas
  for select
  using (empresa_id = private.empresa_id() and private.tiene_rol('dueno', 'contador', 'admin'));

create policy asiento_lineas_insert on public.asiento_lineas
  for insert
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy asiento_lineas_update on public.asiento_lineas
  for update
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'))
  with check (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

create policy asiento_lineas_delete on public.asiento_lineas
  for delete
  using (empresa_id = private.empresa_id() and private.tiene_rol('contador'));

-- Grants: sin esto, aunque la política lo permita, el rol no tiene ni
-- el permiso base de la tabla. periodos no recibe delete: no hay política
-- que lo use, y así queda claro en el propio grant que no es un olvido.
grant select, insert, update on public.periodos to authenticated;
grant select, insert, update, delete on public.cuentas to authenticated;
grant select, insert, update, delete on public.asientos to authenticated;
grant select, insert, update, delete on public.asiento_lineas to authenticated;
