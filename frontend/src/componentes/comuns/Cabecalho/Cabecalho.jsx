import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import estilos from './Cabecalho.module.css'

// Itens da navbar (lado direito). Para adicionar/remover, basta mexer aqui.
const links = [
  { texto: 'Acessar', para: '/acessar' },
  { texto: 'Para empresas', para: '/profissional' },
  { texto: 'Cliente', para: '/cliente' },
]

export default function Cabecalho() {
  const [menuAberto, setMenuAberto] = useState(false)
  const [rolou, setRolou] = useState(false)

  // Adiciona sombra no cabeçalho quando a página é rolada
  useEffect(() => {
    const aoRolar = () => setRolou(window.scrollY > 10)
    aoRolar()
    window.addEventListener('scroll', aoRolar, { passive: true })
    return () => window.removeEventListener('scroll', aoRolar)
  }, [])

  const fecharMenu = () => setMenuAberto(false)

  return (
    <header className={`${estilos.cabecalho} ${rolou ? estilos.rolou : ''}`}>
      <div className={`container ${estilos.conteudo}`}>
        <Link to="/" className={estilos.logo} onClick={fecharMenu}>
          Glow<span>ment</span>
        </Link>

        <button
          className={estilos.hamburguer}
          aria-label="Abrir menu"
          aria-expanded={menuAberto}
          onClick={() => setMenuAberto(!menuAberto)}
        >
          <span />
          <span />
          <span />
        </button>

        <nav className={`${estilos.nav} ${menuAberto ? estilos.navAberta : ''}`}>
          {links.map((link) => (
            <Link key={link.texto} to={link.para} className={estilos.link} onClick={fecharMenu}>
              {link.texto}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  )
}
