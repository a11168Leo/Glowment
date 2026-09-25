-- =====================================================
-- Glowment — Ficheiro 6 de 6: avaliações
-- =====================================================

create table public.avaliacoes (
  id          uuid primary key default gen_random_uuid(),
  marcacao_id uuid not null unique references public.marcacoes (id) on delete cascade,
  nota        smallint not null check (nota between 1 and 5),
  comentario  text check (char_length(comentario) <= 1000),
  criado_em   timestamptz not null default now()
);

-- Funções auxiliares
create or replace function privado.salao_da_marcacao(p_marcacao_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.salao_id
  from public.marcacoes m
  join public.profissionais p on p.id = m.profissional_id
  where m.id = p_marcacao_id;
$$;

-- Só quem teve a marcação, e só depois de concluída, pode avaliar
create or replace function privado.pode_avaliar(p_marcacao_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.marcacoes
    where id = p_marcacao_id
      and cliente_id = (select auth.uid())
      and estado = 'concluida'
  );
$$;

revoke execute on function privado.salao_da_marcacao(uuid), privado.pode_avaliar(uuid) from public;
grant execute on function privado.salao_da_marcacao(uuid), privado.pode_avaliar(uuid) to anon, authenticated;

-- RLS
alter table public.avaliacoes enable row level security;

create policy "Ver avaliações de salões visíveis"
  on public.avaliacoes for select to anon, authenticated
  using (privado.salao_visivel(privado.salao_da_marcacao(marcacao_id)));

create policy "Cliente avalia marcações concluídas"
  on public.avaliacoes for insert to authenticated
  with check (privado.pode_avaliar(marcacao_id));

create policy "Cliente edita a sua avaliação"
  on public.avaliacoes for update to authenticated
  using (privado.pode_avaliar(marcacao_id))
  with check (privado.pode_avaliar(marcacao_id));

create policy "Cliente apaga a sua avaliação"
  on public.avaliacoes for delete to authenticated
  using (privado.pode_avaliar(marcacao_id));

-- GRANTs
grant select on public.avaliacoes to anon;
grant select, delete on public.avaliacoes to authenticated;
grant insert (marcacao_id, nota, comentario) on public.avaliacoes to authenticated;
grant update (nota, comentario) on public.avaliacoes to authenticated;

-- Atualizar a nota média e o total de avaliações do salão automaticamente
create or replace function privado.atualizar_nota_salao()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_salao uuid := privado.salao_da_marcacao(coalesce(new.marcacao_id, old.marcacao_id));
begin
  update public.saloes s
  set nota_media = r.media,
      total_avaliacoes = r.total
  from (
    select round(avg(a.nota), 1) as media, count(*)::int as total
    from public.avaliacoes a
    where privado.salao_da_marcacao(a.marcacao_id) = v_salao
  ) r
  where s.id = v_salao;
  return null;
end;
$$;

create trigger avaliacoes_atualizar_nota
  after insert or update or delete on public.avaliacoes
  for each row execute function privado.atualizar_nota_salao();
