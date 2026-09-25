-- =====================================================================
-- Glowment · Dados de demonstração (para testar o site e para a PAP)
--
-- ANTES DE CORRER, cria 3 contas no painel do Supabase:
--   Authentication > Users > Add user > Create new user
--   (marca "Auto Confirm User" e escolhe uma palavra-passe)
--     salao@demo.glowment.pt      → proprietária dos 3 salões
--     barbearia@demo.glowment.pt  → proprietário das 3 barbearias
--     cliente@demo.glowment.pt    → cliente com marcações e avaliações
--
-- Depois: SQL Editor > New query > colar este ficheiro > Run.
-- Para apagar tudo: demo/remover_demo.sql
-- =====================================================================

-- Cria um salão completo: serviços, profissionais (fazem todos os serviços)
-- e horário de terça a sábado, 09:00–13:00 e 14:00–19:00.
create or replace function pg_temp.criar_salao_demo(
  p_proprietario uuid, p_categoria public.categoria_salao,
  p_nome text, p_slug text, p_descricao text,
  p_morada text, p_codigo_postal text, p_cidade text,
  p_profissionais text[], p_servicos jsonb
) returns uuid
language plpgsql as $$
declare
  v_salao uuid;
  v_servico uuid;
  v_prof uuid;
  v_nome text;
  v_item jsonb;
  v_dia int;
begin
  insert into public.saloes (proprietario_id, categoria, nome, slug, descricao,
                             morada, codigo_postal, cidade, publicado)
  values (p_proprietario, p_categoria, p_nome, p_slug, p_descricao,
          p_morada, p_codigo_postal, p_cidade, true)
  returning id into v_salao;

  for v_item in select * from jsonb_array_elements(p_servicos) loop
    insert into public.servicos (salao_id, nome, duracao_min, preco_cents)
    values (v_salao, v_item ->> 'nome', (v_item ->> 'min')::int, (v_item ->> 'cents')::int);
  end loop;

  foreach v_nome in array p_profissionais loop
    insert into public.profissionais (salao_id, nome, especialidade)
    values (v_salao, v_nome,
            case p_categoria when 'barbearia' then 'Barbeiro' else 'Cabeleireira' end)
    returning id into v_prof;

    insert into public.profissional_servicos (profissional_id, servico_id)
    select v_prof, id from public.servicos where salao_id = v_salao;

    for v_dia in 2..6 loop  -- terça (2) a sábado (6)
      insert into public.horarios (profissional_id, dia_semana, hora_inicio, hora_fim) values
        (v_prof, v_dia, '09:00', '13:00'),
        (v_prof, v_dia, '14:00', '19:00');
    end loop;
  end loop;

  return v_salao;
end;
$$;

-- Regista uma marcação antiga, concluída e avaliada pelo cliente de demonstração
create or replace function pg_temp.avaliacao_demo(
  p_cliente uuid, p_salao uuid, p_dias_atras int, p_nota int, p_comentario text
) returns void
language plpgsql as $$
declare
  v_prof uuid;
  v_servico uuid;
  v_marcacao uuid;
begin
  select p.id, ps.servico_id into v_prof, v_servico
  from public.profissionais p
  join public.profissional_servicos ps on ps.profissional_id = p.id
  where p.salao_id = p_salao
  limit 1;

  insert into public.marcacoes (cliente_id, profissional_id, servico_id, inicio, estado, criado_em)
  values (p_cliente, v_prof, v_servico,
          date_trunc('day', now()) - make_interval(days => p_dias_atras) + interval '10 hours',
          'concluida',
          date_trunc('day', now()) - make_interval(days => p_dias_atras + 3))
  returning id into v_marcacao;

  insert into public.avaliacoes (marcacao_id, nota, comentario)
  values (v_marcacao, p_nota, p_comentario);
end;
$$;

do $$
declare
  v_salao_prop  uuid := (select id from auth.users where email = 'salao@demo.glowment.pt');
  v_barb_prop   uuid := (select id from auth.users where email = 'barbearia@demo.glowment.pt');
  v_cliente     uuid := (select id from auth.users where email = 'cliente@demo.glowment.pt');
  v_s1 uuid; v_s2 uuid; v_s3 uuid; v_b1 uuid; v_b2 uuid; v_b3 uuid;
begin
  if v_salao_prop is null or v_barb_prop is null or v_cliente is null then
    raise exception 'Cria primeiro as 3 contas de demonstração (ver o topo deste ficheiro)';
  end if;

  -- Contas criadas no painel ficam como "cliente": promover os proprietários
  update public.perfis set nome = 'Sofia Martins', tipo = 'proprietario' where id = v_salao_prop;
  update public.perfis set nome = 'Tiago Rocha',   tipo = 'proprietario' where id = v_barb_prop;
  update public.perfis set nome = 'Inês Carvalho'                        where id = v_cliente;

  -- ---------------- Salões ----------------
  v_s1 := pg_temp.criar_salao_demo(v_salao_prop, 'salao',
    'Studio Aurora', 'studio-aurora', 'Cortes, coloração e tratamentos capilares num espaço luminoso no centro de Lisboa.',
    'Rua Augusta 120', '1100-053', 'Lisboa', array['Sofia', 'Carla'],
    '[{"nome":"Corte e brushing","min":60,"cents":3500},
      {"nome":"Coloração","min":90,"cents":5500},
      {"nome":"Tratamento de hidratação","min":45,"cents":2500}]');

  v_s2 := pg_temp.criar_salao_demo(v_salao_prop, 'salao',
    'Maison Belle', 'maison-belle', 'Salão de beleza com serviços de cabelo, unhas e sobrancelhas.',
    'Rua de Santa Catarina 300', '4000-443', 'Porto', array['Beatriz'],
    '[{"nome":"Corte feminino","min":45,"cents":2800},
      {"nome":"Manicure","min":40,"cents":1500},
      {"nome":"Design de sobrancelhas","min":30,"cents":1200}]');

  v_s3 := pg_temp.criar_salao_demo(v_salao_prop, 'salao',
    'Espaço Lótus', 'espaco-lotus', 'Estética e bem-estar junto à universidade.',
    'Avenida Sá da Bandeira 50', '3000-350', 'Coimbra', array['Marta', 'Joana'],
    '[{"nome":"Limpeza de pele","min":60,"cents":4000},
      {"nome":"Depilação com cera","min":30,"cents":1800},
      {"nome":"Pedicure","min":45,"cents":2000}]');

  -- ---------------- Barbearias ----------------
  v_b1 := pg_temp.criar_salao_demo(v_barb_prop, 'barbearia',
    'Barbearia do Bairro', 'barbearia-do-bairro', 'Barbearia tradicional com toalha quente e navalha.',
    'Rua da Rosa 45', '1200-383', 'Lisboa', array['Tiago', 'Nuno'],
    '[{"nome":"Corte masculino","min":30,"cents":1400},
      {"nome":"Barba","min":20,"cents":1000},
      {"nome":"Corte e barba","min":45,"cents":2200}]');

  v_b2 := pg_temp.criar_salao_demo(v_barb_prop, 'barbearia',
    'Navalha Norte', 'navalha-norte', 'Degradês, desenhos e cuidados de barba no coração do Porto.',
    'Rua das Flores 80', '4050-265', 'Porto', array['Ricardo'],
    '[{"nome":"Corte degradê","min":40,"cents":1600},
      {"nome":"Barba com toalha quente","min":30,"cents":1200}]');

  v_b3 := pg_temp.criar_salao_demo(v_barb_prop, 'barbearia',
    'Clube do Bigode', 'clube-do-bigode', 'Barbearia moderna para estudantes e não só.',
    'Rua Ferreira Borges 20', '3000-179', 'Coimbra', array['André', 'Miguel'],
    '[{"nome":"Corte masculino","min":30,"cents":1200},
      {"nome":"Corte de criança","min":25,"cents":1000},
      {"nome":"Barba","min":20,"cents":800}]');

  -- ---------------- Avaliações (marcações antigas concluídas) ----------------
  perform pg_temp.avaliacao_demo(v_cliente, v_s1, 30, 5, 'Adorei o corte, voltarei de certeza!');
  perform pg_temp.avaliacao_demo(v_cliente, v_s1, 12, 4, 'Muito simpáticas, só esperei um pouco.');
  perform pg_temp.avaliacao_demo(v_cliente, v_s2, 20, 5, 'As melhores unhas do Porto.');
  perform pg_temp.avaliacao_demo(v_cliente, v_s3, 15, 4, 'Espaço muito calmo e limpo.');
  perform pg_temp.avaliacao_demo(v_cliente, v_b1, 25, 5, 'Corte impecável e ótimo ambiente.');
  perform pg_temp.avaliacao_demo(v_cliente, v_b1,  8, 5, 'O Tiago é um artista.');
  perform pg_temp.avaliacao_demo(v_cliente, v_b2, 18, 4, 'Bom degradê, preço justo.');
  perform pg_temp.avaliacao_demo(v_cliente, v_b3, 10, 3, 'Bom corte, mas estava muito cheio.');

  raise notice 'Dados de demonstração criados: 3 salões e 3 barbearias.';
end;
$$;
