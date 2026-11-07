-- enviar_conteo: rechaza el envío si la empresa no tiene ninguna denominación activa
-- (sin esto, un conteo vacío pasaba la verificación de "falta alguna denominación").
-- create or replace conserva los grants de la migración anterior.

create or replace function public.enviar_conteo(p_arqueo uuid)
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

  if not exists (
    select 1 from public.empresa_denominaciones ed
    where ed.empresa_id = v_arqueo.empresa_id and ed.activa
  ) then
    raise exception 'La empresa no tiene denominaciones activas; pide al dueño que active las que usa antes de enviar el conteo'
      using errcode = '23514';
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
