-- Organización: empresa → negocio → sucursal → caja.
-- Cada tabla repite empresa_id y las llaves foráneas son compuestas (x_id, empresa_id),
-- de modo que la BD rechaza una sucursal de la empresa A colgando de un negocio de la B.

create schema if not exists private;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------- empresas ----------
create table public.empresas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (btrim(nombre) <> ''),
  ruc text,
  logo_path text,
  zona_horaria text not null default 'America/Managua',
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null
);

-- ---------- negocios ----------
create table public.negocios (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  nombre text not null check (btrim(nombre) <> ''),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  unique (id, empresa_id)
);
create unique index negocios_nombre_uq on public.negocios (empresa_id, lower(nombre));

-- ---------- sucursales ----------
create table public.sucursales (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null,
  negocio_id uuid not null,
  codigo text not null check (codigo ~ '^[A-Z0-9]{2,10}$'),
  nombre text not null check (btrim(nombre) <> ''),
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  unique (id, empresa_id),
  unique (empresa_id, codigo),
  foreign key (negocio_id, empresa_id)
    references public.negocios (id, empresa_id) on delete restrict
);
create index sucursales_negocio_idx on public.sucursales (negocio_id, empresa_id);

-- ---------- cajas ----------
create table public.cajas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null,
  sucursal_id uuid not null,
  numero smallint not null check (numero > 0),
  nombre text not null check (btrim(nombre) <> ''),
  fondo_nio numeric(14, 2) not null default 0 check (fondo_nio >= 0),
  fondo_usd numeric(14, 2) not null default 0 check (fondo_usd >= 0),
  activa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  unique (id, empresa_id),
  unique (sucursal_id, numero),
  foreign key (sucursal_id, empresa_id)
    references public.sucursales (id, empresa_id) on delete restrict
);
create index cajas_empresa_idx on public.cajas (empresa_id);

-- ---------- updated_at ----------
create trigger empresas_updated_at before update on public.empresas
  for each row execute function private.set_updated_at();
create trigger negocios_updated_at before update on public.negocios
  for each row execute function private.set_updated_at();
create trigger sucursales_updated_at before update on public.sucursales
  for each row execute function private.set_updated_at();
create trigger cajas_updated_at before update on public.cajas
  for each row execute function private.set_updated_at();

-- ---------- seguridad ----------
-- RLS activo desde el primer día y sin políticas: nadie lee ni escribe por la API
-- hasta que se agreguen en la migración de políticas. Anon nunca toca estas tablas.
alter table public.empresas enable row level security;
alter table public.negocios enable row level security;
alter table public.sucursales enable row level security;
alter table public.cajas enable row level security;

revoke all on table public.empresas, public.negocios, public.sucursales, public.cajas from anon;
