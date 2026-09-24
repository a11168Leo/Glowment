import { Link } from 'react-router-dom'
import { IconeEstrela, IconeLocalizacao } from '@/recursos/icones/Icones'
import estilos from './CartaoEstabelecimento.module.css'

/**
 * Cartão de um salão ou barbearia.
 * capa: fundo da parte de cima (cor/gradiente) até termos fotos reais.
 */
export default function CartaoEstabelecimento({ estabelecimento, capa }) {
  const { nome, bairro, nota, avaliacoes, servicos } = estabelecimento
  const iniciais = nome
    .split(' ')
    .slice(0, 2)
    .map((palavra) => palavra[0])
    .join('')

  return (
    <Link to="/cliente" className={estilos.cartao}>
      <div className={estilos.capa} style={{ background: capa }}>
        <span>{iniciais}</span>
      </div>

      <div className={estilos.info}>
        <div className={estilos.linha}>
          <h3>{nome}</h3>
          <span className={estilos.nota}>
            <IconeEstrela tamanho={13} />
            {nota.toLocaleString('pt-BR', { minimumFractionDigits: 1 })}
            <small>({avaliacoes})</small>
          </span>
        </div>

        <p className={estilos.bairro}>
          <IconeLocalizacao tamanho={13} />
          {bairro}
        </p>

        <ul className={estilos.servicos}>
          {servicos.map((servico) => (
            <li key={servico}>{servico}</li>
          ))}
        </ul>
      </div>
    </Link>
  )
}
