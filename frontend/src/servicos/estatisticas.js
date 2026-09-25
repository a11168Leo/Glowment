import { supabase } from './supabase'

// Número de marcações feitas hoje (função "marcacoes_hoje" na base de dados).
// Sem ligação à base de dados, devolve 0 e o contador não aparece.
export async function buscarAgendamentosHoje() {
  if (!supabase) return 0

  const { data, error } = await supabase.rpc('marcacoes_hoje')

  if (error) {
    console.error('Erro ao buscar as marcações de hoje:', error.message)
    return 0
  }

  return data ?? 0
}
