import { Link } from 'react-router-dom'
import estilos from './Botao.module.css'

/**
 * Botão padrão do site.
 * - Com "para": vira um link de navegação (<Link>).
 * - Sem "para": é um <button> normal.
 * variante: primario | secundario | claro
 * tamanho: medio | grande
 */
export default function Botao({
  para,
  variante = 'primario',
  tamanho = 'medio',
  className = '',
  children,
  ...resto
}) {
  const classes = `${estilos.botao} ${estilos[variante]} ${estilos[tamanho]} ${className}`

  if (para) {
    return (
      <Link to={para} className={classes} {...resto}>
        {children}
      </Link>
    )
  }

  return (
    <button type="button" className={classes} {...resto}>
      {children}
    </button>
  )
}
