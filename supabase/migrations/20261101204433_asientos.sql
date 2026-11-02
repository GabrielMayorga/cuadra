-- Núcleo contable 3/5: asientos en partida doble.
-- Flujo: borrador (se cargan líneas) -> contabilizado (congelado, numerado).
-- Un asiento contabilizado nunca se edita ni se borra: se revierte con otro asiento.
-- Cada línea guarda el monto original, su moneda y tipo de cambio, y el debe o haber en C$.

create type public.estado_asiento as enum ('borrador', 'contabilizado');
create type public.origen_asiento as enum (
  'manual', 'arqueo', 'deposito', 'gasto', 'factura_proveedor', 'pago_proveedor',
  'venta_credito', 'abono', 'planilla', 'revaluacion', 'cierre', 'reversion'
);

-- ---------- cabecera ----------
create table public.asientos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  fecha date not null,
  descripcion text not null check (btrim(descripcion) <> ''),
  origen public.origen_asiento not null default 'manual',
  origen_id uuid,
  revierte_a uuid,
  estado public.estado_asiento not null default 'borrador',
  ejercicio smallint,
  numero integer,
  contabilizado_por uuid references auth.users (id) on delete set null,
  contabilizado_en timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  unique (id, empresa_id),
  unique (empresa_id, ejercicio, numero),
  unique (revierte_a),
  foreign key (revierte_a, empresa_id)
    references public.asientos (id, empresa_id) on delete restrict,
  check ((estado = 'borrador') = (numero is null)),
  check ((estado = 'borrador') = (ejercicio is null)),
  check ((estado = 'borrador') = (contabilizado_en is null))
);
create index asientos_fecha_idx on public.asientos (empresa_id, fecha);

-- ---------- líneas ----------
create table public.asiento_lineas (
  id uuid primary key default gen_random_uuid(),
  asiento_id uuid not null,
  empresa_id uuid not null,
  cuenta_id uuid not null,
  negocio_id uuid,
  sucursal_id uuid,
  moneda public.moneda not null default 'NIO',
  monto_original numeric(14, 2) not null check (monto_original > 0),
  tipo_cambio numeric(10, 4) not null default 1 check (tipo_cambio > 0),
  debe numeric(14, 2) not null default 0 check (debe >= 0),
  haber numeric(14, 2) not null default 0 check (haber >= 0),
  descripcion text,
  created_at timestamptz not null default now(),
  -- Exactamente un lado con valor.
  check ((debe = 0) <> (haber = 0)),
  -- C$ siempre a tipo 1; US$ con su tipo de cambio.
  check ((moneda = 'NIO') = (tipo_cambio = 1)),
  -- El valor en C$ es el monto original por el tipo de cambio, redondeado como Excel.
  check (debe + haber = round(monto_original * tipo_cambio, 2)),
  foreign key (asiento_id, empresa_id)
    references public.asientos (id, empresa_id) on delete cascade,
  foreign key (cuenta_id, empresa_id)
    references public.cuentas (id, empresa_id) on delete restrict,
  foreign key (negocio_id, empresa_id)
    references public.negocios (id, empresa_id) on delete restrict,
  foreign key (sucursal_id, empresa_id)
    references public.sucursales (id, empresa_id) on delete restrict
);
create index asiento_lineas_asiento_idx on public.asiento_lineas (asiento_id);
create index asiento_lineas_cuenta_idx on public.asiento_lineas (empresa_id, cuenta_id);

-- ---------- correlativo sin huecos ----------
-- Una fila por empresa y ejercicio. El UPDATE bloquea la fila hasta el commit:
-- dos contabilizaciones simultáneas esperan su turno, y si una transacción falla
-- su incremento se deshace con ella. Una secuencia de Postgres dejaría huecos.
create table public.asiento_contadores (
  empresa_id uuid not null references public.empresas (id) on delete restrict,
  ejercicio smallint not null,
  ultimo integer not null check (ultimo > 0),
  primary key (empresa_id, ejercicio)
);

-- ---------- reglas de la cabecera ----------
create function private.validar_asiento()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lineas integer;
  v_debe numeric;
  v_haber numeric;
  v_ejercicio smallint;
  v_numero integer;
  v_estado_original public.estado_asiento;
  v_origen_original public.origen_asiento;
begin
  if tg_op = 'DELETE' then
    if old.estado <> 'borrador' then
      raise exception 'Un asiento contabilizado no se borra; se revierte' using errcode = '42501';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.estado <> 'borrador' then
      raise exception 'Un asiento nace en borrador; se contabiliza después de cargar sus líneas'
        using errcode = '23514';
    end if;
    new.ejercicio := null;
    new.numero := null;
    new.contabilizado_por := null;
    new.contabilizado_en := null;

    if new.revierte_a is not null then
      select a.estado, a.origen into v_estado_original, v_origen_original
      from public.asientos a
      where a.id = new.revierte_a and a.empresa_id = new.empresa_id;
      if not found or v_estado_original <> 'contabilizado' or v_origen_original = 'reversion' then
        raise exception 'Solo se revierte un asiento contabilizado que no sea a su vez una reversión'
          using errcode = '23514';
      end if;
    end if;
    return new;
  end if;

  -- UPDATE
  if old.estado = 'contabilizado' then
    raise exception 'Un asiento contabilizado no se modifica; se revierte' using errcode = '42501';
  end if;

  if new.empresa_id is distinct from old.empresa_id
     or new.origen is distinct from old.origen
     or new.origen_id is distinct from old.origen_id
     or new.revierte_a is distinct from old.revierte_a then
    raise exception 'Empresa, origen y reversión de un asiento no se cambian' using errcode = '42501';
  end if;

  if new.estado = 'borrador' then
    new.ejercicio := null;
    new.numero := null;
    new.contabilizado_por := null;
    new.contabilizado_en := null;
    return new;
  end if;

  -- Contabilizar: borrador -> contabilizado.
  if not private.periodo_abierto(new.empresa_id, new.fecha) then
    raise exception 'El periodo de % está cerrado', new.fecha using errcode = '23514';
  end if;

  select count(*), coalesce(sum(l.debe), 0), coalesce(sum(l.haber), 0)
    into v_lineas, v_debe, v_haber
  from public.asiento_lineas l
  where l.asiento_id = new.id;

  if v_lineas < 2 then
    raise exception 'Un asiento necesita al menos dos líneas' using errcode = '23514';
  end if;
  if v_debe <> v_haber then
    raise exception 'El asiento no cuadra: debe C$ % y haber C$ %', v_debe, v_haber
      using errcode = '23514';
  end if;

  v_ejercicio := extract(year from new.fecha)::smallint;
  insert into public.asiento_contadores as c (empresa_id, ejercicio, ultimo)
  values (new.empresa_id, v_ejercicio, 1)
  on conflict (empresa_id, ejercicio) do update set ultimo = c.ultimo + 1
  returning c.ultimo into v_numero;

  new.ejercicio := v_ejercicio;
  new.numero := v_numero;
  new.contabilizado_por := auth.uid();
  new.contabilizado_en := now();
  return new;
end;
$$;

-- ---------- reglas de las líneas ----------
create function private.validar_linea()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado public.estado_asiento;
  v_origen public.origen_asiento;
  v_acepta boolean;
  v_activa boolean;
  v_moneda_cuenta public.moneda;
  v_negocio uuid;
  v_asiento_id uuid;
begin
  v_asiento_id := case when tg_op = 'DELETE' then old.asiento_id else new.asiento_id end;

  -- FOR SHARE: si otra transacción está contabilizando este asiento, esperamos a que
  -- termine y entonces vemos el estado final. Sin esto, una línea podría colarse
  -- justo después de verificar el cuadre.
  select a.estado, a.origen into v_estado, v_origen
  from public.asientos a
  where a.id = v_asiento_id
  for share;

  if found and v_estado <> 'borrador' then
    raise exception 'Un asiento contabilizado no se modifica; se revierte' using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  if tg_op = 'UPDATE'
     and (new.asiento_id <> old.asiento_id or new.empresa_id <> old.empresa_id) then
    raise exception 'Una línea no se mueve a otro asiento' using errcode = '42501';
  end if;

  select c.acepta_movimientos, c.activa, c.moneda
    into v_acepta, v_activa, v_moneda_cuenta
  from public.cuentas c
  where c.id = new.cuenta_id and c.empresa_id = new.empresa_id;

  if found then
    if not v_acepta then
      raise exception 'La cuenta es agrupadora; usa una de sus subcuentas' using errcode = '23514';
    end if;
    if not v_activa and v_origen is distinct from 'reversion' then
      raise exception 'La cuenta está inactiva' using errcode = '23514';
    end if;
    if v_moneda_cuenta = 'USD' and new.moneda <> 'USD' then
      raise exception 'La cuenta es en US$: la línea debe registrar el monto en dólares'
        using errcode = '23514';
    end if;
  end if;

  -- El negocio sale de la sucursal: no pueden contradecirse.
  if new.sucursal_id is not null then
    select s.negocio_id into v_negocio
    from public.sucursales s
    where s.id = new.sucursal_id and s.empresa_id = new.empresa_id;
    if found then
      if new.negocio_id is null then
        new.negocio_id := v_negocio;
      elsif new.negocio_id <> v_negocio then
        raise exception 'La sucursal no pertenece a ese negocio' using errcode = '23514';
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------- cuentas con movimientos (completa la regla de la 1b-1) ----------
create function private.cuenta_con_movimientos()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.acepta_movimientos and not new.acepta_movimientos
     and exists (select 1 from public.asiento_lineas l where l.cuenta_id = new.id) then
    raise exception 'La cuenta ya tiene movimientos; no puede volverse agrupadora'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger asientos_updated_at before update on public.asientos
  for each row execute function private.set_updated_at();
create trigger asientos_validar before insert or update or delete on public.asientos
  for each row execute function private.validar_asiento();
create trigger asiento_lineas_validar before insert or update or delete on public.asiento_lineas
  for each row execute function private.validar_linea();
create trigger cuentas_con_movimientos before update on public.cuentas
  for each row execute function private.cuenta_con_movimientos();

-- ---------- reversión ----------
-- Crea el asiento espejo (debe y haber intercambiados) y lo contabiliza, todo o nada.
-- SECURITY DEFINER porque escribe revierte_a y origen, que el cliente no puede escribir;
-- por eso valida el rol a mano. auth.uid() nulo = servidor (contexto de confianza).
create function public.revertir_asiento(p_asiento uuid, p_fecha date, p_motivo text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_original public.asientos%rowtype;
  v_nuevo uuid;
begin
  select * into v_original from public.asientos where id = p_asiento for update;
  if not found then
    raise exception 'Asiento no encontrado' using errcode = 'P0002';
  end if;

  if auth.uid() is not null and not (
    v_original.empresa_id = private.empresa_id()
    and private.tiene_rol('dueno', 'contador')
  ) then
    raise exception 'Solo el dueño o la contadora revierten asientos' using errcode = '42501';
  end if;

  if coalesce(btrim(p_motivo), '') = '' then
    raise exception 'Indica el motivo de la reversión' using errcode = '23514';
  end if;
  if v_original.estado <> 'contabilizado' then
    raise exception 'Solo se revierte un asiento contabilizado' using errcode = '23514';
  end if;
  if v_original.origen = 'reversion' then
    raise exception 'Una reversión no se revierte; registra un asiento nuevo' using errcode = '23514';
  end if;
  if p_fecha < v_original.fecha then
    raise exception 'La reversión no puede tener fecha anterior al asiento original'
      using errcode = '23514';
  end if;
  if exists (select 1 from public.asientos a where a.revierte_a = p_asiento) then
    raise exception 'El asiento %-% ya fue revertido', v_original.ejercicio, v_original.numero
      using errcode = '23505';
  end if;

  insert into public.asientos (empresa_id, fecha, descripcion, origen, origen_id, revierte_a)
  values (
    v_original.empresa_id,
    p_fecha,
    format('Reversión del asiento %s-%s: %s', v_original.ejercicio, v_original.numero, p_motivo),
    'reversion',
    v_original.origen_id,
    p_asiento
  )
  returning id into v_nuevo;

  insert into public.asiento_lineas (
    asiento_id, empresa_id, cuenta_id, negocio_id, sucursal_id,
    moneda, monto_original, tipo_cambio, debe, haber, descripcion
  )
  select v_nuevo, l.empresa_id, l.cuenta_id, l.negocio_id, l.sucursal_id,
         l.moneda, l.monto_original, l.tipo_cambio, l.haber, l.debe, l.descripcion
  from public.asiento_lineas l
  where l.asiento_id = p_asiento;

  update public.asientos set estado = 'contabilizado' where id = v_nuevo;
  return v_nuevo;
end;
$$;

revoke all on function public.revertir_asiento(uuid, date, text) from public, anon;
grant execute on function public.revertir_asiento(uuid, date, text) to authenticated;

-- ---------- seguridad ----------
-- RLS sin políticas hasta la 1b-5. El contador no tiene políticas nunca:
-- solo lo toca el trigger de contabilización.
alter table public.asientos enable row level security;
alter table public.asiento_lineas enable row level security;
alter table public.asiento_contadores enable row level security;

revoke all on table public.asientos, public.asiento_lineas, public.asiento_contadores
  from anon, authenticated;

grant select on public.asientos, public.asiento_lineas to authenticated;

-- origen, origen_id y revierte_a no están: los asientos manuales son "manual" siempre;
-- los de los módulos y las reversiones los crean funciones del servidor.
grant insert (empresa_id, fecha, descripcion) on public.asientos to authenticated;
grant update (fecha, descripcion, estado) on public.asientos to authenticated;
grant delete on public.asientos to authenticated;

grant insert (asiento_id, empresa_id, cuenta_id, negocio_id, sucursal_id,
              moneda, monto_original, tipo_cambio, debe, haber, descripcion)
  on public.asiento_lineas to authenticated;
grant update (cuenta_id, negocio_id, sucursal_id,
              moneda, monto_original, tipo_cambio, debe, haber, descripcion)
  on public.asiento_lineas to authenticated;
grant delete on public.asiento_lineas to authenticated;
