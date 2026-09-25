import { createClient } from '@supabase/supabase-js'

// As chaves vêm do arquivo frontend/.env (veja o .env.example).
const url = import.meta.env.VITE_SUPABASE_URL
const chave = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

// Enquanto o .env não estiver preenchido, o site funciona sem dados
// (as seções que dependem do banco simplesmente não aparecem).
export const supabase = url && chave ? createClient(url, chave) : null

if (!supabase) {
  console.warn('Supabase não configurado: preencha frontend/.env para carregar os dados.')
}
