import { useEffect, useRef } from 'react'
import estilos from './FundoInterativo.module.css'

/**
 * Fundo animado com uma grade de pontos.
 * - Computador (mouse): um brilho segue o cursor e os pontos próximos
 *   acendem e se afastam dele.
 * - Celular (toque): uma onda de luz atravessa os pontos sozinha.
 * - Nos dois: clicar/tocar cria uma onda que se espalha a partir do ponto.
 * Coloque dentro de um elemento com "position: relative".
 */

const ESPACO = 30 // distância entre os pontos (px)
const RAIO_MOUSE = 170 // alcance do cursor (px)
const DURACAO_ONDA = 1200 // ms

// Converte a cor de uma variável CSS (#rrggbb) para "r, g, b"
function corDaVariavel(nome) {
  const hex = getComputedStyle(document.documentElement).getPropertyValue(nome).trim()
  if (!/^#[0-9a-f]{6}$/i.test(hex)) return '148, 101, 53'
  return [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(', ')
}

export default function FundoInterativo() {
  const canvasRef = useRef(null)

  useEffect(() => {
    const canvas = canvasRef.current
    const ctx = canvas.getContext('2d')
    const ehToque = window.matchMedia('(pointer: coarse)').matches
    const semAnimacao = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const cor = corDaVariavel('--cor-primaria')

    let largura = 0
    let altura = 0
    let pontos = []
    let ondas = []
    let visivel = true
    let quadro
    const mouse = { x: 0, y: 0, suaveX: 0, suaveY: 0, dentro: false, intensidade: 0 }

    const desenhar = (tempo) => {
      ctx.clearRect(0, 0, largura, altura)

      // O brilho segue o cursor com um pequeno atraso (fica mais suave)
      mouse.suaveX += (mouse.x - mouse.suaveX) * 0.12
      mouse.suaveY += (mouse.y - mouse.suaveY) * 0.12
      mouse.intensidade += ((mouse.dentro ? 1 : 0) - mouse.intensidade) * 0.08

      if (!ehToque && mouse.intensidade > 0.01) {
        const brilho = ctx.createRadialGradient(mouse.suaveX, mouse.suaveY, 0, mouse.suaveX, mouse.suaveY, 320)
        brilho.addColorStop(0, `rgba(${cor}, ${0.14 * mouse.intensidade})`)
        brilho.addColorStop(1, `rgba(${cor}, 0)`)
        ctx.fillStyle = brilho
        ctx.fillRect(0, 0, largura, altura)
      }

      ondas = ondas.filter((onda) => tempo - onda.inicio < DURACAO_ONDA)

      for (const ponto of pontos) {
        let forca = 0
        let dx = 0
        let dy = 0

        if (ehToque) {
          // Onda diagonal automática
          const fase = (ponto.x + ponto.y) * 0.01 - tempo * 0.0012
          forca = Math.max(0, Math.sin(fase)) ** 8 * 0.6
        } else if (mouse.intensidade > 0.01) {
          const distX = ponto.x - mouse.suaveX
          const distY = ponto.y - mouse.suaveY
          const distancia = Math.hypot(distX, distY)
          if (distancia < RAIO_MOUSE) {
            const perto = 1 - distancia / RAIO_MOUSE
            const empurrao = perto * perto * 12 * mouse.intensidade
            forca = perto * mouse.intensidade
            dx = (distX / (distancia || 1)) * empurrao
            dy = (distY / (distancia || 1)) * empurrao
          }
        }

        for (const onda of ondas) {
          const progresso = (tempo - onda.inicio) / DURACAO_ONDA
          const distancia = Math.hypot(ponto.x - onda.x, ponto.y - onda.y)
          const naBorda = 1 - Math.abs(distancia - progresso * 500) / 45
          if (naBorda > 0) forca = Math.max(forca, naBorda * (1 - progresso))
        }

        ctx.fillStyle = `rgba(${cor}, ${0.14 + forca * 0.66})`
        ctx.beginPath()
        ctx.arc(ponto.x + dx, ponto.y + dy, 1.2 + forca * 2, 0, Math.PI * 2)
        ctx.fill()
      }
    }

    const redimensionar = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      largura = canvas.clientWidth
      altura = canvas.clientHeight
      canvas.width = largura * dpr
      canvas.height = altura * dpr
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

      pontos = []
      for (let y = ESPACO / 2; y < altura; y += ESPACO) {
        for (let x = ESPACO / 2; x < largura; x += ESPACO) pontos.push({ x, y })
      }
      if (semAnimacao) desenhar(0)
    }

    const posicaoRelativa = (e) => {
      const area = canvas.getBoundingClientRect()
      const x = e.clientX - area.left
      const y = e.clientY - area.top
      return { x, y, dentro: x >= 0 && y >= 0 && x <= area.width && y <= area.height }
    }

    const aoMover = (e) => {
      const { x, y, dentro } = posicaoRelativa(e)
      if (mouse.intensidade < 0.01) {
        mouse.suaveX = x
        mouse.suaveY = y
      }
      Object.assign(mouse, { x, y, dentro })
    }

    const aoSair = () => {
      mouse.dentro = false
    }

    const aoTocar = (e) => {
      const { x, y, dentro } = posicaoRelativa(e)
      if (dentro) ondas.push({ x, y, inicio: performance.now() })
    }

    const loop = (tempo) => {
      if (visivel && !document.hidden) desenhar(tempo)
      quadro = requestAnimationFrame(loop)
    }

    const observadorTamanho = new ResizeObserver(redimensionar)
    observadorTamanho.observe(canvas)

    // Pausa a animação quando o fundo sai da tela (economiza bateria)
    const observadorVisibilidade = new IntersectionObserver(([entrada]) => {
      visivel = entrada.isIntersecting
    })
    observadorVisibilidade.observe(canvas)

    if (!semAnimacao) {
      if (!ehToque) {
        window.addEventListener('pointermove', aoMover)
        document.documentElement.addEventListener('mouseleave', aoSair)
      }
      window.addEventListener('pointerdown', aoTocar)
      quadro = requestAnimationFrame(loop)
    }

    return () => {
      cancelAnimationFrame(quadro)
      observadorTamanho.disconnect()
      observadorVisibilidade.disconnect()
      window.removeEventListener('pointermove', aoMover)
      document.documentElement.removeEventListener('mouseleave', aoSair)
      window.removeEventListener('pointerdown', aoTocar)
    }
  }, [])

  return <canvas ref={canvasRef} className={estilos.fundo} aria-hidden="true" />
}
