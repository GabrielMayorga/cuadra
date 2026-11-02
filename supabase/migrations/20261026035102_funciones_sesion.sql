-- Funciones de sesión (esquema private) y protección de perfiles.
--
-- Por qué SECURITY DEFINER: las políticas necesitan saber la empresa y el rol del usuario,
-- y eso vive en public.perfiles. Si la política de perfiles consultara perfiles con los
-- permisos del usuario, Postgres re-evaluaría la política y entraría en recursión.
-- La función corre con los permisos de su dueño (que no pasa por RLS), así que no hay bucle.
-- Siempre: search_path vacío (nadie puede suplantar objetos) y objetos con nombre completo.
-- Si el perfil está inactivo, o la empresa está inactiva, todas fallan cerrado (null/false).

create function private.empresa_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.empresa_id
  from public.perfiles p
  join public.empresas e on e.id = p.empresa_id and e.activa
  where p.id = (select auth.uid()) and p.activo
$$;

create function private.rol()
returns public.rol_usuario
language sql
stable
security definer
set search_path = ''
as $$
  select p.rol
  from public.perfiles p
  join public.empresas e on e.id = p.empresa_id and e.activa
  where p.id = (select auth.uid()) and p.activo
$$;

create function private.es_global()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfiles p
    join public.empresas e on e.id = p.empresa_id and e.activa
    where p.id = (select auth.uid()) and p.activo
      and p.rol in ('dueno', 'contador', 'admin')
  )
$$;

create function private.tiene_rol(variadic roles public.rol_usuario[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfiles p
    join public.empresas e on e.id = p.empresa_id and e.activa
    where p.id = (select auth.uid()) and p.activo
      and p.rol = any (roles)
  )
$$;

create function private.sucursales_asignadas()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(ps.sucursal_id), '{}'::uuid[])
  from public.perfil_sucursales ps
  join public.perfiles p on p.id = ps.perfil_id
  join public.empresas e on e.id = p.empresa_id and e.activa
  where ps.perfil_id = (select auth.uid()) and p.activo
$$;

create function private.modulo_activo(p_modulo text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.empresa_modulos m
    where m.empresa_id = (select private.empresa_id())
      and m.modulo = p_modulo
      and m.contratado
      and m.activo
  )
$$;

-- Solo usuarios autenticados pueden ejecutarlas (anon ni siquiera ve el esquema).
revoke all on function
  private.empresa_id(),
  private.rol(),
  private.es_global(),
  private.tiene_rol(public.rol_usuario[]),
  private.sucursales_asignadas(),
  private.modulo_activo(text)
from public;

grant usage on schema private to authenticated;
grant execute on function
  private.empresa_id(),
  private.rol(),
  private.es_global(),
  private.tiene_rol(public.rol_usuario[]),
  private.sucursales_asignadas(),
  private.modulo_activo(text)
to authenticated;

-- ---------- protección de perfiles ----------
-- RLS no distingue columnas ni relaciones entre filas; este trigger cubre lo que falta.
-- auth.uid() nulo = service_role o SQL directo: contexto de confianza (el servidor ya
-- validó quién es el actor), salvo empresa_id, que no cambia nunca.

create function private.proteger_perfiles()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_rol_actor public.rol_usuario;
begin
  if new.empresa_id is distinct from old.empresa_id then
    raise exception 'La empresa de un perfil no se puede cambiar'
      using errcode = '42501';
  end if;

  if v_actor is null then
    return new;
  end if;

  if v_actor = old.id then
    if new.rol is distinct from old.rol then
      raise exception 'No puedes cambiar tu propio rol' using errcode = '42501';
    end if;
    if old.activo and not new.activo then
      raise exception 'No puedes desactivarte a ti mismo' using errcode = '42501';
    end if;
  end if;

  v_rol_actor := private.rol();
  if v_rol_actor is null then
    raise exception 'Usuario sin perfil activo' using errcode = '42501';
  end if;

  if v_rol_actor = 'admin' and (old.rol = 'dueno' or new.rol = 'dueno') then
    raise exception 'Un admin no puede modificar a un dueño ni crear dueños'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger perfiles_proteger before update on public.perfiles
  for each row execute function private.proteger_perfiles();

-- ---------- permisos por columna ----------
-- Las políticas (siguiente migración) deciden QUÉ FILAS; esto decide QUÉ COLUMNAS.
revoke all on table public.perfiles, public.perfil_sucursales from authenticated;
grant select on public.perfiles, public.perfil_sucursales to authenticated;
grant update (nombre, rol, activo) on public.perfiles to authenticated;
grant insert (empresa_id, perfil_id, sucursal_id) on public.perfil_sucursales to authenticated;
grant delete on public.perfil_sucursales to authenticated;
