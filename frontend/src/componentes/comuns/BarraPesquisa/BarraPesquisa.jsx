import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { IconePesquisa, IconeLocalizacao, IconeCalendario } from '@/recursos/icones/Icones'
import estilos from './BarraPesquisa.module.css'

/**
 * Barra de pesquisa em duas camadas:
 * - .moldura (fundo): só faz a transição de cores
 * - .barra (frente): os três campos + o botão "Pesquisar"
 */
export default function BarraPesquisa() {
  const navegar = useNavigate()
  const [busca, setBusca] = useState({ servico: '', local: '', horario: '' })

  const alterar = (campo) => (e) => setBusca({ ...busca, [campo]: e.target.value })

  const pesquisar = (e) => {
    e.preventDefault()
    // Por enquanto só leva para a área do cliente com os filtros na URL.
    // Quando o backend existir, é aqui que a busca vai ser feita.
    const filtros = new URLSearchParams(Object.entries(busca).filter(([, valor]) => valor))
    navegar(`/cliente?${filtros}`)
  }

  return (
    <div className={estilos.moldura}>
      <form className={estilos.barra} onSubmit={pesquisar} role="search">
        <label className={estilos.campo}>
          <IconePesquisa />
          <input
            type="text"
            placeholder="Tratamento ou produtos"
            aria-label="Tratamento ou produtos"
            value={busca.servico}
            onChange={alterar('servico')}
          />
        </label>

        <label className={estilos.campo}>
          <IconeLocalizacao />
          <input
            type="text"
            placeholder="Localização atual"
            aria-label="Localização"
            value={busca.local}
            onChange={alterar('local')}
          />
        </label>

        <label className={estilos.campo}>
          <IconeCalendario />
          <input
            type="text"
            placeholder="Horário"
            aria-label="Horário"
            value={busca.horario}
            onChange={alterar('horario')}
          />
        </label>

        <button type="submit" className={estilos.botao}>
          Pesquisar
        </button>
      </form>
    </div>
  )
}
