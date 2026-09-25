-- =====================================================
-- Glowment — Ficheiro 2 de 6: salões
-- =====================================================

-- Categoria do estabelecimento (o site mostra salões e barbearias em secções separadas)
create type public.categoria_salao as enum ('salao', 'barbearia');

create table public.saloes (
  id              uuid primary key default gen_random_uuid(),
  proprietario_id uuid not null default auth.uid()
                  references public.perfis (id) on delete cascade,
  nome            text not null check (char_length(nome) between 2 and 100),
  categoria       public.categoria_salao not null default 'salao',
  slug            text not null unique
                  check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 60),
  descricao       text check (char_length(descricao) <= 1000),
  telefone        text check (telefone ~ '^\+?[0-9 ]{9,15}$'),
  email           text check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  morada          text not null,
  codigo_postal   text not null check (codigo_postal ~ '^\d{4}-\d{3}$'),
  cidade          text not null,
  latitude        double precision check (latitude between -90 and 90),
  longitude       double precision check (longitude between -180 and 180),
  logo_path       text,
  capa_path       text,
  publicado       boolean not null default false,
  -- Calculados automaticamente a partir das avaliações (o site não os pode escrever)
  nota_media       numeric(2, 1),
  total_avaliacoes int not null default 0,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

comment on table public.saloes is 'Salões registados no Glowment. Um proprietário pode ter vários (ex.: várias unidades).';
comment on column public.saloes.slug is 'Endereço público: glowment.pt/<slug>';
comment on column public.saloes.publicado is 'Só aparece nas pesquisas quando o proprietário publica.';

create index saloes_proprietario_id_idx on public.saloes (proprietario_id);
create index saloes_cidade_idx on public.saloes (lower(cidade)) where publicado;
create index saloes_categoria_idx on public.saloes (categoria, nota_media desc) where publicado;

create trigger saloes_atualizado_em
  before update on public.saloes
  for each row execute function public.definir_atualizado_em();

-- Funções auxiliares (usadas nas regras de segurança desta e das próximas tabelas)
create or replace function privado.e_proprietario_do_salao(p_salao_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.saloes
    where id = p_salao_id and proprietario_id = (select auth.uid())
  );
$$;

create or replace function privado.salao_visivel(p_salao_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.saloes
    where id = p_salao_id
      and (publicado or proprietario_id = (select auth.uid()))
  );
$$;

revoke execute on function privado.e_proprietario_do_salao(uuid), privado.salao_visivel(uuid) from public;
grant execute on function privado.e_proprietario_do_salao(uuid), privado.salao_visivel(uuid) to anon, authenticated;

-- RLS
alter table public.saloes enable row level security;

create policy "Ver salões publicados ou os próprios"
  on public.saloes for select
  to anon, authenticated
  using (publicado or proprietario_id = (select auth.uid()));

create policy "Só proprietários criam salões"
  on public.saloes for insert
  to authenticated
  with check (
    proprietario_id = (select auth.uid())
    and (select privado.tipo_utilizador()) in ('proprietario', 'admin')
  );

create policy "Proprietários editam os seus salões"
  on public.saloes for update
  to authenticated
  using (proprietario_id = (select auth.uid()))
  with check (proprietario_id = (select auth.uid()));

create policy "Proprietários apagam os seus salões"
  on public.saloes for delete
  to authenticated
  using (proprietario_id = (select auth.uid()));

-- GRANTs por coluna: proprietario_id, criado_em, etc. não podem ser escritos pelo site
grant select on public.saloes to anon;
grant select, delete on public.saloes to authenticated;

grant insert (nome, categoria, slug, descricao, telefone, email, morada, codigo_postal,
              cidade, latitude, longitude, logo_path, capa_path, publicado)
  on public.saloes to authenticated;

grant update (nome, categoria, slug, descricao, telefone, email, morada, codigo_postal,
              cidade, latitude, longitude, logo_path, capa_path, publicado)
  on public.saloes to authenticated;
