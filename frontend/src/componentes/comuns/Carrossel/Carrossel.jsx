import { Children, useEffect, useRef, useState } from 'react'
import { IconeSetaEsquerda, IconeSetaDireita } from '@/recursos/icones/Icones'
import estilos from './Carrossel.module.css'

/**
 * Carrossel horizontal.
 * - Computador: setas para avançar/voltar (ou arrastar no touchpad)
 * - Celular: deslizar com o dedo (as setas somem)
 * Cada filho vira um item do carrossel.
 */
export default function Carrossel({ titulo, descricao, children }) {
  const trilhoRef = useRef(null)
  const [podeVoltar, setPodeVoltar] = useState(false)
  const [podeAvancar, setPodeAvancar] = useState(false)
  const quantidade = Children.count(children)

  const atualizarSetas = () => {
    const trilho = trilhoRef.current
    setPodeVoltar(trilho.scrollLeft > 4)
    setPodeAvancar(trilho.scrollLeft + trilho.clientWidth < trilho.scrollWidth - 4)
  }

  useEffect(() => {
    atualizarSetas()
    window.addEventListener('resize', atualizarSetas)
    return () => window.removeEventListener('resize', atualizarSetas)
  }, [quantidade])

  const rolar = (direcao) => {
    const trilho = trilhoRef.current
    trilho.scrollBy({ left: direcao * trilho.clientWidth * 0.9, behavior: 'smooth' })
  }

  return (
    <div>
      <div className={estilos.topo}>
        <div>
          <h2>{titulo}</h2>
          {descricao && <p>{descricao}</p>}
        </div>

        <div className={estilos.setas}>
          <button className={estilos.seta} onClick={() => rolar(-1)} disabled={!podeVoltar} aria-label="Anterior">
            <IconeSetaEsquerda />
          </button>
          <button className={estilos.seta} onClick={() => rolar(1)} disabled={!podeAvancar} aria-label="Próximo">
            <IconeSetaDireita />
          </button>
        </div>
      </div>

      <div className={estilos.trilho} ref={trilhoRef} onScroll={atualizarSetas}>
        {children}
      </div>
    </div>
  )
}
