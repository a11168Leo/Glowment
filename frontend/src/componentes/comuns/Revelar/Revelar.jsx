import { useEffect, useRef, useState } from 'react'

/**
 * Envolve qualquer conteúdo para ele "surgir" quando aparecer na tela.
 * atraso: em milissegundos, útil para animar itens de uma lista em sequência.
 * A animação em si está em estilos/animacoes.css (.revelar).
 */
export default function Revelar({ children, atraso = 0, className = '' }) {
  const ref = useRef(null)
  const [visivel, setVisivel] = useState(false)

  useEffect(() => {
    const observador = new IntersectionObserver(
      ([entrada]) => {
        if (entrada.isIntersecting) {
          setVisivel(true)
          observador.disconnect()
        }
      },
      { threshold: 0.15 }
    )
    observador.observe(ref.current)
    return () => observador.disconnect()
  }, [])

  return (
    <div
      ref={ref}
      className={`revelar ${visivel ? 'revelar--visivel' : ''} ${className}`}
      style={{ transitionDelay: `${atraso}ms` }}
    >
      {children}
    </div>
  )
}
