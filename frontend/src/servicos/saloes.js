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

  return data.map((salao) => ({
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
    servicos: salao.servicos.slice(0, 3).map((servico) => servico.nome),
  }))
}

export function buscarSaloes() {
  return buscarPorCategoria('salao')
}

export function buscarBarbearias() {
  return buscarPorCategoria('barbearia')
}
