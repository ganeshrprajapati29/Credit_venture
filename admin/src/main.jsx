import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import './index.css'
import App from './App.jsx'
import { AuthProvider } from './lib/auth.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter basename={import.meta.env.BASE_URL.replace(/\/$/, '') || '/'}>
      <AuthProvider>
        <App />
        <Toaster position="top-right" toastOptions={{ style: { borderRadius: 12, fontSize: 14 } }} />
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>
)
