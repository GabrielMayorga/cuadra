-- Núcleo contable 2/5: periodos contables.
-- Ciclo: abierto -> cerrado (cierre mensual, reversible) -> bloqueado (cierre anual, definitivo).
-- Se cierra en orden y se reabre en orden inverso.

create type public.estado_periodo as enum ('abierto', 'cerrado', 'bloqueado');

create table public.periodos (
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  anio smallint not null check (anio between 2000 and 2100),
  mes smallint not null check (mes between 1 and 12),
  estado public.estado_periodo not null default 'abierto',
  cerrado_por uuid references auth.users (id) on delete set null,
  cerrado_en timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (empresa_id, anio, mes),
  check ((estado = 'abierto') = (cerrado_en is null))
);

create function private.validar_periodo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.estado <> 'abierto' then
      raise exception 'Un periodo nuevo empieza abierto' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.empresa_id is distinct from old.empresa_id
     or new.anio <> old.anio or new.mes <> old.mes then
    raise exception 'Empresa, año y mes de un periodo no se cambian' using errcode = '42501';
  end if;

  if new.estado = old.estado then
    return new;
  end if;

  if old.estado = 'bloqueado' then
    raise exception 'El periodo %-% está bloqueado por cierre anual', old.anio, old.mes
      using errcode = '42501';
  end if;

  if new.estado = 'bloqueado' and old.estado <> 'cerrado' then
    raise exception 'Solo se bloquea un periodo ya cerrado' using errcode = '23514';
  end if;

  if new.estado = 'cerrado' and exists (
    select 1 from public.periodos p
    where p.empresa_id = new.empresa_id
      and (p.anio, p.mes) < (new.anio, new.mes)
      and p.estado = 'abierto'
  ) then
    raise exception 'Cierra primero los meses anteriores' using errcode = '23514';
  end if;

  if new.estado = 'abierto' and exists (
    select 1 from public.periodos p
    where p.empresa_id = new.empresa_id
      and (p.anio, p.mes) > (new.anio, new.mes)
      and p.estado <> 'abierto'
  ) then
    raise exception 'No se reabre un mes si hay meses posteriores cerrados' using errcode = '23514';
  end if;

  if new.estado = 'abierto' then
    new.cerrado_por := null;
    new.cerrado_en := null;
  elsif old.estado = 'abierto' then
    new.cerrado_por := auth.uid();
    new.cerrado_en := now();
  end if;

  return new;
end;
$$;

create trigger periodos_validar before insert or update on public.periodos
  for each row execute function private.validar_periodo();
create trigger periodos_updated_at before update on public.periodos
  for each row execute function private.set_updated_at();

create function private.periodo_abierto(p_empresa uuid, p_fecha date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with objetivo as (
    select extract(year from p_fecha)::smallint as anio,
           extract(month from p_fecha)::smallint as mes
  )
  select coalesce(
    (select p.estado = 'abierto'
       from public.periodos p, objetivo o
      where p.empresa_id = p_empresa and p.anio = o.anio and p.mes = o.mes),
    not exists (
      select 1 from public.periodos p, objetivo o
       where p.empresa_id = p_empresa
         and (p.anio, p.mes) > (o.anio, o.mes)
         and p.estado <> 'abierto')
  )
$$;

revoke all on function private.periodo_abierto(uuid, date) from public;
grant execute on function private.periodo_abierto(uuid, date) to authenticated;

alter table public.periodos enable row level security;
revoke all on table public.periodos from anon, authenticated;
grant select on public.periodos to authenticated;
grant insert (empresa_id, anio, mes) on public.periodos to authenticated;
grant update (estado) on public.periodos to authenticated;
