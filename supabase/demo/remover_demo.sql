-- =====================================================================
-- Glowment · Apagar os dados de demonstração
--
-- SQL Editor > New query > colar este ficheiro > Run.
-- Depois (opcional) apaga as 3 contas em Authentication > Users.
-- =====================================================================

do $$
declare
  v_contas uuid[] := array(
    select id from auth.users
    where email in ('salao@demo.glowment.pt', 'barbearia@demo.glowment.pt', 'cliente@demo.glowment.pt')
  );
begin
  -- 1. Marcações (e as avaliações delas) dos salões de demonstração ou do cliente de demonstração
  delete from public.marcacoes m
  using public.profissionais p, public.saloes s
  where p.id = m.profissional_id
    and s.id = p.salao_id
    and (s.proprietario_id = any (v_contas) or m.cliente_id = any (v_contas));

  -- 2. Salões (apaga também serviços, profissionais, horários e portfólio)
  delete from public.saloes where proprietario_id = any (v_contas);

  raise notice 'Dados de demonstração apagados.';
end;
$$;
