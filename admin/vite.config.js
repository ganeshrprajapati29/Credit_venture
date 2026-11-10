import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  return {
    // Set VITE_BASE=/admin/ if the panel is served under a sub path
    base: env.VITE_BASE || '/',
    plugins: [react(), tailwindcss()],
    server: {
      port: 5173,
      proxy: {
        '/api': env.VITE_DEV_PROXY || 'http://localhost:5000',
        '/uploads': env.VITE_DEV_PROXY || 'http://localhost:5000',
      },
    },
  }
})
