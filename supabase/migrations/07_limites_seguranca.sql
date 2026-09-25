-- =====================================================================
-- Glowment · Ficheiro 7: limites anti-abuso e reforço de segurança
--
-- O que este ficheiro faz:
--   1. Fecha as funções internas (schema "privado") a quem não precisa delas
--   2. Impede mudar um profissional ou serviço de salão, e ligar contas alheias
--   3. Limita quantidades (salões, profissionais, serviços...) contra spam
--   4. Limita marcações por cliente (um robô não consegue encher uma agenda)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Funções internas: ninguém as executa por defeito
-- ---------------------------------------------------------------------

-- Funções novas no schema "privado" deixam de ser executáveis por qualquer pessoa
alter default privileges in schema privado revoke execute on functions from public;

-- As funções de trigger correm sozinhas; ninguém precisa de as chamar diretamente
revoke execute on function privado.validar_profissional_servico() from public;
revoke execute on function privado.preparar_nova_marcacao()       from public;
revoke execute on function privado.validar_mudanca_estado()       from public;
revoke execute on function privado.atualizar_nota_salao()         from public;


-- ---------------------------------------------------------------------
-- 2. Colunas que o site não pode alterar
-- ---------------------------------------------------------------------

-- Profissionais: o site escolhe o salão só ao criar, e nunca liga uma conta (perfil_id).
-- Sem isto, um proprietário podia "associar" a conta de outra pessoa ao seu salão.
revoke insert, update on public.profissionais from authenticated;
grant insert (salao_id, nome, especialidade, biografia, foto_path, ativo) on public.profissionais to authenticated;
grant update (nome, especialidade, biografia, foto_path, ativo)           on public.profissionais to authenticated;

-- Serviços: não mudam de salão depois de criados (evita misturar dados entre salões)
revoke insert, update on public.servicos from authenticated;
grant insert (salao_id, nome, descricao, duracao_min, preco_cents, ativo) on public.servicos to authenticated;
grant update (nome, descricao, duracao_min, preco_cents, ativo)           on public.servicos to authenticated;

-- Horários, ausências e portfólio: não mudam de profissional depois de criados
revoke update on public.horarios, public.ausencias, public.portfolio from authenticated;
grant update (dia_semana, hora_inicio, hora_fim)    on public.horarios  to authenticated;
grant update (inicio, fim, motivo)                  on public.ausencias to authenticated;
grant update (servico_id, imagem_path, legenda, ordem) on public.portfolio to authenticated;


-- ---------------------------------------------------------------------
-- 3. Limites de quantidade (contra spam e contas falsas)
--    Uma só função serve várias tabelas: recebe o nome da coluna a contar
--    e o máximo permitido.
-- ---------------------------------------------------------------------

create or replace function privado.limitar_quantidade()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coluna text := tg_argv[0];                         -- ex.: 'salao_id'
  v_maximo int  := tg_argv[1]::int;                    -- ex.: 20
  v_valor  text := to_jsonb(new) ->> v_coluna;          -- valor dessa coluna na linha nova
  v_total  int;
begin
  -- O administrador (painel do Supabase, sem sessão) não tem limites
  if auth.uid() is null then
    return new;
  end if;

  -- Conta quantas linhas já existem com o mesmo valor (ex.: no mesmo salão)
  execute format('select count(*) from %I.%I where %I::text = $1',
                 tg_table_schema, tg_table_name, v_coluna)
    into v_total
    using v_valor;

  if v_total >= v_maximo then
    raise exception 'Limite atingido: no máximo % registos em %', v_maximo, tg_table_name;
  end if;

  return new;
end;
$$;

revoke execute on function privado.limitar_quantidade() from public;

create trigger limite_saloes         before insert on public.saloes
  for each row execute function privado.limitar_quantidade('proprietario_id', '5');
create trigger limite_profissionais  before insert on public.profissionais
  for each row execute function privado.limitar_quantidade('salao_id', '20');
create trigger limite_servicos       before insert on public.servicos
  for each row execute function privado.limitar_quantidade('salao_id', '50');
create trigger limite_horarios       before insert on public.horarios
  for each row execute function privado.limitar_quantidade('profissional_id', '21');
create trigger limite_ausencias      before insert on public.ausencias
  for each row execute function privado.limitar_quantidade('profissional_id', '100');
create trigger limite_portfolio      before insert on public.portfolio
  for each row execute function privado.limitar_quantidade('profissional_id', '30');


-- ---------------------------------------------------------------------
-- 4. Limites nas marcações
--    - no máximo 5 marcações em aberto por cliente (em todos os salões)
--    - no máximo 2 marcações em aberto por cliente no mesmo salão
--    - só se marca até 90 dias no futuro
--    - o proprietário não marca no próprio salão (evita marcações falsas)
-- ---------------------------------------------------------------------

create or replace function privado.limitar_marcacoes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cliente uuid := auth.uid();
  v_salao   uuid := privado.salao_do_profissional(new.profissional_id);
begin
  if v_cliente is null then        -- administrador: sem limites
    return new;
  end if;

  -- Uma marcação de cada vez por cliente: impede contornar os limites
  -- com vários pedidos enviados ao mesmo tempo
  perform pg_advisory_xact_lock(hashtext(v_cliente::text));

  if privado.e_proprietario_do_salao(v_salao) then
    raise exception 'Não é possível marcar no próprio salão';
  end if;

  if new.inicio > now() + interval '90 days' then
    raise exception 'Só é possível marcar até 90 dias de antecedência';
  end if;

  if (select count(*) from public.marcacoes
      where cliente_id = v_cliente
        and estado in ('pendente', 'confirmada')
        and inicio > now()) >= 5 then
    raise exception 'Já tem 5 marcações em aberto';
  end if;

  if (select count(*) from public.marcacoes m
      join public.profissionais p on p.id = m.profissional_id
      where m.cliente_id = v_cliente
        and p.salao_id = v_salao
        and m.estado in ('pendente', 'confirmada')
        and m.inicio > now()) >= 2 then
    raise exception 'Já tem 2 marcações em aberto neste salão';
  end if;

  return new;
end;
$$;

revoke execute on function privado.limitar_marcacoes() from public;

-- O nome começa por "marcacoes_limites" para correr ANTES de "marcacoes_preparar"
-- (o PostgreSQL corre os triggers por ordem alfabética)
create trigger marcacoes_limites
  before insert on public.marcacoes
  for each row execute function privado.limitar_marcacoes();
