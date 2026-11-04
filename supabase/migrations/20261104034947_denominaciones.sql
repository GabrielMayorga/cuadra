-- Denominaciones de efectivo para el arqueo de caja.
-- El catálogo es global y se inserta aquí (no en seed.sql): son datos de referencia que
-- también necesita producción. Cada empresa recibe sus denominaciones activas al crearse.
-- Debe coincidir con DENOMINACIONES_POR_DEFECTO en src/domain/arqueo/conteo.ts.

-- ---------- catálogo global ----------
create table public.denominaciones (
  id smallint generated always as identity primary key,
  moneda public.moneda not null,
  valor numeric(14, 2) not null check (valor > 0),
  tipo text not null check (tipo in ('billete', 'moneda')),
  orden smallint not null unique,
  unique (moneda, tipo, valor)
);

insert into public.denominaciones (moneda, valor, tipo, orden) values
  ('NIO', 1000.00, 'billete', 1),
  ('NIO', 500.00, 'billete', 2),
  ('NIO', 200.00, 'billete', 3),
  ('NIO', 100.00, 'billete', 4),
  ('NIO', 50.00, 'billete', 5),
  ('NIO', 20.00, 'billete', 6),
  ('NIO', 10.00, 'billete', 7),
  ('NIO', 5.00, 'moneda', 8),
  ('NIO', 1.00, 'moneda', 9),
  ('NIO', 0.50, 'moneda', 10),
  ('NIO', 0.25, 'moneda', 11),
  ('NIO', 0.10, 'moneda', 12),
  ('USD', 100.00, 'billete', 13),
  ('USD', 50.00, 'billete', 14),
  ('USD', 20.00, 'billete', 15),
  ('USD', 10.00, 'billete', 16),
  ('USD', 5.00, 'billete', 17),
  ('USD', 1.00, 'billete', 18);

-- ---------- denominaciones por empresa ----------
create table public.empresa_denominaciones (
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  denominacion_id smallint not null references public.denominaciones (id) on delete restrict,
  activa boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (empresa_id, denominacion_id)
);

-- Toda empresa nueva recibe una fila por denominación, activa (mismo mecanismo que empresa_modulos).
create function private.crear_denominaciones_de_empresa()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.empresa_denominaciones (empresa_id, denominacion_id)
  select new.id, d.id from public.denominaciones d;
  return new;
end;
$$;

create trigger empresas_crear_denominaciones after insert on public.empresas
  for each row execute function private.crear_denominaciones_de_empresa();

create trigger empresa_denominaciones_updated_at before update on public.empresa_denominaciones
  for each row execute function private.set_updated_at();

-- Empresas que ya existen.
insert into public.empresa_denominaciones (empresa_id, denominacion_id)
select e.id, d.id from public.empresas e cross join public.denominaciones d;

-- ---------- seguridad ----------
alter table public.denominaciones enable row level security;
alter table public.empresa_denominaciones enable row level security;

revoke all on table public.denominaciones, public.empresa_denominaciones from anon, authenticated;

grant select on public.denominaciones, public.empresa_denominaciones to authenticated;

-- Solo "activa" es editable. Nadie inserta ni borra desde la API (sin GRANT de insert/delete).
grant update (activa) on public.empresa_denominaciones to authenticated;

-- El catálogo lo lee cualquier usuario autenticado.
create policy denominaciones_select on public.denominaciones for select to authenticated
  using (true);

-- Cualquier rol de la empresa lee las suyas: el cajero necesita saber qué denominaciones contar.
create policy empresa_denominaciones_select on public.empresa_denominaciones for select to authenticated
  using (empresa_id = (select private.empresa_id()));

-- La configuración es del dueño.
create policy empresa_denominaciones_update on public.empresa_denominaciones for update to authenticated
  using (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')))
  with check (empresa_id = (select private.empresa_id()) and (select private.tiene_rol('dueno')));
