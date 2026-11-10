import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { get, send, tokenStore } from './api'

const AuthCtx = createContext(null)

export function AuthProvider({ children }) {
  const [admin, setAdmin] = useState(null)
  const [loading, setLoading] = useState(!!tokenStore.get())

  const logout = useCallback(() => {
    tokenStore.clear()
    setAdmin(null)
  }, [])

  useEffect(() => {
    const onLogout = () => setAdmin(null)
    window.addEventListener('cv:logout', onLogout)
    if (tokenStore.get()) {
      get('/admin/auth/me')
        .then((d) => setAdmin(d.admin))
        .catch(() => tokenStore.clear())
        .finally(() => setLoading(false))
    }
    return () => window.removeEventListener('cv:logout', onLogout)
  }, [])

  const login = async (email, password) => {
    const r = await send('post', '/admin/auth/login', { email, password })
    tokenStore.set(r.data.token)
    setAdmin(r.data.admin)
    return r.data.admin
  }

  const can = (...roles) => !!admin && (roles.length === 0 || roles.includes(admin.role))

  return <AuthCtx.Provider value={{ admin, loading, login, logout, can }}>{children}</AuthCtx.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthCtx)
