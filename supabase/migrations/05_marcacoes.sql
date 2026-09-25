-- =====================================================
-- Glowment — Ficheiro 5 de 6: marcações (o coração do sistema)
-- =====================================================

create type public.estado_marcacao as enum
  ('pendente', 'confirmada', 'concluida', 'cancelada', 'falta');

-- 1. Tabela
create table public.marcacoes (
  id              uuid primary key default gen_random_uuid(),
  cliente_id      uuid not null default auth.uid()
                  references public.perfis (id) on delete restrict,
  profissional_id uuid not null references public.profissionais (id) on delete restrict,
  servico_id      uuid not null references public.servicos (id) on delete restrict,
  inicio          timestamptz not null,
  fim             timestamptz not null,
  preco_cents     int not null check (preco_cents >= 0),
  estado          public.estado_marcacao not null default 'pendente',
  notas           text check (char_length(notas) <= 500),
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),

  constraint marcacoes_fim_depois_inicio check (fim > inicio),

  -- >>> A REGRA ANTI-CONFLITO <<<
  -- O mesmo profissional não pode ter duas marcações ATIVAS cujos horários se sobreponham.
  -- tstzrange(inicio, fim) é o intervalo [inicio, fim) — 10:00–10:30 e 10:30–11:00 NÃO chocam.
  -- Marcações canceladas / concluídas / falta não contam.
  constraint marcacoes_sem_sobreposicao exclude using gist (
    profissional_id with =,
    tstzrange(inicio, fim) with &&
  ) where (estado in ('pendente', 'confirmada'))
);

create index marcacoes_cliente_idx on public.marcacoes (cliente_id, inicio desc);
create index marcacoes_profissional_idx on public.marcacoes (profissional_id, inicio);

create trigger marcacoes_atualizado_em
  before update on public.marcacoes
  for each row execute function public.definir_atualizado_em();

-- 2. Ao criar uma marcação: calcular fim e preço, e validar tudo
create or replace function privado.preparar_nova_marcacao()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_servico      public.servicos;
  v_inicio_local timestamp;
  v_fim_local    timestamp;
begin
  -- O serviço existe, está ativo, e o salão está publicado?
  select s.* into v_servico
  from public.servicos s
  join public.saloes sa on sa.id = s.salao_id
  where s.id = new.servico_id
    and ((s.ativo and sa.publicado) or auth.uid() is null);

  if not found then
    raise exception 'Serviço indisponível';
  end if;

  -- O profissional está ativo e faz este serviço?
  if not exists (
    select 1
    from public.profissional_servicos ps
    join public.profissionais p on p.id = ps.profissional_id
    where ps.profissional_id = new.profissional_id
      and ps.servico_id = new.servico_id
      and p.ativo
  ) then
    raise exception 'Este profissional não faz este serviço';
  end if;

  -- Valores calculados pela base de dados (o site não os pode falsificar)
  new.fim         := new.inicio + make_interval(mins => v_servico.duracao_min);
  new.preco_cents := v_servico.preco_cents;

  -- Inserções feitas pelo administrador no painel do Supabase (sem utilizador com sessão),
  -- por exemplo os dados de demonstração, podem registar marcações antigas.
  -- A regra anti-conflito continua a aplicar-se na mesma (é uma constraint da tabela).
  if auth.uid() is null then
    return new;
  end if;

  new.estado := 'pendente';

  -- Não se marca no passado
  if new.inicio <= now() then
    raise exception 'Não é possível marcar no passado';
  end if;

  -- Tem de caber dentro do horário do profissional (hora de Portugal)
  v_inicio_local := new.inicio at time zone 'Europe/Lisbon';
  v_fim_local    := new.fim    at time zone 'Europe/Lisbon';

  if v_inicio_local::date <> v_fim_local::date or not exists (
    select 1 from public.horarios h
    where h.profissional_id = new.profissional_id
      and h.dia_semana = extract(dow from v_inicio_local)
      and h.hora_inicio <= v_inicio_local::time
      and h.hora_fim    >= v_fim_local::time
  ) then
    raise exception 'Fora do horário do profissional';
  end if;

  -- Não pode calhar numa ausência (férias, folga...)
  if exists (
    select 1 from public.ausencias a
    where a.profissional_id = new.profissional_id
      and tstzrange(a.inicio, a.fim) && tstzrange(new.inicio, new.fim)
  ) then
    raise exception 'O profissional não está disponível nesse período';
  end if;

  -- A sobreposição com outras marcações é garantida pela constraint marcacoes_sem_sobreposicao
  return new;
end;
$$;

create trigger marcacoes_preparar
  before insert on public.marcacoes
  for each row execute function privado.preparar_nova_marcacao();

-- 3. Ao mudar o estado: só são permitidas certas transições
--    Cliente:      pendente/confirmada -> cancelada (antes da hora)
--    Proprietário: pendente -> confirmada | cancelada
--                  confirmada -> concluida | falta (depois da hora) | cancelada
--    concluida, cancelada e falta são estados finais.
create or replace function privado.validar_mudanca_estado()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_e_proprietario boolean;
begin
  if new.estado = old.estado then
    return new;
  end if;

  -- Alterações feitas no dashboard do Supabase (sem utilizador) são permitidas
  if auth.uid() is null then
    return new;
  end if;

  if old.estado in ('concluida', 'cancelada', 'falta') then
    raise exception 'Esta marcação já está fechada (%)', old.estado;
  end if;

  v_e_proprietario := privado.e_proprietario_do_salao(privado.salao_do_profissional(old.profissional_id));

  if v_e_proprietario then
    if new.estado = 'pendente' then
      raise exception 'Não é possível voltar a pendente';
    elsif new.estado in ('concluida', 'falta') and (old.estado <> 'confirmada' or old.inicio > now()) then
      raise exception 'Só uma marcação confirmada e já iniciada pode ficar %', new.estado;
    end if;
  else
    -- É o cliente
    if new.estado <> 'cancelada' then
      raise exception 'O cliente só pode cancelar a marcação';
    elsif old.inicio <= now() then
      raise exception 'Já não é possível cancelar esta marcação';
    end if;
  end if;

  return new;
end;
$$;

create trigger marcacoes_validar_estado
  before update on public.marcacoes
  for each row execute function privado.validar_mudanca_estado();

-- 4. RLS
alter table public.marcacoes enable row level security;

create policy "Cliente vê as suas marcações; proprietário vê as do salão"
  on public.marcacoes for select to authenticated
  using (
    cliente_id = (select auth.uid())
    or privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id))
  );

create policy "Clientes com conta fazem marcações para si próprios"
  on public.marcacoes for insert to authenticated
  with check (cliente_id = (select auth.uid()));

create policy "Cliente e proprietário mudam o estado"
  on public.marcacoes for update to authenticated
  using (
    cliente_id = (select auth.uid())
    or privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id))
  )
  with check (
    cliente_id = (select auth.uid())
    or privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id))
  );

-- Sem política de delete: marcações nunca se apagam, mudam de estado.

-- O proprietário pode ver o perfil (nome, telefone) dos clientes que marcaram no seu salão
create policy "Proprietário vê os clientes das suas marcações"
  on public.perfis for select to authenticated
  using (
    exists (
      select 1 from public.marcacoes m
      where m.cliente_id = perfis.id
        and privado.e_proprietario_do_salao(privado.salao_do_profissional(m.profissional_id))
    )
  );

-- 5. GRANTs: o site só escolhe profissional, serviço, hora e notas; só pode mudar o estado
grant select on public.marcacoes to authenticated;
grant insert (profissional_id, servico_id, inicio, notas) on public.marcacoes to authenticated;
grant update (estado) on public.marcacoes to authenticated;

-- 6. Vagas livres de um profissional para um serviço num dia (chamada pelo site via RPC)
--    Devolve só horas livres — nunca dados de outros clientes.
create or replace function public.vagas_disponiveis(
  p_profissional_id uuid,
  p_servico_id      uuid,
  p_data            date
)
returns table (inicio timestamptz, fim timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  with servico as (
    select s.duracao_min
    from public.servicos s
    join public.saloes sa on sa.id = s.salao_id and sa.publicado
    join public.profissional_servicos ps on ps.servico_id = s.id
                                        and ps.profissional_id = p_profissional_id
    join public.profissionais p on p.id = p_profissional_id and p.ativo
    where s.id = p_servico_id and s.ativo
  ),
  candidatos as (
    select g.inicio, g.inicio + make_interval(mins => sv.duracao_min) as fim
    from public.horarios h
    cross join servico sv
    cross join lateral generate_series(
      ((p_data + h.hora_inicio) at time zone 'Europe/Lisbon'),
      ((p_data + h.hora_fim) at time zone 'Europe/Lisbon') - make_interval(mins => sv.duracao_min),
      interval '15 minutes'
    ) as g(inicio)
    where h.profissional_id = p_profissional_id
      and h.dia_semana = extract(dow from p_data)
  )
  select c.inicio, c.fim
  from candidatos c
  where c.inicio > now()
    and not exists (
      select 1 from public.ausencias a
      where a.profissional_id = p_profissional_id
        and tstzrange(a.inicio, a.fim) && tstzrange(c.inicio, c.fim)
    )
    and not exists (
      select 1 from public.marcacoes m
      where m.profissional_id = p_profissional_id
        and m.estado in ('pendente', 'confirmada')
        and tstzrange(m.inicio, m.fim) && tstzrange(c.inicio, c.fim)
    )
  order by c.inicio;
$$;

revoke execute on function public.vagas_disponiveis(uuid, uuid, date) from public;
grant execute on function public.vagas_disponiveis(uuid, uuid, date) to anon, authenticated;

-- 7. Número de marcações feitas hoje em toda a plataforma (contador da página inicial)
--    Devolve só um número, nunca dados das marcações.
create or replace function public.marcacoes_hoje()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.marcacoes
  where estado <> 'cancelada'
    and criado_em >= (date_trunc('day', now() at time zone 'Europe/Lisbon') at time zone 'Europe/Lisbon');
$$;

revoke execute on function public.marcacoes_hoje() from public;
grant execute on function public.marcacoes_hoje() to anon, authenticated;
