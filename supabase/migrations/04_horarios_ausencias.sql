-- =====================================================
-- Glowment — Ficheiro 4 de 6: horários e ausências
-- =====================================================

-- Extensão que permite misturar "=" e "sobreposição" na mesma regra (exclusion constraint)
create extension if not exists btree_gist with schema extensions;

-- Tipo "intervalo de horas" (ex.: 09:00–13:00), para detetar sobreposições
create type public.intervalo_horas as range (subtype = time);

-- 1. Horário semanal fixo de cada profissional
create table public.horarios (
  id              uuid primary key default gen_random_uuid(),
  profissional_id uuid not null references public.profissionais (id) on delete cascade,
  dia_semana      smallint not null check (dia_semana between 0 and 6),
  hora_inicio     time not null,
  hora_fim        time not null,
  constraint horarios_fim_depois_inicio check (hora_fim > hora_inicio),
  -- No mesmo dia, os intervalos do mesmo profissional não se podem sobrepor
  constraint horarios_sem_sobreposicao exclude using gist (
    profissional_id with =,
    dia_semana with =,
    public.intervalo_horas(hora_inicio, hora_fim) with &&
  )
);

comment on column public.horarios.dia_semana is '0 = domingo, 1 = segunda ... 6 = sábado';

-- 2. Ausências (férias, folgas, feriados...)
create table public.ausencias (
  id              uuid primary key default gen_random_uuid(),
  profissional_id uuid not null references public.profissionais (id) on delete cascade,
  inicio          timestamptz not null,
  fim             timestamptz not null,
  motivo          text check (char_length(motivo) <= 200),
  constraint ausencias_fim_depois_inicio check (fim > inicio)
);

create index ausencias_profissional_idx on public.ausencias using gist (profissional_id, tstzrange(inicio, fim));

-- 3. RLS
alter table public.horarios  enable row level security;
alter table public.ausencias enable row level security;

create policy "Ver horários de salões visíveis"
  on public.horarios for select to anon, authenticated
  using (privado.salao_visivel(privado.salao_do_profissional(profissional_id)));

create policy "Proprietário gere os horários"
  on public.horarios for all to authenticated
  using (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)))
  with check (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)));

-- Ausências são privadas (o motivo pode ser pessoal): só o proprietário as vê.
-- Os clientes só veem as vagas livres, através da função vagas_disponiveis (migration 0005).
create policy "Proprietário gere as ausências"
  on public.ausencias for all to authenticated
  using (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)))
  with check (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)));

-- 4. GRANTs
grant select on public.horarios to anon;
grant select, insert, update, delete on public.horarios, public.ausencias to authenticated;
