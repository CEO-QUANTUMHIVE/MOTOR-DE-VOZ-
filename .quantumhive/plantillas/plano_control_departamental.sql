-- Plano de control local de un departamento QuantumHive.
--
-- Se instala en la base propia del módulo. No reemplaza sus tablas de dominio
-- ni duplica QuantumCore: conserva el detalle interno que el CEO necesita y
-- publica hacia Dominus solamente eventos, métricas y resúmenes promovidos.

create extension if not exists pgcrypto;
create schema if not exists quantumdepartamento;

create table quantumdepartamento.sesiones (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  actor text not null,
  herramienta text not null,
  rama text,
  version_repositorio text,
  estado text not null default 'activa'
    check (estado in ('activa','cerrada','fallida','cancelada')),
  resumen text,
  evidencia jsonb not null default '[]'::jsonb check (jsonb_typeof(evidencia) = 'array'),
  iniciada_en timestamptz not null default now(),
  cerrada_en timestamptz,
  creado_en timestamptz not null default now()
);

create table quantumdepartamento.planes (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  clave_idempotencia text not null,
  objetivo text not null check (length(btrim(objetivo)) > 0),
  resultado_esperado text not null check (length(btrim(resultado_esperado)) > 0),
  version_contrato integer not null default 1 check (version_contrato > 0),
  estado text not null default 'borrador'
    check (estado in ('borrador','validado','en_ejecucion','bloqueado','completado','cancelado')),
  creado_por text not null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (departamento_codigo, id),
  unique (departamento_codigo, clave_idempotencia)
);

create table quantumdepartamento.trabajos_internos (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  plan_id uuid not null,
  codigo text not null,
  titulo text not null check (length(btrim(titulo)) > 0),
  objetivo text not null check (length(btrim(objetivo)) > 0),
  resultado_esperado text not null check (length(btrim(resultado_esperado)) > 0),
  tipo text not null check (tipo in ('liviano','pesado','pruebas','operacion')),
  prioridad integer not null default 50 check (prioridad between 0 and 100),
  alcances jsonb not null check (jsonb_typeof(alcances) = 'array' and jsonb_array_length(alcances) > 0),
  criterios_aceptacion jsonb not null
    check (jsonb_typeof(criterios_aceptacion) = 'array' and jsonb_array_length(criterios_aceptacion) > 0),
  instruccion_control jsonb not null default '{}'::jsonb check (jsonb_typeof(instruccion_control) = 'object'),
  rama text,
  espacio_trabajo text,
  presupuesto_usd numeric(14,6) check (presupuesto_usd is null or presupuesto_usd >= 0),
  estado text not null default 'pendiente'
    check (estado in ('pendiente','bloqueado','reservado','en_ejecucion','en_revision','completado','fallido','cancelado')),
  reservado_por text,
  huella_reserva text,
  reserva_vence_en timestamptz,
  intentos integer not null default 0 check (intentos >= 0),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (departamento_codigo, id),
  unique (plan_id, codigo),
  foreign key (departamento_codigo, plan_id)
    references quantumdepartamento.planes(departamento_codigo, id) on delete restrict
);

create table quantumdepartamento.dependencias_trabajo (
  departamento_codigo text not null,
  trabajo_id uuid not null,
  requisito_id uuid not null,
  creado_en timestamptz not null default now(),
  primary key (trabajo_id, requisito_id),
  check (trabajo_id <> requisito_id),
  foreign key (departamento_codigo, trabajo_id)
    references quantumdepartamento.trabajos_internos(departamento_codigo, id) on delete cascade,
  foreign key (departamento_codigo, requisito_id)
    references quantumdepartamento.trabajos_internos(departamento_codigo, id) on delete restrict
);

create table quantumdepartamento.entregas (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  trabajo_id uuid not null,
  resumen text not null check (length(btrim(resumen)) > 0),
  evidencias jsonb not null check (jsonb_typeof(evidencias) = 'array' and jsonb_array_length(evidencias) > 0),
  resultado jsonb not null default '{}'::jsonb check (jsonb_typeof(resultado) = 'object'),
  estado text not null default 'presentada'
    check (estado in ('presentada','validada','rechazada')),
  presentada_por text not null,
  validada_por text,
  creado_en timestamptz not null default now(),
  validado_en timestamptz,
  foreign key (departamento_codigo, trabajo_id)
    references quantumdepartamento.trabajos_internos(departamento_codigo, id) on delete restrict
);

create table quantumdepartamento.memorias (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  linaje_id uuid not null default gen_random_uuid(),
  version integer not null default 1 check (version > 0),
  corrige_a_id uuid references quantumdepartamento.memorias(id) on delete restrict,
  titulo text not null check (length(btrim(titulo)) > 0),
  contenido text not null check (length(btrim(contenido)) > 0),
  origen_tipo text not null,
  origen_id text not null,
  evidencia jsonb not null default '[]'::jsonb check (jsonb_typeof(evidencia) = 'array'),
  confianza text not null default 'no_validada'
    check (confianza in ('no_validada','validada','verificada')),
  sensibilidad text not null default 'restringida'
    check (sensibilidad in ('publica','interna','restringida','secreta')),
  estado text not null default 'vigente'
    check (estado in ('borrador','vigente','corregida','archivada')),
  creado_por text not null,
  creado_en timestamptz not null default now(),
  unique (linaje_id, version)
);

create table quantumdepartamento.decisiones (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  asunto text not null check (length(btrim(asunto)) > 0),
  decision text not null check (length(btrim(decision)) > 0),
  motivo text not null,
  impacto jsonb not null default '{}'::jsonb check (jsonb_typeof(impacto) = 'object'),
  requiere_dominus boolean not null default false,
  requiere_sergio boolean not null default false,
  decidida_por text not null,
  creado_en timestamptz not null default now()
);

create table quantumdepartamento.hechos_operativos (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null unique default gen_random_uuid(),
  departamento_codigo text not null,
  tipo text not null
    check (tipo in ('cliente','ingesta','proceso','trabajo','despliegue','incidente','costo','seguridad','decision')),
  entidad_tipo text,
  entidad_id text,
  estado text not null,
  carga jsonb not null default '{}'::jsonb check (jsonb_typeof(carga) = 'object'),
  correlacion_id uuid,
  causacion_id uuid,
  clave_idempotencia text not null,
  ocurrido_en timestamptz not null default now(),
  registrado_en timestamptz not null default now(),
  unique (departamento_codigo, evento_id),
  unique (departamento_codigo, clave_idempotencia)
);

create table quantumdepartamento.ejecuciones_proceso (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  proceso text not null,
  version_proceso text not null,
  correlacion_id uuid,
  estado text not null check (estado in ('pendiente','ejecutando','completada','fallida','cancelada')),
  entrada_referencia jsonb not null default '{}'::jsonb,
  salida_referencia jsonb not null default '{}'::jsonb,
  metricas jsonb not null default '{}'::jsonb,
  ultimo_error text,
  iniciada_en timestamptz,
  finalizada_en timestamptz,
  creado_en timestamptz not null default now()
);

create table quantumdepartamento.ingestas (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  fuente text not null,
  cursor_origen text,
  clave_idempotencia text not null,
  estado text not null check (estado in ('recibida','validada','procesada','rechazada','fallida')),
  registros_recibidos bigint not null default 0 check (registros_recibidos >= 0),
  registros_aceptados bigint not null default 0 check (registros_aceptados >= 0),
  registros_rechazados bigint not null default 0 check (registros_rechazados >= 0),
  evidencia jsonb not null default '[]'::jsonb,
  recibido_en timestamptz not null default now(),
  procesado_en timestamptz,
  unique (departamento_codigo, clave_idempotencia)
);

create table quantumdepartamento.informes (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  tipo text not null
    check (tipo in ('cliente','ingesta','proceso','trabajo','despliegue','incidente','costo','seguridad','decision')),
  clave_idempotencia text not null,
  estado text not null,
  resumen text not null check (length(btrim(resumen)) > 0),
  metricas jsonb not null default '{}'::jsonb check (jsonb_typeof(metricas) = 'object'),
  evidencia jsonb not null default '[]'::jsonb check (jsonb_typeof(evidencia) = 'array'),
  destino_escalado text not null default 'local'
    check (destino_escalado in ('local','dominus','sergio')),
  correlacion_id uuid,
  publicado_en timestamptz,
  creado_en timestamptz not null default now(),
  check (destino_escalado = 'local' or jsonb_array_length(evidencia) > 0),
  unique (departamento_codigo, clave_idempotencia)
);

create table quantumdepartamento.eventos_salida (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  evento_id uuid not null,
  destino text not null default 'dominus',
  estado text not null default 'pendiente'
    check (estado in ('pendiente','reservado','enviado','confirmado','fallido')),
  intentos integer not null default 0 check (intentos >= 0),
  proximo_intento_en timestamptz not null default now(),
  ultimo_error text,
  creado_en timestamptz not null default now(),
  confirmado_en timestamptz,
  unique (departamento_codigo, evento_id, destino),
  foreign key (departamento_codigo, evento_id)
    references quantumdepartamento.hechos_operativos(departamento_codigo, evento_id) on delete restrict
);

create table quantumdepartamento.eventos_entrada (
  id uuid primary key default gen_random_uuid(),
  departamento_codigo text not null,
  evento_id uuid not null,
  productor text not null,
  tipo text not null,
  version_esquema integer not null default 1,
  carga jsonb not null default '{}'::jsonb,
  clave_idempotencia text not null,
  estado text not null default 'recibido'
    check (estado in ('recibido','procesado','rechazado','fallido')),
  recibido_en timestamptz not null default now(),
  procesado_en timestamptz,
  unique (departamento_codigo, productor, evento_id),
  unique (departamento_codigo, clave_idempotencia)
);

create index trabajos_internos_cola_idx
  on quantumdepartamento.trabajos_internos (departamento_codigo, estado, prioridad desc, creado_en);
create index hechos_operativos_tiempo_idx
  on quantumdepartamento.hechos_operativos (departamento_codigo, tipo, ocurrido_en desc);
create index ejecuciones_proceso_estado_idx
  on quantumdepartamento.ejecuciones_proceso (departamento_codigo, proceso, estado, creado_en desc);
create index ingestas_estado_idx
  on quantumdepartamento.ingestas (departamento_codigo, fuente, estado, recibido_en desc);
create index informes_escalado_idx
  on quantumdepartamento.informes (departamento_codigo, destino_escalado, publicado_en, creado_en desc);
create index eventos_salida_cola_idx
  on quantumdepartamento.eventos_salida (estado, proximo_intento_en, creado_en);

create or replace function quantumdepartamento.registrar_hecho(
  p_departamento_codigo text,
  p_tipo text,
  p_estado text,
  p_clave_idempotencia text,
  p_carga jsonb default '{}'::jsonb,
  p_entidad_tipo text default null,
  p_entidad_id text default null,
  p_correlacion_id uuid default null,
  p_causacion_id uuid default null,
  p_destino text default 'local'
)
returns uuid
language plpgsql
security definer
set search_path = quantumdepartamento, pg_temp
as $$
declare
  v_evento_id uuid;
begin
  if p_destino not in ('local','dominus','sergio') then
    raise exception 'destino de hecho desconocido: %', p_destino;
  end if;

  insert into quantumdepartamento.hechos_operativos (
    departamento_codigo, tipo, entidad_tipo, entidad_id, estado, carga,
    correlacion_id, causacion_id, clave_idempotencia
  ) values (
    p_departamento_codigo, p_tipo, p_entidad_tipo, p_entidad_id, p_estado,
    coalesce(p_carga, '{}'::jsonb), p_correlacion_id, p_causacion_id,
    p_clave_idempotencia
  )
  on conflict (departamento_codigo, clave_idempotencia) do nothing
  returning evento_id into v_evento_id;

  if v_evento_id is null then
    select evento_id into v_evento_id
    from quantumdepartamento.hechos_operativos
    where departamento_codigo = p_departamento_codigo
      and clave_idempotencia = p_clave_idempotencia;
  end if;

  if p_destino <> 'local' then
    insert into quantumdepartamento.eventos_salida (
      departamento_codigo, evento_id, destino
    ) values (p_departamento_codigo, v_evento_id, p_destino)
    on conflict (departamento_codigo, evento_id, destino) do nothing;
  end if;

  return v_evento_id;
end;
$$;

create or replace function quantumdepartamento.reclamar_trabajo(
  p_departamento_codigo text,
  p_worker text,
  p_huella_reserva text,
  p_tipos text[] default null,
  p_duracion interval default interval '5 minutes'
)
returns uuid
language plpgsql
security definer
set search_path = quantumdepartamento, pg_temp
as $$
declare
  v_trabajo_id uuid;
begin
  if length(coalesce(p_huella_reserva, '')) < 32 then
    raise exception 'la huella de reserva es demasiado corta';
  end if;
  if length(btrim(coalesce(p_worker, ''))) = 0 then
    raise exception 'el worker es obligatorio';
  end if;
  if p_duracion <= interval '0 seconds' then
    raise exception 'la duración de reserva debe ser positiva';
  end if;

  with candidato as (
    select trabajo.id
    from quantumdepartamento.trabajos_internos trabajo
    where trabajo.departamento_codigo = p_departamento_codigo
      and trabajo.estado = 'pendiente'
      and (p_tipos is null or trabajo.tipo = any(p_tipos))
      and not exists (
        select 1
        from quantumdepartamento.dependencias_trabajo dependencia
        join quantumdepartamento.trabajos_internos requisito
          on requisito.id = dependencia.requisito_id
        where dependencia.trabajo_id = trabajo.id
          and requisito.estado <> 'completado'
      )
    order by trabajo.prioridad desc, trabajo.creado_en, trabajo.id
    for update of trabajo skip locked
    limit 1
  )
  update quantumdepartamento.trabajos_internos trabajo
  set estado = 'reservado',
      reservado_por = p_worker,
      huella_reserva = p_huella_reserva,
      reserva_vence_en = now() + p_duracion,
      intentos = trabajo.intentos + 1,
      actualizado_en = now()
  from candidato
  where trabajo.id = candidato.id
  returning trabajo.id into v_trabajo_id;

  return v_trabajo_id;
end;
$$;

create or replace function quantumdepartamento.renovar_reserva(
  p_trabajo_id uuid,
  p_huella_reserva text,
  p_duracion interval default interval '5 minutes'
)
returns boolean
language sql
security definer
set search_path = quantumdepartamento, pg_temp
as $$
  with renovada as (
    update quantumdepartamento.trabajos_internos
    set reserva_vence_en = now() + p_duracion,
        actualizado_en = now()
    where id = p_trabajo_id
      and huella_reserva = p_huella_reserva
      and estado in ('reservado','en_ejecucion')
      and reserva_vence_en > now()
      and p_duracion > interval '0 seconds'
    returning 1
  )
  select exists(select 1 from renovada);
$$;

create or replace function quantumdepartamento.recuperar_reservas_vencidas()
returns integer
language sql
security definer
set search_path = quantumdepartamento, pg_temp
as $$
  with recuperadas as (
    update quantumdepartamento.trabajos_internos
    set estado = 'pendiente', reservado_por = null, huella_reserva = null,
        reserva_vence_en = null, actualizado_en = now()
    where estado in ('reservado','en_ejecucion','en_revision')
      and reserva_vence_en <= now()
    returning 1
  )
  select count(*)::integer from recuperadas;
$$;

create or replace function quantumdepartamento.completar_trabajo(
  p_trabajo_id uuid,
  p_huella_reserva text,
  p_resumen text,
  p_evidencias jsonb,
  p_resultado jsonb default '{}'::jsonb,
  p_elevar_a text default 'local'
)
returns uuid
language plpgsql
security definer
set search_path = quantumdepartamento, pg_temp
as $$
declare
  v_trabajo quantumdepartamento.trabajos_internos%rowtype;
  v_entrega_id uuid;
begin
  if length(btrim(coalesce(p_resumen, ''))) = 0
     or jsonb_typeof(p_evidencias) <> 'array'
     or jsonb_array_length(p_evidencias) = 0 then
    raise exception 'la entrega requiere resumen y evidencia';
  end if;

  select * into v_trabajo
  from quantumdepartamento.trabajos_internos
  where id = p_trabajo_id
    and huella_reserva = p_huella_reserva
    and estado in ('reservado','en_ejecucion','en_revision')
    and reserva_vence_en > now()
  for update;

  if not found then
    return null;
  end if;

  insert into quantumdepartamento.entregas (
    departamento_codigo, trabajo_id, resumen, evidencias, resultado,
    presentada_por
  ) values (
    v_trabajo.departamento_codigo, v_trabajo.id, p_resumen, p_evidencias,
    coalesce(p_resultado, '{}'::jsonb), coalesce(v_trabajo.reservado_por, 'worker')
  ) returning id into v_entrega_id;

  update quantumdepartamento.trabajos_internos
  set estado = 'completado', reservado_por = null, huella_reserva = null,
      reserva_vence_en = null, actualizado_en = now()
  where id = v_trabajo.id;

  perform quantumdepartamento.registrar_hecho(
    v_trabajo.departamento_codigo,
    'trabajo',
    'completado',
    'trabajo:' || v_trabajo.id::text || ':completado',
    jsonb_build_object(
      'trabajo_id', v_trabajo.id,
      'entrega_id', v_entrega_id,
      'resumen', p_resumen,
      'evidencias', p_evidencias
    ),
    'trabajo',
    v_trabajo.id::text,
    null,
    null,
    p_elevar_a
  );

  return v_entrega_id;
end;
$$;

create or replace function quantumdepartamento.publicar_informe(
  p_departamento_codigo text,
  p_tipo text,
  p_estado text,
  p_resumen text,
  p_clave_idempotencia text,
  p_metricas jsonb default '{}'::jsonb,
  p_evidencia jsonb default '[]'::jsonb,
  p_destino_escalado text default 'local',
  p_correlacion_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = quantumdepartamento, pg_temp
as $$
declare
  v_informe_id uuid;
begin
  insert into quantumdepartamento.informes (
    departamento_codigo, tipo, clave_idempotencia, estado, resumen, metricas, evidencia,
    destino_escalado, correlacion_id, publicado_en
  ) values (
    p_departamento_codigo, p_tipo, p_clave_idempotencia, p_estado, p_resumen,
    coalesce(p_metricas, '{}'::jsonb), coalesce(p_evidencia, '[]'::jsonb),
    p_destino_escalado, p_correlacion_id,
    case when p_destino_escalado = 'local' then null else now() end
  )
  on conflict (departamento_codigo, clave_idempotencia) do nothing
  returning id into v_informe_id;

  if v_informe_id is null then
    select id into v_informe_id
    from quantumdepartamento.informes
    where departamento_codigo = p_departamento_codigo
      and clave_idempotencia = p_clave_idempotencia;
  end if;

  perform quantumdepartamento.registrar_hecho(
    p_departamento_codigo,
    p_tipo,
    p_estado,
    p_clave_idempotencia,
    jsonb_build_object(
      'informe_id', v_informe_id,
      'resumen', p_resumen,
      'metricas', coalesce(p_metricas, '{}'::jsonb),
      'evidencia', coalesce(p_evidencia, '[]'::jsonb)
    ),
    'informe',
    v_informe_id::text,
    p_correlacion_id,
    null,
    p_destino_escalado
  );

  return v_informe_id;
end;
$$;

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'sesiones','planes','trabajos_internos','dependencias_trabajo','entregas',
    'memorias','decisiones','hechos_operativos','ejecuciones_proceso','ingestas',
    'informes','eventos_salida','eventos_entrada'
  ] loop
    execute format('alter table quantumdepartamento.%I enable row level security', tabla);
    execute format('revoke all on quantumdepartamento.%I from public', tabla);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on quantumdepartamento.%I from anon', tabla);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke all on quantumdepartamento.%I from authenticated', tabla);
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
      execute format('grant all on quantumdepartamento.%I to service_role', tabla);
    end if;
  end loop;
end;
$$;

do $$
begin
  revoke execute on all functions in schema quantumdepartamento from public;
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant usage on schema quantumdepartamento to service_role;
    grant execute on all functions in schema quantumdepartamento to service_role;
  end if;
end;
$$;

comment on schema quantumdepartamento is
  'Plano de control interno de un módulo; sólo publica agregados y hechos relevantes a QuantumCore';
comment on table quantumdepartamento.hechos_operativos is
  'Bitácora durable de clientes, ingestas, procesos, trabajos, despliegues, incidentes, costos, seguridad y decisiones';
comment on table quantumdepartamento.informes is
  'Informes locales y escalados; elevar a Dominus o Sergio exige evidencia';
