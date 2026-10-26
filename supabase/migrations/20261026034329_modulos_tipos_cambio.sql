-- Módulos por empresa y tipos de cambio.
-- Los permisos finos de esta migración son por COLUMNA: RLS filtra filas, no columnas.

-- ---------- catálogo de módulos ----------
create table public.modulos (
  codigo text primary key check (codigo ~ '^[a-z_]+$'),
  nombre text not null
);

insert into public.modulos (codigo, nombre) values
  ('arqueo', 'Arqueo de caja'),
  ('ingresos_gastos', 'Ingresos y gastos'),
  ('cxc', 'Cuentas por cobrar'),
  ('proveedores', 'Proveedores'),
  ('planilla', 'Planilla de pagos'),
  ('reportes', 'Reportes');

-- ---------- módulos por empresa ----------
create table public.empresa_modulos (
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  modulo text not null references public.modulos (codigo) on delete restrict,
  contratado boolean not null default false,
  activo boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (empresa_id, modulo),
  check (not activo or contratado)
);

-- Toda empresa nueva recibe una fila por módulo (sin contratar): el menú nunca queda vacío.
create function private.crear_modulos_de_empresa()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.empresa_modulos (empresa_id, modulo)
  select new.id, m.codigo from public.modulos m;
  return new;
end;
$$;

create trigger empresas_crear_modulos after insert on public.empresas
  for each row execute function private.crear_modulos_de_empresa();

-- ---------- tipos de cambio ----------
create table public.tipos_cambio (
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  fecha date not null,
  tc_oficial numeric(10, 4) not null check (tc_oficial > 0),
  tc_caja numeric(10, 4) not null check (tc_caja > 0),
  registrado_por uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (empresa_id, fecha)
);

create trigger empresa_modulos_updated_at before update on public.empresa_modulos
  for each row execute function private.set_updated_at();
create trigger tipos_cambio_updated_at before update on public.tipos_cambio
  for each row execute function private.set_updated_at();

-- ---------- seguridad ----------
alter table public.modulos enable row level security;
alter table public.empresa_modulos enable row level security;
alter table public.tipos_cambio enable row level security;

revoke all on table public.modulos, public.empresa_modulos, public.tipos_cambio
  from anon, authenticated;

grant select on public.modulos, public.empresa_modulos, public.tipos_cambio to authenticated;

-- El usuario solo puede cambiar "activo"; "contratado" lo cambia únicamente service_role.
grant update (activo) on public.empresa_modulos to authenticated;

-- registrado_por no está en la lista: siempre sale de auth.uid(), no se puede falsear.
-- empresa_id y fecha solo se fijan al insertar; luego solo cambian los valores.
grant insert (empresa_id, fecha, tc_oficial, tc_caja) on public.tipos_cambio to authenticated;
grant update (tc_oficial, tc_caja) on public.tipos_cambio to authenticated;
