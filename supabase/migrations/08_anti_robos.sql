-- =====================================================================
-- Glowment · Ficheiro 8: barreiras contra robôs e marcações em massa
--
-- Substitui a função "limitar_marcacoes" do ficheiro 7 por uma versão
-- mais completa. Antes de aceitar uma marcação, a base de dados verifica,
-- por esta ordem:
--   1. o email da conta está confirmado     (robôs usam emails falsos)
--   2. o cliente não tem 3 faltas recentes  (quem marca e não aparece)
--   3. o ritmo: máx. 3 marcações por hora e 10 por dia
--      (conta também as canceladas: impede "marcar e cancelar" em série)
--   4. o proprietário não marca no próprio salão
--   5. só até 90 dias de antecedência
--   6. máx. 5 marcações em aberto no total e 2 no mesmo salão
-- =====================================================================

create or replace function privado.limitar_marcacoes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cliente uuid := auth.uid();                                   -- quem está a marcar
  v_salao   uuid := privado.salao_do_profissional(new.profissional_id);
begin
  -- Administrador (painel do Supabase, sem sessão): sem limites
  if v_cliente is null then
    return new;
  end if;

  -- Trata uma marcação de cada vez por cliente: vários pedidos enviados
  -- ao mesmo segundo não conseguem contornar os limites
  perform pg_advisory_xact_lock(hashtext(v_cliente::text));

  -- 1. Email confirmado
  if not exists (
    select 1 from auth.users
    where id = v_cliente and email_confirmed_at is not null
  ) then
    raise exception 'Confirme o seu email antes de fazer marcações';
  end if;

  -- 2. Faltas: 3 ou mais nos últimos 90 dias suspendem as marcações online
  if (select count(*) from public.marcacoes
      where cliente_id = v_cliente
        and estado = 'falta'
        and inicio > now() - interval '90 days') >= 3 then
    raise exception 'Marcações online suspensas: 3 faltas nos últimos 90 dias. Contacte o salão.';
  end if;

  -- 3. Ritmo: marcações CRIADAS na última hora e nas últimas 24 horas
  if (select count(*) from public.marcacoes
      where cliente_id = v_cliente
        and criado_em > now() - interval '1 hour') >= 3 then
    raise exception 'Demasiadas marcações seguidas. Tente novamente daqui a uma hora.';
  end if;

  if (select count(*) from public.marcacoes
      where cliente_id = v_cliente
        and criado_em > now() - interval '24 hours') >= 10 then
    raise exception 'Atingiu o limite de marcações de hoje.';
  end if;

  -- 4. O proprietário não marca no próprio salão
  if privado.e_proprietario_do_salao(v_salao) then
    raise exception 'Não é possível marcar no próprio salão';
  end if;

  -- 5. Até 90 dias de antecedência
  if new.inicio > now() + interval '90 days' then
    raise exception 'Só é possível marcar até 90 dias de antecedência';
  end if;

  -- 6. Marcações em aberto (pendentes ou confirmadas, no futuro)
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

-- Índice para as contagens acima serem rápidas mesmo com muitas marcações
create index if not exists marcacoes_cliente_criado_idx on public.marcacoes (cliente_id, criado_em desc);
