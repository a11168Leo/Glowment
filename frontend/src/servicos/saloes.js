import { supabase } from './supabase'

// Busca os estabelecimentos publicados de uma categoria ('salao' ou 'barbearia'),
// os mais bem avaliados primeiro.
// Sem ligação à base de dados, ou sem registos, devolve [] (a secção fica escondida).
async function buscarPorCategoria(categoria) {
  if (!supabase) return []

  const { data, error } = await supabase
    .from('saloes')
    .select('id, nome, slug, cidade, nota_media, total_avaliacoes, capa_path, servicos(nome)')
    .eq('categoria', categoria)
    .eq('publicado', true)
    .eq('servicos.ativo', true)
    .order('nota_media', { ascending: false, nullsFirst: false })
    .limit(12)

  if (error) {
    console.error(`Erro ao buscar estabelecimentos (${categoria}):`, error.message)
    return []
  }

  return data.map((salao) =>
    paraCartao({ ...salao, servicos: salao.servicos.map((servico) => servico.nome) }),
  )
}

// Converte uma linha da base de dados no formato que o CartaoEstabelecimento usa
function paraCartao(salao) {
  return {
    id: salao.id,
    nome: salao.nome,
    slug: salao.slug,
    bairro: salao.cidade,
    nota: salao.nota_media != null ? Number(salao.nota_media) : null,
    avaliacoes: salao.total_avaliacoes,
    // A foto de capa fica no Supabase Storage (bucket "saloes"); sem foto, o cartão usa um fundo
    foto: salao.capa_path
      ? supabase.storage.from('saloes').getPublicUrl(salao.capa_path).data.publicUrl
      : null,
    servicos: (salao.servicos ?? []).slice(0, 3),
  }
}

/**
 * Pesquisa salões e barbearias (função "pesquisar_saloes" na base de dados).
 * Ignora acentos e maiúsculas e tolera erros de escrita ("barbaria" → Barbearia).
 *
 * Todos os campos são opcionais:
 *   texto            → nome do salão, cidade ou serviço ("aurora", "corte", "unhas")
 *   local            → cidade ("lisboa")
 *   categoria        → 'salao' ou 'barbearia'
 *   categoriaServico → 'cabelo', 'barba', 'unhas', 'sobrancelhas', 'estetica',
 *                      'maquilhagem', 'depilacao', 'massagem' ou 'outro'
 *
 * Exemplo: pesquisarSaloes({ texto: 'corte', local: 'porto' })
 */
export async function pesquisarSaloes({ texto, local, categoria, categoriaServico } = {}) {
  if (!supabase) return []

  const { data, error } = await supabase.rpc('pesquisar_saloes', {
    p_texto: texto || null,
    p_local: local || null,
    p_categoria: categoria || null,
    p_categoria_servico: categoriaServico || null,
    p_limite: 20,
  })

  if (error) {
    console.error('Erro na pesquisa:', error.message)
    return []
  }

  return data.map(paraCartao)
}

export function buscarSaloes() {
  return buscarPorCategoria('salao')
}

export function buscarBarbearias() {
  return buscarPorCategoria('barbearia')
}
