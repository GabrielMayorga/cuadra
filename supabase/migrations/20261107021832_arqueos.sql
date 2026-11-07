-- Pieza 3-3: arqueos con conteo ciego.
-- Aquí solo se guardan cantidades por denominación: nada de venta del día ni diferencia
-- (eso vive en otra tabla, en otra pieza). Estados: abierto -> contado -> (reabrir) -> abierto.
-- El estado 'cuadrado' lo agrega una pieza futura.

-- ---------- fecha del negocio ----------
-- ÚNICO lugar que calcula "hoy" según la zona horaria de la empresa (nunca UTC).
create function private.fecha_negocio(p_empresa uuid)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (now() at time zone e.zona_horaria)::date
  from public.empresas e
  where e.id = p_empresa
$$;

revoke all on function private.fecha_negocio(uuid) from public;

-- ---------- arqueos ----------
create type public.estado_arqueo as enum ('abierto', 'contado');

create table public.arqueos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  caja_id uuid not null,
  sucursal_id uuid not null,
  fecha date not null,
  correlativo text not null,
  estado public.estado_arqueo not null default 'abierto',
  abierto_por uuid default auth.uid() references auth.users (id) on delete set null,
  abierto_en timestamptz not null default now(),
  contado_por uuid references auth.users (id) on delete set null,
  contado_en timestamptz,
  reabierto_motivo text,
  unique (id, empresa_id),
  unique (caja_id, fecha),
  foreign key (caja_id, empresa_id)
    references public.cajas (id, empresa_id) on delete restrict,
  foreign key (sucursal_id, empresa_id)
    references public.sucursales (id, empresa_id) on delete restrict,
  check ((estado = 'contado') = (contado_en is not null))
);
create index arqueos_empresa_fecha_idx on public.arqueos (empresa_id, fecha);
create index arqueos_sucursal_idx on public.arqueos (sucursal_id, empresa_id);

-- ---------- conteo por denominación ----------
create table public.arqueo_conteo (
  id uuid primary key default gen_random_uuid(),
  arqueo_id uuid not null,
  empresa_id uuid not null,
  denominacion_id smallint not null references public.denominaciones (id) on delete restrict,
  cantidad integer not null check (cantidad >= 0),
  unique (arqueo_id, denominacion_id),
  foreign key (arqueo_id, empresa_id)
    references public.arqueos (id, empresa_id) on delete restrict
);

-- ---------- reglas al abrir un arqueo ----------
-- BEFORE INSERT corre antes del WITH CHECK de RLS: la política ya puede usar sucursal_id.
-- sucursal_id y correlativo salen de la caja y la sucursal; el cliente nunca los manda.
create function private.preparar_arqueo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol public.rol_usuario := private.rol();
  v_hoy date;
  v_sucursal uuid;
  v_numero smallint;
  v_activa boolean;
  v_codigo text;
begin
  if v_rol is null then
    raise exception 'Usuario sin perfil activo' using errcode = '42501';
  end if;
  if v_rol = 'dueno' then
    raise exception 'El dueño solo consulta los arqueos; no los abre' using errcode = '42501';
  end if;

  select c.sucursal_id, c.numero, c.activa, s.codigo
    into v_sucursal, v_numero, v_activa, v_codigo
  from public.cajas c
  join public.sucursales s on s.id = c.sucursal_id and s.empresa_id = c.empresa_id
  where c.id = new.caja_id and c.empresa_id = new.empresa_id;

  if not found then
    raise exception 'Caja no encontrada' using errcode = 'P0002';
  end if;
  if not v_activa then
    raise exception 'La caja está inactiva; no se puede abrir un arqueo' using errcode = '23514';
  end if;

  v_hoy := private.fecha_negocio(new.empresa_id);
  new.fecha := coalesce(new.fecha, v_hoy);

  if v_rol in ('cajero', 'encargado') and new.fecha <> v_hoy then
    raise exception 'Solo puedes abrir el arqueo de hoy (%)', v_hoy using errcode = '23514';
  end if;
  if new.fecha > v_hoy then
    raise exception 'No se puede abrir un arqueo con fecha futura (hoy es %)', v_hoy
      using errcode = '23514';
  end if;

  new.sucursal_id := v_sucursal;
  new.correlativo := format('%s-C%s-%s', v_codigo, v_numero, to_char(new.fecha, 'YYYYMMDD'));
  new.estado := 'abierto';
  new.abierto_por := auth.uid();
  new.abierto_en := now();
  new.contado_por := null;
  new.contado_en := null;
  new.reabierto_motivo := null;
  return new;
end;
$$;

create trigger arqueos_preparar before insert on public.arqueos
  for each row execute function private.preparar_arqueo();

-- ---------- reglas del conteo ----------
create function private.validar_conteo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_arqueo public.arqueos%rowtype;
  v_arqueo_id uuid := case when tg_op = 'DELETE' then old.arqueo_id else new.arqueo_id end;
  v_rol public.rol_usuario := private.rol();
  v_activa boolean;
begin
  -- FOR SHARE: si enviar_conteo está cerrando este arqueo, esperamos y vemos el estado final.
  select * into v_arqueo from public.arqueos a where a.id = v_arqueo_id for share;

  if found then
    if v_arqueo.estado <> 'abierto' then
      raise exception 'El conteo ya fue enviado; pide a la contadora que lo reabra'
        using errcode = '42501';
    end if;
    if v_rol in ('cajero', 'encargado')
       and v_arqueo.fecha <> private.fecha_negocio(v_arqueo.empresa_id) then
      raise exception 'Solo se cuenta el arqueo de hoy' using errcode = '42501';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  if tg_op = 'UPDATE'
     and (new.arqueo_id <> old.arqueo_id
          or new.empresa_id <> old.empresa_id
          or new.denominacion_id <> old.denominacion_id) then
    raise exception 'Una línea de conteo no se mueve de arqueo ni de denominación'
      using errcode = '42501';
  end if;

  select ed.activa into v_activa
  from public.empresa_denominaciones ed
  where ed.empresa_id = new.empresa_id and ed.denominacion_id = new.denominacion_id;

  if not coalesce(v_activa, false) then
    raise exception 'Esa denominación no está activa para la empresa' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger arqueo_conteo_validar before insert or update or delete on public.arqueo_conteo
  for each row execute function private.validar_conteo();

-- ---------- transiciones ----------
-- SECURITY DEFINER porque escriben estado, contado_por y contado_en, que el cliente no puede
-- escribir (sin GRANT de update). Saltan RLS, así que validan rol, empresa y sucursal a mano.
create function public.enviar_conteo(p_arqueo uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_arqueo public.arqueos%rowtype;
  v_rol public.rol_usuario := private.rol();
  v_faltan text;
begin
  select * into v_arqueo from public.arqueos where id = p_arqueo for update;
  if not found or v_arqueo.empresa_id is distinct from private.empresa_id() then
    raise exception 'Arqueo no encontrado' using errcode = 'P0002';
  end if;

  if v_rol in ('cajero', 'encargado') then
    if not (v_arqueo.sucursal_id = any (private.sucursales_asignadas())) then
      raise exception 'Ese arqueo no es de tu sucursal' using errcode = '42501';
    end if;
    if v_arqueo.fecha <> private.fecha_negocio(v_arqueo.empresa_id) then
      raise exception 'Solo se envía el conteo del arqueo de hoy' using errcode = '42501';
    end if;
  elsif v_rol is distinct from 'contador' and v_rol is distinct from 'admin' then
    raise exception 'Tu rol no puede enviar el conteo' using errcode = '42501';
  end if;

  if v_arqueo.estado <> 'abierto' then
    raise exception 'El conteo ya fue enviado' using errcode = '23514';
  end if;

  select string_agg(format('%s %s (%s)', d.moneda, d.valor, d.tipo), ', ' order by d.orden)
    into v_faltan
  from public.empresa_denominaciones ed
  join public.denominaciones d on d.id = ed.denominacion_id
  where ed.empresa_id = v_arqueo.empresa_id
    and ed.activa
    and not exists (
      select 1 from public.arqueo_conteo c
      where c.arqueo_id = p_arqueo and c.denominacion_id = ed.denominacion_id
    );

  if v_faltan is not null then
    raise exception 'Faltan denominaciones por contar (usa 0 si no hay): %', v_faltan
      using errcode = '23514';
  end if;

  update public.arqueos
     set estado = 'contado', contado_por = auth.uid(), contado_en = now()
   where id = p_arqueo;
end;
$$;

create function public.reabrir_conteo(p_arqueo uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_arqueo public.arqueos%rowtype;
begin
  select * into v_arqueo from public.arqueos where id = p_arqueo for update;
  if not found or v_arqueo.empresa_id is distinct from private.empresa_id() then
    raise exception 'Arqueo no encontrado' using errcode = 'P0002';
  end if;

  if not private.tiene_rol('contador', 'admin') then
    raise exception 'Solo la contadora o el admin reabren un conteo' using errcode = '42501';
  end if;
  if coalesce(btrim(p_motivo), '') = '' then
    raise exception 'Indica el motivo para reabrir el conteo' using errcode = '23514';
  end if;
  if v_arqueo.estado <> 'contado' then
    raise exception 'Solo se reabre un conteo ya enviado' using errcode = '23514';
  end if;

  update public.arqueos
     set estado = 'abierto', contado_por = null, contado_en = null, reabierto_motivo = btrim(p_motivo)
   where id = p_arqueo;
end;
$$;

revoke all on function public.enviar_conteo(uuid), public.reabrir_conteo(uuid, text)
  from public, anon;
grant execute on function public.enviar_conteo(uuid), public.reabrir_conteo(uuid, text)
  to authenticated;

-- ---------- seguridad ----------
alter table public.arqueos enable row level security;
alter table public.arqueo_conteo enable row level security;

revoke all on table public.arqueos, public.arqueo_conteo from anon, authenticated;

grant select on public.arqueos, public.arqueo_conteo to authenticated;
-- Solo estas tres columnas: sucursal_id, correlativo y estado los pone el servidor.
-- Sin update ni delete: las transiciones van por enviar_conteo y reabrir_conteo.
grant insert (empresa_id, caja_id, fecha) on public.arqueos to authenticated;

grant insert (arqueo_id, empresa_id, denominacion_id, cantidad) on public.arqueo_conteo to authenticated;
grant update (cantidad) on public.arqueo_conteo to authenticated;
grant delete on public.arqueo_conteo to authenticated;

-- ---------- políticas: arqueos ----------
create policy arqueos_select on public.arqueos for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (
      (select private.es_global())
      or sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
    )
  );

create policy arqueos_insert on public.arqueos for insert to authenticated
  with check (
    empresa_id = (select private.empresa_id())
    and (
      (select private.tiene_rol('contador', 'admin'))
      or (
        (select private.tiene_rol('cajero', 'encargado'))
        and sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
      )
    )
  );

-- ---------- políticas: arqueo_conteo ----------
create policy arqueo_conteo_select on public.arqueo_conteo for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and exists (
      select 1 from public.arqueos a
      where a.id = arqueo_conteo.arqueo_id and a.empresa_id = arqueo_conteo.empresa_id
    )
  );

create policy arqueo_conteo_insert on public.arqueo_conteo for insert to authenticated
  with check (
    empresa_id = (select private.empresa_id())
    and exists (
      select 1 from public.arqueos a
      where a.id = arqueo_conteo.arqueo_id and a.empresa_id = arqueo_conteo.empresa_id
        and (
          (select private.tiene_rol('contador', 'admin'))
          or (
            (select private.tiene_rol('cajero', 'encargado'))
            and a.sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
          )
        )
    )
  );

create policy arqueo_conteo_update on public.arqueo_conteo for update to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and exists (
      select 1 from public.arqueos a
      where a.id = arqueo_conteo.arqueo_id and a.empresa_id = arqueo_conteo.empresa_id
        and (
          (select private.tiene_rol('contador', 'admin'))
          or (
            (select private.tiene_rol('cajero', 'encargado'))
            and a.sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
          )
        )
    )
  )
  with check (
    empresa_id = (select private.empresa_id())
    and exists (
      select 1 from public.arqueos a
      where a.id = arqueo_conteo.arqueo_id and a.empresa_id = arqueo_conteo.empresa_id
        and (
          (select private.tiene_rol('contador', 'admin'))
          or (
            (select private.tiene_rol('cajero', 'encargado'))
            and a.sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
          )
        )
    )
  );

create policy arqueo_conteo_delete on public.arqueo_conteo for delete to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and exists (
      select 1 from public.arqueos a
      where a.id = arqueo_conteo.arqueo_id and a.empresa_id = arqueo_conteo.empresa_id
        and (
          (select private.tiene_rol('contador', 'admin'))
          or (
            (select private.tiene_rol('cajero', 'encargado'))
            and a.sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
          )
        )
    )
  );

-- ---------- bitácora ----------
alter table public.bitacora drop constraint bitacora_tabla_check;
alter table public.bitacora add constraint bitacora_tabla_check
  check (tabla in ('cuentas', 'periodos', 'asientos', 'asiento_lineas', 'arqueos', 'arqueo_conteo'));

create trigger arqueos_bitacora
  after insert or update or delete on public.arqueos
  for each row execute function private.registrar_bitacora();

create trigger arqueo_conteo_bitacora
  after insert or update or delete on public.arqueo_conteo
  for each row execute function private.registrar_bitacora();
