-- Pieza 1b-4: bitácora de auditoría del núcleo contable.
-- Registra automáticamente cada INSERT/UPDATE/DELETE en cuentas, periodos,
-- asientos y asiento_lineas. Es de solo lectura para dueño y contador;
-- nadie, con ningún rol, puede editarla ni borrarla.

create table public.bitacora (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  tabla text not null check (tabla in ('cuentas', 'periodos', 'asientos', 'asiento_lineas')),
  registro_id text not null,
  operacion text not null check (operacion in ('insert', 'update', 'delete')),
  datos_antes jsonb,
  datos_despues jsonb,
  perfil_id uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  check ((operacion = 'insert') = (datos_antes is null)),
  check ((operacion = 'delete') = (datos_despues is null))
);

create index bitacora_empresa_id_idx on public.bitacora (empresa_id);
create index bitacora_tabla_registro_idx on public.bitacora (tabla, registro_id);

comment on table public.bitacora is
  'Auditoría inmutable del núcleo contable. Solo el trigger registrar_bitacora escribe aquí.';

-- security definer: corre con privilegios de quien creó la función (el rol
-- de las migraciones), no del usuario que disparó el trigger. Así puede
-- insertar en bitacora aunque esa tabla no le dé INSERT a authenticated.
-- search_path fijo para que nadie le cuele un esquema falso.
create function private.registrar_bitacora()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fila jsonb;
  v_registro_id text;
  v_empresa_id uuid;
begin
  v_fila := to_jsonb(case when tg_op = 'DELETE' then old else new end);
  v_empresa_id := (v_fila ->> 'empresa_id')::uuid;

  v_registro_id := case
    when tg_table_name = 'periodos'
      then (v_fila ->> 'anio') || '-' || lpad(v_fila ->> 'mes', 2, '0')
    else v_fila ->> 'id'
  end;

  insert into public.bitacora (empresa_id, tabla, registro_id, operacion, datos_antes, datos_despues, perfil_id)
  values (
    v_empresa_id,
    tg_table_name,
    v_registro_id,
    lower(tg_op),
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end,
    auth.uid()
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger cuentas_bitacora
  after insert or update or delete on public.cuentas
  for each row execute function private.registrar_bitacora();

create trigger periodos_bitacora
  after insert or update or delete on public.periodos
  for each row execute function private.registrar_bitacora();

create trigger asientos_bitacora
  after insert or update or delete on public.asientos
  for each row execute function private.registrar_bitacora();

create trigger asiento_lineas_bitacora
  after insert or update or delete on public.asiento_lineas
  for each row execute function private.registrar_bitacora();

alter table public.bitacora enable row level security;

create policy bitacora_select on public.bitacora
  for select
  using (
    empresa_id = private.empresa_id()
    and private.tiene_rol('dueno', 'contador')
  );

-- Solo SELECT. Sin insert/update/delete para authenticated: la bitácora
-- se escribe únicamente desde el trigger (security definer) y nunca se
-- corrige a mano, ni siquiera por el dueño.
grant select on public.bitacora to authenticated;
