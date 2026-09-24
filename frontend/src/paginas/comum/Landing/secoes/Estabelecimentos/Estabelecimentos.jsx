import { useEffect, useState } from 'react'
import Carrossel from '@/componentes/comuns/Carrossel/Carrossel'
import CartaoEstabelecimento from '@/componentes/comuns/CartaoEstabelecimento/CartaoEstabelecimento'
import Revelar from '@/componentes/comuns/Revelar/Revelar'
import { buscarSaloes, buscarBarbearias } from '@/servicos/estabelecimentos'
import estilos from './Estabelecimentos.module.css'

// Capas provisórias até termos fotos reais dos estabelecimentos
const capasSaloes = [
  'linear-gradient(135deg, #d9a88f, #946535)',
  'linear-gradient(135deg, #e8c7b8, #b07a5a)',
  'linear-gradient(135deg, #c99a8a, #7a4f3a)',
]

const capasBarbearias = [
  'linear-gradient(135deg, #4a4540, #1c1b1a)',
  'linear-gradient(135deg, #946535, #2b2420)',
  'linear-gradient(135deg, #6b635b, #1c1b1a)',
]

export default function Estabelecimentos() {
  const [saloes, setSaloes] = useState([])
  const [barbearias, setBarbearias] = useState([])

  useEffect(() => {
    buscarSaloes().then(setSaloes)
    buscarBarbearias().then(setBarbearias)
  }, [])

  // Sem nenhum estabelecimento cadastrado, a seção inteira não aparece
  if (saloes.length === 0 && barbearias.length === 0) return null

  return (
    <section className="secao">
      <div className={`container ${estilos.lista}`}>
        {saloes.length > 0 && (
          <Revelar>
            <Carrossel titulo="Salões de beleza" descricao="Os salões mais bem avaliados perto de você.">
              {saloes.map((salao, i) => (
                <CartaoEstabelecimento
                  key={salao.id}
                  estabelecimento={salao}
                  capa={capasSaloes[i % capasSaloes.length]}
                />
              ))}
            </Carrossel>
          </Revelar>
        )}

        {barbearias.length > 0 && (
          <Revelar>
            <Carrossel titulo="Barbearias" descricao="Corte e barba com quem entende do assunto.">
              {barbearias.map((barbearia, i) => (
                <CartaoEstabelecimento
                  key={barbearia.id}
                  estabelecimento={barbearia}
                  capa={capasBarbearias[i % capasBarbearias.length]}
                />
              ))}
            </Carrossel>
          </Revelar>
        )}
      </div>
    </section>
  )
}
