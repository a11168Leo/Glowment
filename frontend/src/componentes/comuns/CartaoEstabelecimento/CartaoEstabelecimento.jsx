import { Link } from 'react-router-dom'
import { IconeEstrela, IconeLocalizacao } from '@/recursos/icones/Icones'
import estilos from './CartaoEstabelecimento.module.css'

/**
 * Cartão de um salão ou barbearia.
 * capa: fundo usado quando o estabelecimento ainda não tem foto.
 */
export default function CartaoEstabelecimento({ estabelecimento, capa }) {
  const { nome, bairro, nota, avaliacoes, foto, servicos } = estabelecimento
  const iniciais = nome
    .split(' ')
    .slice(0, 2)
    .map((palavra) => palavra[0])
    .join('')

  const fundo = foto
    ? { backgroundImage: `url(${JSON.stringify(foto)})`, backgroundSize: 'cover', backgroundPosition: 'center' }
    : { background: capa }

  return (
    <Link to="/cliente" className={estilos.cartao}>
      <div className={estilos.capa} style={fundo}>
        {!foto && <span>{iniciais}</span>}
      </div>

      <div className={estilos.info}>
        <div className={estilos.linha}>
          <h3>{nome}</h3>
          {nota != null ? (
            <span className={estilos.nota}>
              <IconeEstrela tamanho={13} />
              {nota.toLocaleString('pt-PT', { minimumFractionDigits: 1 })}
              <small>({avaliacoes})</small>
            </span>
          ) : (
            <span className={estilos.novo}>Novo</span>
          )}
        </div>

        {bairro && (
          <p className={estilos.bairro}>
            <IconeLocalizacao tamanho={13} />
            {bairro}
          </p>
        )}

        {servicos.length > 0 && (
          <ul className={estilos.servicos}>
            {servicos.map((servico) => (
              <li key={servico}>{servico}</li>
            ))}
          </ul>
        )}
      </div>
    </Link>
  )
}
