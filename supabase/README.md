# Base de dados do Glowment (Supabase / PostgreSQL)

## Pastas

- `migrations/` — a estrutura da base de dados, um ficheiro por tema, **por ordem**:

  | # | Ficheiro | O que cria |
  |---|---|---|
  | 1 | `01_perfis.sql` | Perfis dos utilizadores (cliente / proprietário), criados automaticamente no registo |
  | 2 | `02_saloes.sql` | Salões e barbearias |
  | 3 | `03_servicos_profissionais.sql` | Serviços, profissionais, quem faz o quê, portfólio |
  | 4 | `04_horarios_ausencias.sql` | Horário semanal e ausências (férias, folgas) |
  | 5 | `05_marcacoes.sql` | Marcações, **regra anti-conflito**, vagas livres |
  | 6 | `06_avaliacoes.sql` | Avaliações e nota média automática |
  | 7 | `07_limites_seguranca.sql` | Limites anti-abuso e reforço das permissões |
  | 8 | `08_anti_robos.sql` | Barreiras contra robôs: email confirmado, ritmo de marcações, faltas |
  | 9 | `09_auditoria.sql` | Registo automático de quem alterou o quê e quando |

- `testes/testes_base_de_dados.sql` — 37 testes automáticos (segurança e agenda).
- `demo/` — dados de demonstração (3 salões + 3 barbearias) e o script para os apagar.

## Aplicar numa base de dados nova

1. Supabase (projeto **dev**) > **SQL Editor** > **New query**.
2. Cola **o ficheiro 1**, clica em **Run** e confirma que aparece *Success*.
3. Repete para os ficheiros 2 a 9, **por esta ordem**.
4. Corre `testes/testes_base_de_dados.sql`. Deve aparecer
   **"✅ TODOS OS TESTES PASSARAM (37/37)"** (aparece como erro de propósito: é assim que o teste se desfaz).
5. Só depois repetir tudo no projeto **prod**.

## Ligar o site

1. Supabase > **Project Settings > API Keys**: copia o **URL** e a chave **publishable**.
2. Em `frontend/`, copia `.env.example` para `.env` e preenche as duas variáveis.
3. `npm run dev`.

> Nunca coloques a chave **secret / service_role** no frontend nem no Git.

## Dados de demonstração

1. **Authentication > Users > Add user** (marca *Auto Confirm User*) e cria:
   `salao@demo.glowment.pt`, `barbearia@demo.glowment.pt`, `cliente@demo.glowment.pt`.
2. **SQL Editor**: corre `demo/dados_demo.sql`.
3. Para apagar: `demo/remover_demo.sql`.

## Regras de segurança (resumo)

- **RLS** em todas as tabelas: cada utilizador só vê e altera o que é seu.
- **Permissões por coluna**: o site nunca escreve o dono, o preço, o fim da marcação, o estado inicial, a nota média nem o tipo de conta.
- **Ninguém se regista como admin**; o tipo de conta não pode ser alterado pelo próprio utilizador.
- **Marcações sem conflitos**: uma *exclusion constraint* impede duas marcações ativas sobrepostas para o mesmo profissional, mesmo com cliques ao mesmo segundo.
- **Marcações nunca se apagam**: mudam de estado (pendente → confirmada → concluída / cancelada / falta).
- **Ausências e marcações são privadas**: os clientes só veem as vagas livres (`vagas_disponiveis`).
- **Avaliações só de quem foi ao salão** (marcação concluída), no máximo uma por marcação.
- **Limites anti-abuso**: 5 marcações em aberto por cliente (2 por salão), marcações até 90 dias, 5 salões por proprietário, e limites de profissionais, serviços, horários e fotos. O proprietário não marca no próprio salão.
- **Contra robôs**: só contas com email confirmado fazem marcações; no máximo 3 marcações criadas por hora e 10 por dia (contando as canceladas); 3 faltas em 90 dias suspendem as marcações online.
- **Auditoria**: alterações a perfis, salões, serviços, profissionais, marcações e avaliações ficam registadas (quem, quando, antes e depois) em `privado.auditoria`, que o site não consegue ler. Para ver: Table Editor > schema `privado` > `auditoria`. Para apagar registos com mais de 1 ano (RGPD): `select privado.limpar_auditoria_antiga();`

## Mudanças futuras

Nunca alterar um ficheiro que já foi aplicado. Cria-se um novo em `migrations/`
com o número seguinte (ex.: `10_lista_de_espera.sql`), acrescenta-se
um teste em `testes/`, corre-se no **dev** e só depois no **prod**.

O número no início do nome serve só para garantir a **ordem** em que os ficheiros são corridos.
