-- =====================================================================
-- Glowment · Testes automáticos da base de dados
--
-- COMO CORRER: Supabase > SQL Editor > New query > colar este ficheiro > Run
--
-- O teste cria utilizadores, salões e marcações falsos, tenta "atacar" as
-- regras de segurança e da agenda, e no fim DESFAZ TUDO.
--
-- O resultado aparece como uma mensagem de ERRO DE PROPÓSITO:
-- é assim que o PostgreSQL desfaz tudo o que o teste criou.
-- Lê a mensagem: diz quantos testes passaram e quais falharam.
-- =====================================================================

do $$
declare
  -- Utilizadores de teste
  v_prop   uuid := 'a0000000-0000-4000-8000-000000000001';  -- proprietário (João)
  v_prop2  uuid := 'a0000000-0000-4000-8000-000000000002';  -- outro proprietário (Marta)
  v_ana    uuid := 'a0000000-0000-4000-8000-000000000003';  -- cliente
  v_rui    uuid := 'a0000000-0000-4000-8000-000000000004';  -- cliente
  v_esperto uuid := 'a0000000-0000-4000-8000-000000000005'; -- tenta registar-se como admin

  v_salao uuid; v_salao_oculto uuid; v_servico uuid; v_prof uuid;
  v_marcacao uuid; v_marcacao_antiga uuid;
  v_seg date;          -- próxima segunda-feira
  v_n int; v_txt text; v_num numeric;

  v_ok int := 0;
  v_falhas text[] := '{}';
begin
  -- Próxima segunda-feira (hora de Portugal)
  v_seg := (now() at time zone 'Europe/Lisbon')::date
           + (8 - extract(isodow from (now() at time zone 'Europe/Lisbon')))::int;

  -- ================================================================
  -- T1 · O registo cria o perfil automaticamente (ninguém se regista como admin)
  -- ================================================================
  insert into auth.users (id, email, raw_user_meta_data) values
    (v_prop,    'teste-joao@glowment.test',  '{"nome":"João","tipo":"proprietario"}'),
    (v_prop2,   'teste-marta@glowment.test', '{"nome":"Marta","tipo":"proprietario"}'),
    (v_ana,     'teste-ana@glowment.test',   '{"nome":"Ana"}'),
    (v_rui,     'teste-rui@glowment.test',   '{"nome":"Rui"}'),
    (v_esperto, 'teste-esperto@glowment.test','{"nome":"Esperto","tipo":"admin"}');

  if (select tipo from public.perfis where id = v_prop) = 'proprietario'
     and (select tipo from public.perfis where id = v_ana) = 'cliente'
     and (select tipo from public.perfis where id = v_esperto) = 'cliente' then
    v_ok := v_ok + 1;
  else
    v_falhas := v_falhas || 'T1: os perfis não foram criados com o tipo certo'::text;
  end if;

  -- A partir daqui, "entramos" como utilizadores do site
  perform set_config('role', 'authenticated', true);

  -- ================================================================
  -- T2 · Um cliente não consegue tornar-se admin
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_esperto::text, true);
  begin
    update public.perfis set tipo = 'admin' where id = v_esperto;
    v_falhas := v_falhas || 'T2: um cliente conseguiu mudar o próprio tipo'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T3 · Um cliente não consegue criar salões
  -- ================================================================
  begin
    insert into public.saloes (nome, slug, morada, codigo_postal, cidade)
    values ('Salão Falso', 'teste-falso', 'Rua X', '2495-000', 'Fátima');
    v_falhas := v_falhas || 'T3: um cliente conseguiu criar um salão'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T4 · O proprietário monta o salão (serviço, profissional, horário)
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_prop::text, true);
  begin
    insert into public.saloes (nome, categoria, slug, morada, codigo_postal, cidade, publicado)
    values ('Barbearia Teste', 'barbearia', 'teste-barbearia', 'Rua Principal 1', '2495-000', 'Fátima', true)
    returning id into v_salao;

    insert into public.saloes (nome, slug, morada, codigo_postal, cidade)
    values ('Salão Por Publicar', 'teste-oculto', 'Rua 2', '2495-000', 'Fátima')
    returning id into v_salao_oculto;

    insert into public.servicos (salao_id, nome, duracao_min, preco_cents)
    values (v_salao, 'Corte masculino', 30, 1200) returning id into v_servico;

    insert into public.profissionais (salao_id, nome, especialidade)
    values (v_salao, 'João', 'Barbeiro') returning id into v_prof;

    insert into public.profissional_servicos (profissional_id, servico_id) values (v_prof, v_servico);

    -- Segunda-feira: 09:00–13:00 e 14:00–19:00 (pausa de almoço)
    insert into public.horarios (profissional_id, dia_semana, hora_inicio, hora_fim) values
      (v_prof, 1, '09:00', '13:00'),
      (v_prof, 1, '14:00', '19:00');

    v_ok := v_ok + 1;
  exception when others then
    v_falhas := v_falhas || ('T4: o proprietário não conseguiu montar o salão: ' || sqlerrm);
  end;

  -- ================================================================
  -- T5 · Horários sobrepostos são recusados (12:00–15:00 choca com 09–13)
  -- ================================================================
  begin
    insert into public.horarios (profissional_id, dia_semana, hora_inicio, hora_fim)
    values (v_prof, 1, '12:00', '15:00');
    v_falhas := v_falhas || 'T5: aceitou um horário sobreposto'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T6 · Outro proprietário não mexe no salão do João
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_prop2::text, true);
  update public.saloes set nome = 'Roubado' where id = v_salao;
  get diagnostics v_n = row_count;
  if v_n = 0 then v_ok := v_ok + 1;
  else v_falhas := v_falhas || 'T6: outro proprietário alterou o salão'::text; end if;

  -- ================================================================
  -- T7 · Um visitante (sem conta) vê o salão publicado, mas não o oculto
  -- ================================================================
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claim.sub', '', true);
  select count(*) into v_n from public.saloes where id in (v_salao, v_salao_oculto);
  if v_n = 1 then v_ok := v_ok + 1;
  else v_falhas := v_falhas || ('T7: o visitante vê ' || v_n || ' salões (devia ver 1)'); end if;

  -- ================================================================
  -- T8 · O visitante vê as vagas livres (a primeira é às 09:00)
  -- ================================================================
  select to_char(min(inicio) at time zone 'Europe/Lisbon', 'HH24:MI') into v_txt
  from public.vagas_disponiveis(v_prof, v_servico, v_seg);
  if v_txt = '09:00' then v_ok := v_ok + 1;
  else v_falhas := v_falhas || ('T8: primeira vaga = ' || coalesce(v_txt, 'nenhuma') || ' (esperado 09:00)'); end if;

  -- ================================================================
  -- T9 · O visitante NÃO consegue ver marcações
  -- ================================================================
  begin
    perform 1 from public.marcacoes;
    v_falhas := v_falhas || 'T9: o visitante conseguiu ler marcações'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  perform set_config('role', 'authenticated', true);

  -- ================================================================
  -- T10 · A Ana marca às 10:00 — a base de dados calcula o fim e o preço
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_ana::text, true);
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, (v_seg + time '10:00') at time zone 'Europe/Lisbon')
    returning id into v_marcacao;

    select to_char(fim at time zone 'Europe/Lisbon', 'HH24:MI') || '|' || preco_cents || '|' || estado
      into v_txt from public.marcacoes where id = v_marcacao;
    if v_txt = '10:30|1200|pendente' then v_ok := v_ok + 1;
    else v_falhas := v_falhas || ('T10: valores errados: ' || v_txt); end if;
  exception when others then
    v_falhas := v_falhas || ('T10: a Ana não conseguiu marcar: ' || sqlerrm);
  end;

  -- ================================================================
  -- T11 · CONFLITO: o Rui tenta as 10:00 com o mesmo profissional
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_rui::text, true);
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, (v_seg + time '10:00') at time zone 'Europe/Lisbon');
    v_falhas := v_falhas || 'T11: aceitou duas marcações às 10:00'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T12 · CONFLITO: o Rui tenta as 10:15 (sobrepõe 10:00–10:30)
  -- ================================================================
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, (v_seg + time '10:15') at time zone 'Europe/Lisbon');
    v_falhas := v_falhas || 'T12: aceitou uma marcação sobreposta às 10:15'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T13 · O Rui marca às 10:30 (encosta, não sobrepõe) — deve funcionar
  -- ================================================================
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, (v_seg + time '10:30') at time zone 'Europe/Lisbon');
    v_ok := v_ok + 1;
  exception when others then
    v_falhas := v_falhas || ('T13: recusou as 10:30: ' || sqlerrm);
  end;

  -- ================================================================
  -- T14 · Marcação que acabaria na pausa de almoço (12:45–13:15)
  -- ================================================================
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, (v_seg + time '12:45') at time zone 'Europe/Lisbon');
    v_falhas := v_falhas || 'T14: aceitou uma marcação na pausa de almoço'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T15 · Marcação no passado
  -- ================================================================
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, now() - interval '1 day');
    v_falhas := v_falhas || 'T15: aceitou uma marcação no passado'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T16 · Tentar escolher o próprio preço (0 €)
  -- ================================================================
  begin
    insert into public.marcacoes (profissional_id, servico_id, inicio, preco_cents)
    values (v_prof, v_servico, (v_seg + time '15:00') at time zone 'Europe/Lisbon', 0);
    v_falhas := v_falhas || 'T16: o cliente conseguiu escolher o preço'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T17 · Privacidade: o Rui só vê as suas marcações
  -- ================================================================
  select count(*) into v_n from public.marcacoes;
  if v_n = 1 then v_ok := v_ok + 1;
  else v_falhas := v_falhas || ('T17: o Rui vê ' || v_n || ' marcações (devia ver 1)'); end if;

  -- ================================================================
  -- T18 · O proprietário vê as marcações do salão e o nome dos clientes
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_prop::text, true);
  select string_agg(p.nome, ',' order by m.inicio) into v_txt
  from public.marcacoes m join public.perfis p on p.id = m.cliente_id;
  if v_txt = 'Ana,Rui' then v_ok := v_ok + 1;
  else v_falhas := v_falhas || ('T18: o proprietário vê: ' || coalesce(v_txt, 'nada')); end if;

  -- ================================================================
  -- T19 · As vagas ocupadas desaparecem da lista (09:45, 10:00, 10:15, 10:30)
  -- ================================================================
  select count(*) into v_n
  from public.vagas_disponiveis(v_prof, v_servico, v_seg)
  where to_char(inicio at time zone 'Europe/Lisbon', 'HH24:MI') in ('09:45', '10:00', '10:15', '10:30', '10:45');
  if v_n = 0 then v_ok := v_ok + 1;
  else v_falhas := v_falhas || ('T19: ainda aparecem ' || v_n || ' vagas ocupadas'); end if;

  -- ================================================================
  -- T20 · A cliente não pode marcar a própria marcação como "concluída"
  -- ================================================================
  perform set_config('request.jwt.claim.sub', v_ana::text, true);
  begin
    update public.marcacoes set estado = 'concluida' where id = v_marcacao;
    v_falhas := v_falhas || 'T20: a cliente marcou como concluída'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T21 · A Ana cancela e o Rui fica com as 10:00
  -- ================================================================
  begin
    update public.marcacoes set estado = 'cancelada' where id = v_marcacao;
    perform set_config('request.jwt.claim.sub', v_rui::text, true);
    insert into public.marcacoes (profissional_id, servico_id, inicio)
    values (v_prof, v_servico, (v_seg + time '10:00') at time zone 'Europe/Lisbon');
    v_ok := v_ok + 1;
  exception when others then
    v_falhas := v_falhas || ('T21: ' || sqlerrm);
  end;

  -- ================================================================
  -- T22 · Não se avalia uma marcação que ainda não foi concluída
  -- ================================================================
  begin
    insert into public.avaliacoes (marcacao_id, nota)
    select id, 5 from public.marcacoes where estado = 'pendente' limit 1;
    v_falhas := v_falhas || 'T22: aceitou avaliar uma marcação não concluída'::text;
  exception when others then v_ok := v_ok + 1;
  end;

  -- ================================================================
  -- T23 · Avaliação de uma marcação concluída atualiza a nota do salão
  -- ================================================================
  -- O "administrador" (sem sessão) regista uma marcação antiga já concluída
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claim.sub', '', true);
  insert into public.marcacoes (cliente_id, profissional_id, servico_id, inicio, estado)
  values (v_ana, v_prof, v_servico, now() - interval '7 days', 'concluida')
  returning id into v_marcacao_antiga;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', v_ana::text, true);
  begin
    insert into public.avaliacoes (marcacao_id, nota, comentario)
    values (v_marcacao_antiga, 5, 'Excelente!');

    select nota_media into v_num from public.saloes where id = v_salao;
    if v_num = 5.0 then v_ok := v_ok + 1;
    else v_falhas := v_falhas || ('T23: nota média = ' || coalesce(v_num::text, 'vazia')); end if;
  exception when others then
    v_falhas := v_falhas || ('T23: ' || sqlerrm);
  end;

  -- ================================================================
  -- T24 · Contador da página inicial
  -- ================================================================
  select public.marcacoes_hoje() into v_n;
  if v_n >= 2 then v_ok := v_ok + 1;
  else v_falhas := v_falhas || ('T24: marcacoes_hoje = ' || v_n); end if;

  -- ================================================================
  -- RESULTADO (e desfazer tudo)
  -- ================================================================
  perform set_config('role', 'none', true);

  if array_length(v_falhas, 1) is null then
    raise exception E'✅ TODOS OS TESTES PASSARAM (%/24)\n(Esta mensagem aparece como erro de propósito: assim nada do teste fica gravado.)', v_ok;
  else
    raise exception E'❌ % teste(s) falharam, % passaram:\n%\n(Nada do teste ficou gravado.)',
      array_length(v_falhas, 1), v_ok, array_to_string(v_falhas, E'\n');
  end if;
end;
$$;
