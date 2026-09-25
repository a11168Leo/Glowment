-- =====================================================================
-- Glowment · Ficheiro 9: auditoria (registo de alterações)
--
-- Guarda automaticamente QUEM alterou O QUÊ e QUANDO nas tabelas importantes:
--   perfis, saloes, servicos, profissionais, marcacoes, avaliacoes
--
-- Para quê:
--   - se um preço mudar, uma marcação for cancelada ou um salão apagado,
--     fica registado quem o fez, o valor antes e o valor depois
--   - permite investigar abusos ou erros
--
-- Segurança:
--   - a tabela fica no schema "privado": o site NÃO a consegue ler nem alterar
--   - só o administrador a vê, no painel do Supabase
--     (Table Editor > escolher o schema "privado" > auditoria)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Tabela da auditoria
-- ---------------------------------------------------------------------

create table privado.auditoria (
  id                bigint generated always as identity primary key,  -- número sequencial automático
  tabela            text not null,               -- ex.: 'servicos'
  operacao          text not null,               -- 'INSERT', 'UPDATE' ou 'DELETE'
  registo_id        uuid,                        -- id da linha alterada
  utilizador_id     uuid,                        -- quem fez (vazio = administrador no painel)
  origem            text not null,               -- 'site' ou 'administrador'
  colunas_alteradas text[],                      -- ex.: {preco_cents}
  dados_antes       jsonb,                       -- a linha antes da alteração
  dados_depois      jsonb,                       -- a linha depois da alteração
  criado_em         timestamptz not null default now()
);

comment on table privado.auditoria is 'Registo automático de alterações. Só leitura para o administrador.';

create index auditoria_registo_idx on privado.auditoria (tabela, registo_id);
create index auditoria_data_idx    on privado.auditoria (criado_em desc);

-- Ninguém do site lhe toca (nem para ler)
revoke all on privado.auditoria from public, anon, authenticated;
alter table privado.auditoria enable row level security;   -- sem policies = acesso negado


-- ---------------------------------------------------------------------
-- 2. Função que escreve na auditoria
--    É ligada às tabelas por triggers (secção 3) e corre sozinha.
-- ---------------------------------------------------------------------

create or replace function privado.registar_auditoria()
returns trigger
language plpgsql
security definer          -- escreve na auditoria mesmo que o utilizador não tenha permissão
set search_path = ''
as $$
declare
  v_antes   jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_depois  jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_colunas text[];
begin
  -- Numa alteração, descobre que colunas mudaram de valor
  if tg_op = 'UPDATE' then
    select array_agg(d.key order by d.key) into v_colunas
    from jsonb_each(v_depois) d
    where d.value is distinct from v_antes -> d.key
      and d.key <> 'atualizado_em';                 -- esta muda sempre, não interessa

    if v_colunas is null then                       -- nada de relevante mudou: não regista
      return null;
    end if;
  end if;

  insert into privado.auditoria
    (tabela, operacao, registo_id, utilizador_id, origem, colunas_alteradas, dados_antes, dados_depois)
  values (
    tg_table_name,
    tg_op,
    coalesce(v_depois ->> 'id', v_antes ->> 'id')::uuid,
    auth.uid(),
    case when auth.uid() is null then 'administrador' else 'site' end,
    v_colunas,
    v_antes,
    v_depois
  );

  return null;   -- trigger "after": o valor devolvido é ignorado
end;
$$;

revoke execute on function privado.registar_auditoria() from public;


-- ---------------------------------------------------------------------
-- 3. Ligar a auditoria às tabelas importantes
--    (as marcações e avaliações novas não são registadas, só alteradas/apagadas,
--     para a auditoria não crescer demasiado)
-- ---------------------------------------------------------------------

create trigger auditoria after update or delete on public.perfis
  for each row execute function privado.registar_auditoria();

create trigger auditoria after insert or update or delete on public.saloes
  for each row execute function privado.registar_auditoria();

create trigger auditoria after insert or update or delete on public.servicos
  for each row execute function privado.registar_auditoria();

create trigger auditoria after insert or update or delete on public.profissionais
  for each row execute function privado.registar_auditoria();

create trigger auditoria after update or delete on public.marcacoes
  for each row execute function privado.registar_auditoria();

create trigger auditoria after update or delete on public.avaliacoes
  for each row execute function privado.registar_auditoria();


-- ---------------------------------------------------------------------
-- 4. Limpeza (RGPD: não guardar dados pessoais para sempre)
--    Apaga registos com mais de 1 ano. O administrador corre no SQL Editor:
--      select privado.limpar_auditoria_antiga();
-- ---------------------------------------------------------------------

create or replace function privado.limpar_auditoria_antiga()
returns integer
language sql
security definer
set search_path = ''
as $$
  with apagados as (
    delete from privado.auditoria
    where criado_em < now() - interval '1 year'
    returning 1
  )
  select count(*)::integer from apagados;
$$;

revoke execute on function privado.limpar_auditoria_antiga() from public, anon, authenticated;
