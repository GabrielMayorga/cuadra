-- Políticas RLS. Todas "to authenticated", una por comando, sin FOR ALL.
-- Patrón: empresa_id = (select private.empresa_id()) en cada una. Si la función devuelve
-- null (sin sesión, perfil o empresa inactivos) la comparación es null y se niega el acceso.
-- Los (select ...) hacen que Postgres evalúe la función una vez por consulta, no por fila.
--
-- Alcance: "global" = dueño, contador y admin. "Local" = encargado y cajero (sus sucursales).

-- ===================== permisos por columna =====================
revoke all on table public.empresas, public.negocios, public.sucursales, public.cajas
  from authenticated;
grant select on public.empresas, public.negocios, public.sucursales, public.cajas
  to authenticated;

-- empresas: no se inserta por la API; "activa" solo lo cambia service_role.
grant update (nombre, ruc, logo_path, zona_horaria) on public.empresas to authenticated;

grant insert (empresa_id, nombre) on public.negocios to authenticated;
grant update (nombre, activo) on public.negocios to authenticated;

-- codigo y negocio_id quedan fijos después de crear la sucursal.
grant insert (empresa_id, negocio_id, codigo, nombre) on public.sucursales to authenticated;
grant update (nombre, activa) on public.sucursales to authenticated;

-- numero queda fijo después de crear la caja.
grant insert (empresa_id, sucursal_id, numero, nombre, fondo_nio, fondo_usd)
  on public.cajas to authenticated;
grant update (nombre, fondo_nio, fondo_usd, activa) on public.cajas to authenticated;

-- ===================== empresas =====================
create policy empresas_select on public.empresas for select to authenticated
  using (id = (select private.empresa_id()));

create policy empresas_update on public.empresas for update to authenticated
  using (id = (select private.empresa_id()) and (select private.tiene_rol('dueno')))
  with check (id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));

-- ===================== negocios =====================
create policy negocios_select on public.negocios for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (
      (select private.es_global())
      or exists (
        select 1 from public.sucursales s
        where s.negocio_id = negocios.id
          and s.id = any ((select private.sucursales_asignadas())::uuid[])
      )
    )
  );

create policy negocios_insert on public.negocios for insert to authenticated
  with check (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));

create policy negocios_update on public.negocios for update to authenticated
  using (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')))
  with check (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));

-- ===================== sucursales =====================
create policy sucursales_select on public.sucursales for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (
      (select private.es_global())
      or id = any ((select private.sucursales_asignadas())::uuid[])
    )
  );

create policy sucursales_insert on public.sucursales for insert to authenticated
  with check (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));

create policy sucursales_update on public.sucursales for update to authenticated
  using (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')))
  with check (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));

-- ===================== cajas =====================
create policy cajas_select on public.cajas for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (
      (select private.es_global())
      or sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
    )
  );

create policy cajas_insert on public.cajas for insert to authenticated
  with check (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  );

create policy cajas_update on public.cajas for update to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  )
  with check (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  );

-- ===================== perfil_sucursales =====================
-- El encargado ve las asignaciones de SUS sucursales: la política de perfiles lo necesita.
create policy perfil_sucursales_select on public.perfil_sucursales for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (
      perfil_id = (select auth.uid())
      or (select private.es_global())
      or (
        (select private.tiene_rol('encargado'))
        and sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
      )
    )
  );

create policy perfil_sucursales_insert on public.perfil_sucursales for insert to authenticated
  with check (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  );

create policy perfil_sucursales_delete on public.perfil_sucursales for delete to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  );

-- ===================== perfiles =====================
create policy perfiles_select on public.perfiles for select to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (
      id = (select auth.uid())
      or (select private.es_global())
      or (
        (select private.tiene_rol('encargado'))
        and exists (
          select 1 from public.perfil_sucursales ps
          where ps.perfil_id = perfiles.id
            and ps.sucursal_id = any ((select private.sucursales_asignadas())::uuid[])
        )
      )
    )
  );

-- El trigger proteger_perfiles impide que un admin toque a un dueño.
create policy perfiles_update on public.perfiles for update to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  )
  with check (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'admin'))
  );

-- ===================== modulos y empresa_modulos =====================
create policy modulos_select on public.modulos for select to authenticated
  using (true);

create policy empresa_modulos_select on public.empresa_modulos for select to authenticated
  using (empresa_id = (select private.empresa_id()));

-- La columna "activo" es la única editable; el check exige que el módulo esté contratado.
create policy empresa_modulos_update on public.empresa_modulos for update to authenticated
  using (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')))
  with check (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));

-- ===================== tipos_cambio =====================
create policy tipos_cambio_select on public.tipos_cambio for select to authenticated
  using (empresa_id = (select private.empresa_id()));

create policy tipos_cambio_insert on public.tipos_cambio for insert to authenticated
  with check (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'contador'))
  );

create policy tipos_cambio_update on public.tipos_cambio for update to authenticated
  using (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'contador'))
  )
  with check (
    empresa_id = (select private.empresa_id())
    and (select private.tiene_rol('dueno', 'contador'))
  );
