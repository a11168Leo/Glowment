import Cabecalho from '@/componentes/comuns/Cabecalho/Cabecalho'
import Rodape from '@/componentes/comuns/Rodape/Rodape'
import Hero from './secoes/Hero/Hero'
import Estabelecimentos from './secoes/Estabelecimentos/Estabelecimentos'
import Loja from './secoes/Loja/Loja'

// Página inicial vista por todos (clientes e profissionais).
// Estabelecimentos e Loja só aparecem se houver dados registados.
export default function Landing() {
  return (
    <>
      <Cabecalho />
      <main>
        <Hero />
        <Estabelecimentos />
        <Loja />
      </main>
      <Rodape />
    </>
  )
}
