import { Link } from 'react-router-dom'
import estilos from './CartaoProduto.module.css'

const formatarPreco = (valor) =>
  valor.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

/**
 * Cartão de um produto da loja.
 * capa: fundo da imagem (cor/gradiente) até termos fotos reais.
 */
export default function CartaoProduto({ produto, capa, className = '', style }) {
  const { nome, vendidoPor, categoria, preco, precoAntigo } = produto
  const desconto = precoAntigo ? Math.round((1 - preco / precoAntigo) * 100) : 0

  return (
    <article className={`${estilos.cartao} ${className}`} style={style}>
      <div className={estilos.imagem} style={{ background: capa }}>
        <span className={estilos.categoria}>{categoria}</span>
        {desconto > 0 && <span className={estilos.desconto}>-{desconto}%</span>}
      </div>

      <div className={estilos.info}>
        <small className={estilos.vendidoPor}>{vendidoPor}</small>
        <h3>{nome}</h3>

        <div className={estilos.rodape}>
          <div className={estilos.precos}>
            {precoAntigo && <s>{formatarPreco(precoAntigo)}</s>}
            <strong>{formatarPreco(preco)}</strong>
          </div>
          <Link to="/cliente" className={estilos.comprar}>
            Comprar
          </Link>
        </div>
      </div>
    </article>
  )
}
