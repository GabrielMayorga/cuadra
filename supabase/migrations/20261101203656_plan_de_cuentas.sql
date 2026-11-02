-- Núcleo contable 1/5: plan de cuentas.
-- Cuentas agrupadoras (no reciben movimientos) y de detalle (sí reciben), en árbol.
-- Código, tipo, cuenta padre y empresa son fijos: una cuenta con historia no cambia
-- de naturaleza; si hace falta otra, se crea y la vieja se desactiva.

create type public.moneda as enum ('NIO', 'USD');
create type public.tipo_cuenta as enum ('activo', 'pasivo', 'patrimonio', 'ingreso', 'costo', 'gasto');

create table public.cuentas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  codigo text not null check (codigo ~ '^[0-9]+([.-][0-9]+)*$'),
  nombre text not null check (btrim(nombre) <> ''),
  tipo public.tipo_cuenta not null,
  padre_id uuid,
  acepta_movimientos boolean not null default true,
  moneda public.moneda not null default 'NIO',
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  unique (id, empresa_id),
  unique (empresa_id, codigo),
  foreign key (padre_id, empresa_id)
    references public.cuentas (id, empresa_id) on delete restrict
);
create index cuentas_padre_idx on public.cuentas (padre_id, empresa_id);

create function private.validar_cuenta()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_tipo_padre public.tipo_cuenta;
  v_padre_acepta boolean;
begin
  if tg_op = 'UPDATE' then
    if new.empresa_id is distinct from old.empresa_id
       or new.codigo is distinct from old.codigo
       or new.tipo is distinct from old.tipo
       or new.padre_id is distinct from old.padre_id then
      raise exception 'Código, tipo, cuenta padre y empresa no se cambian; crea una cuenta nueva'
        using errcode = '42501';
    end if;
    if new.acepta_movimientos and not old.acepta_movimientos
       and exists (select 1 from public.cuentas c where c.padre_id = new.id) then
      raise exception 'Una cuenta con subcuentas no puede recibir movimientos'
        using errcode = '23514';
    end if;
  end if;

  if new.padre_id is not null then
    select c.tipo, c.acepta_movimientos into v_tipo_padre, v_padre_acepta
    from public.cuentas c
    where c.id = new.padre_id and c.empresa_id = new.empresa_id;

    if not found then
      return new;
    end if;
    if v_tipo_padre <> new.tipo then
      raise exception 'La subcuenta debe ser del mismo tipo que su cuenta padre (%)', v_tipo_padre
        using errcode = '23514';
    end if;
    if v_padre_acepta then
      raise exception 'La cuenta padre recibe movimientos; márcala como agrupadora antes de agregarle subcuentas'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

create trigger cuentas_validar before insert or update on public.cuentas
  for each row execute function private.validar_cuenta();
create trigger cuentas_updated_at before update on public.cuentas
  for each row execute function private.set_updated_at();

alter table public.cuentas enable row level security;
revoke all on table public.cuentas from anon, authenticated;
grant select on public.cuentas to authenticated;
grant insert (empresa_id, codigo, nombre, tipo, padre_id, acepta_movimientos, moneda)
  on public.cuentas to authenticated;
grant update (nombre, acepta_movimientos, activa) on public.cuentas to authenticated;
