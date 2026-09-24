import { lazy, Suspense } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import Landing from '@/paginas/comum/Landing/Landing'
import Acessar from '@/paginas/comum/Acessar'

// Cada área só é baixada quando o usuário entra nela:
// o cliente nunca carrega o código do profissional e vice-versa.
const RotasCliente = lazy(() => import('@/rotas/RotasCliente'))
const RotasProfissional = lazy(() => import('@/rotas/RotasProfissional'))

export default function App() {
  return (
    <Suspense fallback={null}>
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/acessar" element={<Acessar />} />
        <Route path="/cliente/*" element={<RotasCliente />} />
        <Route path="/profissional/*" element={<RotasProfissional />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  )
}
