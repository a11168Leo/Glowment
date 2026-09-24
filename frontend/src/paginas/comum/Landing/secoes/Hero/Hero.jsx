import { useEffect, useState } from 'react'
import TextoDigitado from '@/componentes/comuns/TextoDigitado/TextoDigitado'
import BarraPesquisa from '@/componentes/comuns/BarraPesquisa/BarraPesquisa'
import FundoInterativo from '@/componentes/comuns/FundoInterativo/FundoInterativo'
import Contador from '@/componentes/comuns/Contador/Contador'
import { buscarAgendamentosHoje } from '@/servicos/estatisticas'
import estilos from './Hero.module.css'

const titulo = [
  { texto: 'A sua rotina de beleza e cuidado, ' },
  { texto: 'num só lugar.', destaque: true },
]

const subtitulo = [
  {
    texto:
      'Encontre especialistas em cabelo, barba e estética. Reserve o seu horário e compre os seus produtos favoritos num só clique.',
  },
]

export default function Hero() {
  // O subtítulo e a barra de pesquisa só aparecem quando o título termina
  const [tituloPronto, setTituloPronto] = useState(false)
  const [agendamentosHoje, setAgendamentosHoje] = useState(null)

  useEffect(() => {
    buscarAgendamentosHoje().then(setAgendamentosHoje)
  }, [])

  return (
    <section className={estilos.hero}>
      <FundoInterativo />

      <div className={`container ${estilos.texto}`}>
        <TextoDigitado
          como="h1"
          partes={titulo}
          velocidade={55}
          atraso={400}
          aoTerminar={() => setTituloPronto(true)}
        />
        <TextoDigitado
          como="p"
          partes={subtitulo}
          velocidade={22}
          atraso={250}
          iniciar={tituloPronto}
          manterCursor
        />

        <div className={`${estilos.pesquisa} ${tituloPronto ? estilos.pesquisaVisivel : ''}`}>
          <BarraPesquisa />

          {/* Só aparece se houver agendamentos hoje */}
          {agendamentosHoje > 0 && (
            <p className={estilos.agendamentos}>
              <span className={estilos.aoVivo} aria-hidden="true" />
              <strong>
                <Contador valor={agendamentosHoje} iniciar={tituloPronto} />
              </strong>
              <span className={estilos.legenda}>agendamentos feitos hoje</span>
            </p>
          )}
        </div>
      </div>
    </section>
  )
}
