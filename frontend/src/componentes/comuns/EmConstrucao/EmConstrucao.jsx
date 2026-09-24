import Botao from '@/componentes/comuns/Botao/Botao'
import estilos from './EmConstrucao.module.css'

// Página provisória enquanto uma área ainda não foi feita
export default function EmConstrucao({ titulo, descricao }) {
  return (
    <main className={estilos.pagina}>
      <div className="animar-aparecer">
        <span className={estilos.selo}>Em construção</span>
        <h1>{titulo}</h1>
        <p>{descricao}</p>
        <Botao para="/" variante="secundario">
          Voltar ao início
        </Botao>
      </div>
    </main>
  )
}
