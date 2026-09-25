import { Link } from 'react-router-dom'
import estilos from './Rodape.module.css'

// Colunas do rodapé. Para adicionar/remover links, basta mexer aqui.
// As páginas "sobre", "termos" etc. ainda não existem (por enquanto voltam para o início).
const colunas = [
  {
    titulo: 'Sobre a Glowment',
    links: [
      { texto: 'Quem somos', para: '/sobre' },
      { texto: 'Como funciona', para: '/como-funciona' },
      { texto: 'Contato', para: '/contato' },
    ],
  },
  {
    titulo: 'Para empresas',
    links: [
      { texto: 'Registar o meu negócio', para: '/profissional' },
      { texto: 'Área do profissional', para: '/profissional' },
    ],
  },
  {
    titulo: 'Jurídico',
    links: [
      { texto: 'Termos de uso', para: '/termos' },
      { texto: 'Política de privacidade', para: '/privacidade' },
      { texto: 'Política de cookies', para: '/cookies' },
    ],
  },
]

export default function Rodape() {
  return (
    <footer className={estilos.rodape}>
      <div className={`container ${estilos.grade}`}>
        <div className={estilos.marca}>
          <Link to="/" className={estilos.logo}>
            Glow<span>ment</span>
          </Link>
          <p>A sua rotina de beleza e cuidado, num só lugar.</p>
        </div>

        {colunas.map((coluna) => (
          <nav key={coluna.titulo} aria-label={coluna.titulo}>
            <h4>{coluna.titulo}</h4>
            <ul>
              {coluna.links.map((link) => (
                <li key={link.texto}>
                  <Link to={link.para}>{link.texto}</Link>
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>

      <div className={`container ${estilos.base}`}>
        © {new Date().getFullYear()} Glowment. Todos os direitos reservados.
      </div>
    </footer>
  )
}
