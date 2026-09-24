import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import CartaoProduto from '@/componentes/comuns/CartaoProduto/CartaoProduto'
import Revelar from '@/componentes/comuns/Revelar/Revelar'
import { IconeSetaDireita } from '@/recursos/icones/Icones'
import { buscarProdutos, categoriasProdutos } from '@/servicos/produtos'
import estilos from './Loja.module.css'

const TODOS = 'Todos'
const LIMITE = 8 // quantos produtos aparecem na página inicial

// Capas provisórias por categoria até termos fotos reais
const capas = {
  Cabelo: 'linear-gradient(135deg, #d9b28f, #946535)',
  Barba: 'linear-gradient(135deg, #5a534c, #1c1b1a)',
  Pele: 'linear-gradient(135deg, #ecd3c3, #c29a7a)',
  Unhas: 'linear-gradient(135deg, #d8a7a0, #9c5f58)',
}

export default function Loja() {
  const [produtos, setProdutos] = useState([])
  const [filtro, setFiltro] = useState(TODOS)

  useEffect(() => {
    buscarProdutos().then(setProdutos)
  }, [])

  // Sem nenhum produto cadastrado, a loja não aparece
  if (produtos.length === 0) return null

  const visiveis = produtos
    .filter((produto) => filtro === TODOS || produto.categoria === filtro)
    .slice(0, LIMITE)

  return (
    <section className={`secao ${estilos.loja}`}>
      <div className="container">
        <Revelar>
          <div className={estilos.topo}>
            <div>
              <h2>Loja</h2>
              <p>Os produtos que os profissionais usam e recomendam, direto para a sua casa.</p>
            </div>
            <Link to="/cliente" className={estilos.verTudo}>
              Ver loja completa <IconeSetaDireita tamanho={14} />
            </Link>
          </div>

          <div className={estilos.filtros}>
            {[TODOS, ...categoriasProdutos].map((categoria) => (
              <button
                key={categoria}
                className={`${estilos.filtro} ${filtro === categoria ? estilos.filtroAtivo : ''}`}
                aria-pressed={filtro === categoria}
                onClick={() => setFiltro(categoria)}
              >
                {categoria}
              </button>
            ))}
          </div>
        </Revelar>

        {/* A "key" muda com o filtro para os cartões animarem de novo */}
        <div key={filtro} className={estilos.grade}>
          {visiveis.map((produto, i) => (
            <CartaoProduto
              key={produto.id}
              produto={produto}
              capa={capas[produto.categoria]}
              className={estilos.entrar}
              style={{ animationDelay: `${i * 60}ms` }}
            />
          ))}
        </div>
      </div>
    </section>
  )
}
