-- =====================================================================
-- Glowment · Ficheiro 1 de 6: base e perfis dos utilizadores
--
-- O que este ficheiro faz:
--   0. Prepara regras gerais de segurança e uma função reutilizável
--   1. Cria os tipos de conta (cliente, proprietário, admin)
--   2. Cria a tabela "perfis" (nome, telefone, tipo de cada utilizador)
--   3. Cria o perfil automaticamente quando alguém se regista
--   4. Cria uma função para saber o tipo de conta de quem está no site
--   5. Define quem pode ver e editar cada perfil (RLS)
--   6. Define que colunas o site pode alterar (GRANT)
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Preparação
-- ---------------------------------------------------------------------

-- Por defeito, o PostgreSQL deixa qualquer pessoa (PUBLIC) executar funções novas.
-- Esta linha desliga isso: cada função só pode ser usada por quem nós autorizarmos.
alter default privileges in schema public revoke execute on functions from public;

-- Cria um "schema" (uma pasta dentro da base de dados) chamado "privado".
-- Aqui ficam as funções internas de segurança. O Supabase só expõe ao site
-- o schema "public", por isso ninguém consegue chamar estas funções diretamente.
create schema if not exists privado;

-- Os utilizadores do site (anon = visitante sem conta, authenticated = com sessão iniciada)
-- podem "entrar" na pasta privado, para as regras de segurança funcionarem.
grant usage on schema privado to anon, authenticated;

-- Função reutilizável: sempre que uma linha é alterada, atualiza a coluna "atualizado_em".
-- Vai ser usada por várias tabelas.
create or replace function public.definir_atualizado_em()  -- cria (ou substitui) a função
returns trigger                -- é uma função de trigger: corre sozinha quando uma linha muda
language plpgsql               -- escrita em PL/pgSQL, a linguagem de programação do PostgreSQL
set search_path = ''           -- segurança: obriga a escrever sempre o nome completo (ex.: public.perfis)
as $$                          -- os dois cifrões marcam o início do código da função
begin                          -- início das instruções
  new.atualizado_em := now();  -- "new" é a linha que vai ser gravada: mete lá a data e hora atuais
  return new;                  -- devolve a linha (já com a data nova) para ser gravada
end;                           -- fim das instruções
$$;                            -- os dois cifrões marcam o fim do código da função


-- ---------------------------------------------------------------------
-- 1. Tipos de conta
-- ---------------------------------------------------------------------

-- Um "enum" é uma lista fechada de valores: a coluna só aceita um destes três.
--   cliente      → marca serviços
--   proprietario → marca serviços e também gere salões
--   admin        → administrador da plataforma (só atribuído à mão, no painel)
create type public.tipo_conta as enum ('cliente', 'proprietario', 'admin');


-- ---------------------------------------------------------------------
-- 2. Tabela "perfis"
--    O Supabase guarda o email e a password na tabela auth.users (que é dele).
--    Os NOSSOS dados de cada utilizador ficam aqui, com o mesmo id.
-- ---------------------------------------------------------------------

create table public.perfis (
  -- id: o mesmo id da conta em auth.users.
  --   primary key → é único e identifica o perfil
  --   references auth.users (id) → tem de existir uma conta com este id
  --   on delete cascade → se a conta for apagada, o perfil é apagado também
  id            uuid primary key references auth.users (id) on delete cascade,

  -- nome: obrigatório (not null), entre 1 e 100 caracteres (sem contar espaços nas pontas)
  nome          text not null check (char_length(trim(nome)) between 1 and 100),

  -- telefone: opcional; se existir, só pode ter "+" no início, números e espaços (9 a 15)
  telefone      text check (telefone ~ '^\+?[0-9 ]{9,15}$'),

  -- tipo: cliente, proprietario ou admin; quem se regista começa como cliente
  tipo          public.tipo_conta not null default 'cliente',

  -- avatar_path: caminho da foto de perfil no Supabase Storage (opcional)
  avatar_path   text,

  -- datas de criação e da última alteração, preenchidas automaticamente
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Um comentário guardado na própria base de dados (aparece no painel do Supabase)
comment on column public.perfis.tipo is 'cliente = marca serviços; proprietario = também gere salões; admin = só atribuído manualmente';

-- Liga a função "definir_atualizado_em" a esta tabela:
create trigger perfis_atualizado_em                           -- nome do trigger
  before update on public.perfis                              -- corre ANTES de cada alteração a um perfil
  for each row execute function public.definir_atualizado_em(); -- para cada linha alterada, executa a função


-- ---------------------------------------------------------------------
-- 3. Criar o perfil automaticamente no registo
--    Quando alguém cria conta, o site envia o nome e o tipo ("cliente" ou
--    "proprietario"). Este código cria o perfil sozinho.
--    Segurança: mesmo que alguém envie "admin", fica como cliente.
-- ---------------------------------------------------------------------

create or replace function privado.criar_perfil_novo_utilizador()
returns trigger
language plpgsql
security definer        -- corre com as permissões de quem CRIOU a função (o administrador),
                        -- porque o utilizador acabado de registar ainda não pode escrever em "perfis"
set search_path = ''
as $$
begin
  insert into public.perfis (id, nome, tipo)           -- cria uma linha nova em perfis
  values (
    new.id,                                            -- o id da conta acabada de criar

    -- o nome enviado pelo site; se vier vazio, usa a parte do email antes do "@"
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nome'), ''), split_part(new.email, '@', 1)),

    -- só aceita "proprietario"; qualquer outra coisa (incluindo "admin") fica "cliente"
    case when new.raw_user_meta_data ->> 'tipo' = 'proprietario'
         then 'proprietario'::public.tipo_conta
         else 'cliente'::public.tipo_conta end
  );
  return new;                                          -- deixa a criação da conta continuar
end;
$$;

-- Ninguém do site pode chamar esta função diretamente: só o trigger abaixo
revoke execute on function privado.criar_perfil_novo_utilizador() from public, anon, authenticated;

create trigger ao_criar_utilizador                     -- nome do trigger
  after insert on auth.users                           -- corre DEPOIS de ser criada uma conta
  for each row execute function privado.criar_perfil_novo_utilizador();


-- ---------------------------------------------------------------------
-- 4. Saber o tipo de conta de quem está a usar o site
--    Usada nas regras de segurança (ex.: "só proprietários criam salões").
-- ---------------------------------------------------------------------

create or replace function privado.tipo_utilizador()
returns public.tipo_conta      -- devolve cliente, proprietario ou admin
language sql                   -- é só uma consulta SQL (não precisa de PL/pgSQL)
stable                         -- dentro da mesma consulta devolve sempre o mesmo (o PostgreSQL pode otimizar)
security definer               -- lê "perfis" com permissões de administrador
set search_path = ''
as $$
  -- auth.uid() é o id de quem tem a sessão iniciada no site
  select tipo from public.perfis where id = (select auth.uid());
$$;

revoke execute on function privado.tipo_utilizador() from public;          -- tira a permissão a todos
grant execute on function privado.tipo_utilizador() to anon, authenticated; -- e dá só a quem usa o site


-- ---------------------------------------------------------------------
-- 5. Segurança: RLS (Row Level Security = segurança por linha)
--    Com RLS ligado, ninguém vê nenhuma linha, a não ser que uma "policy" o permita.
-- ---------------------------------------------------------------------

alter table public.perfis enable row level security;   -- liga o RLS nesta tabela

create policy "Cada utilizador vê o seu perfil"         -- nome da regra
  on public.perfis for select                           -- aplica-se a LER perfis
  to authenticated                                      -- só para quem tem sessão iniciada
  using (id = (select auth.uid()));                     -- só as linhas cujo id é o do próprio utilizador

create policy "Cada utilizador edita o seu perfil"
  on public.perfis for update                           -- aplica-se a ALTERAR perfis
  to authenticated
  using (id = (select auth.uid()))                      -- só pode alterar o seu próprio perfil...
  with check (id = (select auth.uid()));                -- ...e depois da alteração continua a ser o seu

-- Não há policies de insert nem de delete:
--   o perfil é criado pelo trigger (secção 3) e apagado automaticamente com a conta.


-- ---------------------------------------------------------------------
-- 6. GRANT: que colunas o site pode usar
--    O RLS decide QUE LINHAS; o GRANT decide QUE COLUNAS.
-- ---------------------------------------------------------------------

grant select on public.perfis to authenticated;         -- quem tem sessão pode ler (o RLS limita ao seu perfil)

-- Só pode alterar o nome, o telefone e a foto.
-- A coluna "tipo" NÃO está na lista: assim ninguém se consegue tornar admin sozinho.
grant update (nome, telefone, avatar_path) on public.perfis to authenticated;
