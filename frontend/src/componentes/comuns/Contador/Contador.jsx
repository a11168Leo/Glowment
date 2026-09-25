import { useEffect, useState } from 'react'

/**
 * Número que "sobe" de 0 até o valor final.
 * iniciar: false para segurar a contagem até o momento certo.
 */
export default function Contador({ valor, duracao = 1600, iniciar = true }) {
  const [atual, setAtual] = useState(0)

  useEffect(() => {
    if (!iniciar || valor == null) return

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setAtual(valor)
      return
    }

    let quadro
    const inicio = performance.now()
    const passo = (agora) => {
      const progresso = Math.min((agora - inicio) / duracao, 1)
      const suave = 1 - Math.pow(1 - progresso, 3) // desacelera no final
      setAtual(Math.round(valor * suave))
      if (progresso < 1) quadro = requestAnimationFrame(passo)
    }
    quadro = requestAnimationFrame(passo)
    return () => cancelAnimationFrame(quadro)
  }, [valor, duracao, iniciar])

  return atual.toLocaleString('pt-PT')
}
