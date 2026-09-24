import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react()],
  resolve: {
    // Permite importar com "@/..." em vez de "../../../.."
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
