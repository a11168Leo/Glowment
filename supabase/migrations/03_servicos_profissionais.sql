-- =====================================================
-- Glowment — Ficheiro 3 de 6: serviços, profissionais e portfólio
-- =====================================================

-- 1. Serviços
create table public.servicos (
  id            uuid primary key default gen_random_uuid(),
  salao_id      uuid not null references public.saloes (id) on delete cascade,
  nome          text not null check (char_length(nome) between 2 and 100),
  descricao     text check (char_length(descricao) <= 500),
  duracao_min   int  not null check (duracao_min between 5 and 480),
  preco_cents   int  not null check (preco_cents >= 0),
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

comment on column public.servicos.preco_cents is 'Preço em cêntimos: 12,50 € = 1250';

create index servicos_salao_id_idx on public.servicos (salao_id);

create trigger servicos_atualizado_em
  before update on public.servicos
  for each row execute function public.definir_atualizado_em();

-- 2. Profissionais
create table public.profissionais (
  id            uuid primary key default gen_random_uuid(),
  salao_id      uuid not null references public.saloes (id) on delete cascade,
  perfil_id     uuid references public.perfis (id) on delete set null,
  nome          text not null check (char_length(nome) between 2 and 100),
  especialidade text check (char_length(especialidade) <= 100),
  biografia     text check (char_length(biografia) <= 1000),
  foto_path     text,
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index profissionais_salao_id_idx on public.profissionais (salao_id);

create trigger profissionais_atualizado_em
  before update on public.profissionais
  for each row execute function public.definir_atualizado_em();

-- Função auxiliar: a que salão pertence um profissional
create or replace function privado.salao_do_profissional(p_profissional_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select salao_id from public.profissionais where id = p_profissional_id;
$$;

revoke execute on function privado.salao_do_profissional(uuid) from public;
grant execute on function privado.salao_do_profissional(uuid) to anon, authenticated;

-- 3. Que serviços cada profissional faz (N:N)
create table public.profissional_servicos (
  profissional_id uuid not null references public.profissionais (id) on delete cascade,
  servico_id      uuid not null references public.servicos (id) on delete cascade,
  primary key (profissional_id, servico_id)
);

create index profissional_servicos_servico_id_idx on public.profissional_servicos (servico_id);

-- Garante que o profissional e o serviço são do MESMO salão
create or replace function privado.validar_profissional_servico()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if privado.salao_do_profissional(new.profissional_id)
     is distinct from (select salao_id from public.servicos where id = new.servico_id) then
    raise exception 'O profissional e o serviço têm de pertencer ao mesmo salão';
  end if;
  return new;
end;
$$;

create trigger profissional_servicos_validar
  before insert or update on public.profissional_servicos
  for each row execute function privado.validar_profissional_servico();

-- 4. Portfólio (fotos de trabalhos de cada profissional)
create table public.portfolio (
  id              uuid primary key default gen_random_uuid(),
  profissional_id uuid not null references public.profissionais (id) on delete cascade,
  servico_id      uuid references public.servicos (id) on delete set null,
  imagem_path     text not null,
  legenda         text check (char_length(legenda) <= 200),
  ordem           smallint not null default 0,
  criado_em       timestamptz not null default now()
);

create index portfolio_profissional_id_idx on public.portfolio (profissional_id, ordem);

-- 5. RLS
alter table public.servicos              enable row level security;
alter table public.profissionais         enable row level security;
alter table public.profissional_servicos enable row level security;
alter table public.portfolio             enable row level security;

-- Serviços
create policy "Ver serviços de salões visíveis"
  on public.servicos for select to anon, authenticated
  using (privado.salao_visivel(salao_id));

create policy "Proprietário gere os serviços do seu salão"
  on public.servicos for all to authenticated
  using (privado.e_proprietario_do_salao(salao_id))
  with check (privado.e_proprietario_do_salao(salao_id));

-- Profissionais
create policy "Ver profissionais de salões visíveis"
  on public.profissionais for select to anon, authenticated
  using (privado.salao_visivel(salao_id));

create policy "Proprietário gere os profissionais do seu salão"
  on public.profissionais for all to authenticated
  using (privado.e_proprietario_do_salao(salao_id))
  with check (privado.e_proprietario_do_salao(salao_id));

-- Profissional ↔ serviços
create policy "Ver que serviços cada profissional faz"
  on public.profissional_servicos for select to anon, authenticated
  using (privado.salao_visivel(privado.salao_do_profissional(profissional_id)));

create policy "Proprietário gere os serviços dos seus profissionais"
  on public.profissional_servicos for all to authenticated
  using (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)))
  with check (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)));

-- Portfólio
create policy "Ver portfólio de salões visíveis"
  on public.portfolio for select to anon, authenticated
  using (privado.salao_visivel(privado.salao_do_profissional(profissional_id)));

create policy "Proprietário gere o portfólio dos seus profissionais"
  on public.portfolio for all to authenticated
  using (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)))
  with check (privado.e_proprietario_do_salao(privado.salao_do_profissional(profissional_id)));

-- 6. GRANTs
grant select on public.servicos, public.profissionais,
                public.profissional_servicos, public.portfolio to anon;

grant select, insert, update, delete on public.servicos, public.profissionais,
                public.profissional_servicos, public.portfolio to authenticated;
