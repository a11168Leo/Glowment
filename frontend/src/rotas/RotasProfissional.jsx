import { Routes, Route } from 'react-router-dom'
import InicioProfissional from '@/paginas/profissional/InicioProfissional'

// Todas as rotas da área do profissional ficam aqui (/profissional/...)
export default function RotasProfissional() {
  return (
    <Routes>
      <Route index element={<InicioProfissional />} />
    </Routes>
  )
}
