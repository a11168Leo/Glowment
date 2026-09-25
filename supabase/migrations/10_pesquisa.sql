-- =====================================================================
-- Glowment · Ficheiro 10: pesquisa de salões e barbearias
--
-- O que este ficheiro faz:
--   1. Ativa duas extensões do PostgreSQL (já incluídas no Supabase, grátis):
--        unaccent → ignora acentos   ("espaco lotus" encontra "Espaço Lótus")
--        pg_trgm  → tolera erros     ("barbaria" encontra "Barbearia")
--   2. Dá a cada serviço uma CATEGORIA fixa (cabelo, barba, unhas...), para
--      comparar salões que dão nomes diferentes ao mesmo serviço
--      (pesquisar "unhas" encontra um salão que chama ao serviço "Manicure")
--   3. Cria a função pesquisar_saloes(), chamada pela barra de pesquisa do site
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Extensões e função de normalização
-- ---------------------------------------------------------------------

create extension if not exists unaccent with schema extensions;
create extension if not exists pg_trgm  with schema extensions;

-- Transforma um texto numa forma "comparável": minúsculas e sem acentos.
--   'Espaço Lótus' → 'espaco lotus'
-- "immutable" = para o mesmo texto devolve sempre o mesmo resultado
-- (é obrigatório para poder ser usada em índices).
create or replace function privado.normalizar(p_texto text)
returns text
language sql
immutable
parallel safe
as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, p_texto));
$$;

grant execute on function privado.normalizar(text) to anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. Categorias de serviço
-- ---------------------------------------------------------------------

create type public.categoria_servico as enum (
  'cabelo', 'barba', 'unhas', 'sobrancelhas', 'estetica',
  'maquilhagem', 'depilacao', 'massagem', 'outro'
);

-- Serviços que já existem ficam como 'outro'; o proprietário pode mudar depois
alter table public.servicos
  add column categoria public.categoria_servico not null default 'outro';

-- O site pode escolher a categoria ao criar e ao editar um serviço
grant insert (categoria), update (categoria) on public.servicos to authenticated;

create index servicos_categoria_idx on public.servicos (categoria) where ativo;


-- ---------------------------------------------------------------------
-- 3. Índices de pesquisa (tornam a pesquisa rápida mesmo com muitos salões)
--    "gin_trgm_ops" parte o texto em pedaços de 3 letras:
--    'barbearia' → bar, arb, rbe, bea, ear, ari, ria
--    e assim encontra palavras parecidas, mesmo com erros.
-- ---------------------------------------------------------------------

create index saloes_nome_pesquisa_idx   on public.saloes   using gin (privado.normalizar(nome)   extensions.gin_trgm_ops);
create index saloes_cidade_pesquisa_idx on public.saloes   using gin (privado.normalizar(cidade) extensions.gin_trgm_ops);
create index servicos_nome_pesquisa_idx on public.servicos using gin (privado.normalizar(nome)   extensions.gin_trgm_ops);


-- ---------------------------------------------------------------------
-- 4. Função de pesquisa (o site chama-a com supabase.rpc('pesquisar_saloes', ...))
--
--    Todos os parâmetros são opcionais:
--      p_texto             → nome do salão, cidade ou serviço ("corte", "aurora")
--      p_local             → cidade ("lisboa", "coimbra")
--      p_categoria         → 'salao' ou 'barbearia'
--      p_categoria_servico → 'barba', 'unhas', ...
--      p_limite            → quantos resultados (1 a 50; por defeito 20)
--
--    Segurança: "security invoker" = corre com as permissões de quem pesquisa,
--    por isso as regras RLS aplicam-se. Só aparecem salões publicados.
-- ---------------------------------------------------------------------

create or replace function public.pesquisar_saloes(
  p_texto             text default null,
  p_local             text default null,
  p_categoria         public.categoria_salao default null,
  p_categoria_servico public.categoria_servico default null,
  p_limite            int default 20
)
returns table (
  id               uuid,
  nome             text,
  slug             text,
  categoria        public.categoria_salao,
  cidade           text,
  nota_media       numeric,
  total_avaliacoes int,
  capa_path        text,
  servicos         text[],
  relevancia       real
)
language sql
stable
security invoker
set search_path = ''
as $$
  with termos as (
    select
      -- texto normalizado, até 100 caracteres, sem os caracteres especiais do LIKE (% e _)
      nullif(regexp_replace(privado.normalizar(trim(left(p_texto, 100))), '[%_\\]', '', 'g'), '') as texto,
      nullif(regexp_replace(privado.normalizar(trim(left(p_local, 100))), '[%_\\]', '', 'g'), '') as local
  ),
  resultados as (
    select
      s.*,
      -- Relevância: quão parecido é o texto com o nome, a cidade ou um serviço (0 a 1)
      case when t.texto is null then 0 else greatest(
        extensions.word_similarity(t.texto, privado.normalizar(s.nome)),
        extensions.word_similarity(t.texto, privado.normalizar(s.cidade)),
        coalesce((select max(extensions.word_similarity(t.texto, privado.normalizar(sv.nome)))
                  from public.servicos sv
                  where sv.salao_id = s.id and sv.ativo), 0),
        -- o texto é o nome de uma categoria que o salão tem (ex.: "unhas" → Manicure)
        case when exists (select 1 from public.servicos sv
                          where sv.salao_id = s.id and sv.ativo
                            and (sv.categoria::text like t.texto || '%' or t.texto like sv.categoria::text || '%'))
             then 0.8 else 0 end
      ) end::real as relevancia
    from public.saloes s
    cross join termos t
    where s.publicado
      and (p_categoria is null or s.categoria = p_categoria)
      and (p_categoria_servico is null or exists (
            select 1 from public.servicos sv
            where sv.salao_id = s.id and sv.ativo and sv.categoria = p_categoria_servico))
      -- Local: contém o texto, ou é parecido (tolera erros de escrita)
      and (t.local is null
           or privado.normalizar(s.cidade) like '%' || t.local || '%'
           or extensions.word_similarity(t.local, privado.normalizar(s.cidade)) >= 0.5)
      -- Texto: aparece no nome, na cidade ou num serviço, ou é parecido com o nome
      and (t.texto is null
           or privado.normalizar(s.nome)   like '%' || t.texto || '%'
           or privado.normalizar(s.cidade) like '%' || t.texto || '%'
           or extensions.word_similarity(t.texto, privado.normalizar(s.nome)) >= 0.5
           or exists (
                select 1 from public.servicos sv
                where sv.salao_id = s.id and sv.ativo
                  and (privado.normalizar(sv.nome) like '%' || t.texto || '%'
                       or extensions.word_similarity(t.texto, privado.normalizar(sv.nome)) >= 0.5
                       or sv.categoria::text like t.texto || '%'            -- "unha"  → unhas
                       or t.texto like sv.categoria::text || '%')))         -- "unhas de gel" → unhas
  )
  select
    r.id, r.nome, r.slug, r.categoria, r.cidade, r.nota_media, r.total_avaliacoes, r.capa_path,
    array(select sv.nome from public.servicos sv
          where sv.salao_id = r.id and sv.ativo
          order by sv.nome limit 3) as servicos,
    r.relevancia
  from resultados r
  order by r.relevancia desc, r.nota_media desc nulls last, r.nome
  limit least(greatest(coalesce(p_limite, 20), 1), 50);
$$;

revoke execute on function public.pesquisar_saloes(text, text, public.categoria_salao, public.categoria_servico, int) from public;
grant execute on function public.pesquisar_saloes(text, text, public.categoria_salao, public.categoria_servico, int) to anon, authenticated;
