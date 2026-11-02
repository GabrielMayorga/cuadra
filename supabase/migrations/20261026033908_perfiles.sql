-- Perfiles: un usuario de Auth pertenece a una sola empresa y tiene un rol.
-- Dueño, contador y admin ven toda la empresa (alcance global); encargado y cajero
-- solo las sucursales asignadas en perfil_sucursales.

create type public.rol_usuario as enum ('dueno', 'contador', 'admin', 'encargado', 'cajero');

create table public.perfiles (
  id uuid primary key references auth.users (id) on delete restrict,
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  nombre text not null check (btrim(nombre) <> ''),
  rol public.rol_usuario not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  unique (id, empresa_id)
);
create index perfiles_empresa_idx on public.perfiles (empresa_id);

create table public.perfil_sucursales (
  empresa_id uuid not null,
  perfil_id uuid not null,
  sucursal_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  primary key (perfil_id, sucursal_id),
  foreign key (perfil_id, empresa_id)
    references public.perfiles (id, empresa_id) on delete cascade,
  foreign key (sucursal_id, empresa_id)
    references public.sucursales (id, empresa_id) on delete restrict
);
create index perfil_sucursales_empresa_idx on public.perfil_sucursales (empresa_id);
create index perfil_sucursales_sucursal_idx on public.perfil_sucursales (sucursal_id, empresa_id);

create trigger perfiles_updated_at before update on public.perfiles
  for each row execute function private.set_updated_at();

alter table public.perfiles enable row level security;
alter table public.perfil_sucursales enable row level security;

revoke all on table public.perfiles, public.perfil_sucursales from anon;
