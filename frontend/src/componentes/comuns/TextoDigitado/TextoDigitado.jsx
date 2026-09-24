import { useEffect, useRef, useState } from 'react'
import estilos from './TextoDigitado.module.css'

/**
 * Mostra um texto como se estivesse sendo digitado.
 *
 * partes: lista de trechos, ex.: [{ texto: 'Olá, ' }, { texto: 'mundo', destaque: true }]
 *         (trechos com "destaque" são envolvidos em <em>)
 * como: tag usada (h1, p...)
 * velocidade: milissegundos por letra
 * atraso: espera antes de começar (ms)
 * iniciar: false para segurar a animação (útil para encadear textos)
 * aoTerminar: chamado quando a última letra aparece
 * manterCursor: deixa o cursor piscando depois de terminar
 *
 * O texto que ainda não apareceu fica invisível mas ocupando espaço,
 * assim a página não "pula" enquanto as letras surgem.
 */
export default function TextoDigitado({
  partes,
  como: Tag = 'p',
  velocidade = 45,
  atraso = 0,
  iniciar = true,
  aoTerminar,
  manterCursor = false,
  className = '',
}) {
  const total = partes.reduce((soma, parte) => soma + parte.texto.length, 0)
  const [digitados, setDigitados] = useState(0)
  const aoTerminarRef = useRef(aoTerminar)
  aoTerminarRef.current = aoTerminar

  useEffect(() => {
    if (!iniciar) return

    // Quem desativou animações no sistema vê o texto completo na hora
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setDigitados(total)
      return
    }

    let intervalo
    const espera = setTimeout(() => {
      intervalo = setInterval(() => {
        setDigitados((n) => Math.min(n + 1, total))
      }, velocidade)
    }, atraso)

    return () => {
      clearTimeout(espera)
      clearInterval(intervalo)
    }
  }, [iniciar, total, velocidade, atraso])

  const terminou = digitados >= total

  useEffect(() => {
    if (terminou) aoTerminarRef.current?.()
  }, [terminou])

  const mostrarCursor = iniciar && (!terminou || manterCursor)
  const textoCompleto = partes.map((parte) => parte.texto).join('')

  // Em qual trecho o cursor está agora (o primeiro que ainda não terminou)
  let indiceCursor = partes.length - 1
  let contagem = 0
  for (let i = 0; i < partes.length; i++) {
    contagem += partes[i].texto.length
    if (digitados < contagem) {
      indiceCursor = i
      break
    }
  }

  let restante = digitados

  return (
    <Tag className={className}>
      <span className={estilos.somenteLeitor}>{textoCompleto}</span>
      <span aria-hidden="true">
        {partes.map((parte, i) => {
          const visivel = parte.texto.slice(0, Math.max(0, restante))
          const oculto = parte.texto.slice(visivel.length)
          restante -= parte.texto.length

          const conteudo = (
            <>
              {visivel}
              {mostrarCursor && i === indiceCursor && (
                <span className={`${estilos.cursor} ${terminou ? estilos.piscando : ''}`} />
              )}
              <span className={estilos.oculto}>{oculto}</span>
            </>
          )

          return parte.destaque ? <em key={i}>{conteudo}</em> : <span key={i}>{conteudo}</span>
        })}
      </span>
    </Tag>
  )
}
