import { Routes, Route } from 'react-router-dom'
import InicioCliente from '@/paginas/cliente/InicioCliente'

// Todas as rotas da área do cliente ficam aqui (/cliente/...)
export default function RotasCliente() {
  return (
    <Routes>
      <Route index element={<InicioCliente />} />
    </Routes>
  )
}
