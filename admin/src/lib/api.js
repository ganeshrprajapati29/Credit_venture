import axios from 'axios'

// In production set VITE_API_URL=https://api.yourdomain.com/api/v1
export const API_URL = import.meta.env.VITE_API_URL || '/api/v1'
const TOKEN_KEY = 'cv_admin_token'

export const tokenStore = {
  get: () => {
    try {
      return localStorage.getItem(TOKEN_KEY)
    } catch {
      return null
    }
  },
  set: (t) => {
    try {
      localStorage.setItem(TOKEN_KEY, t)
    } catch {
      /* ignore */
    }
  },
  clear: () => {
    try {
      localStorage.removeItem(TOKEN_KEY)
    } catch {
      /* ignore */
    }
  },
}

export const api = axios.create({ baseURL: API_URL, timeout: 30000 })

api.interceptors.request.use((cfg) => {
  const t = tokenStore.get()
  if (t) cfg.headers.Authorization = `Bearer ${t}`
  return cfg
})

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401 && !err.config.url.includes('/auth/login')) {
      tokenStore.clear()
      window.dispatchEvent(new Event('cv:logout'))
    }
    return Promise.reject(err)
  }
)

/** Extract the API's `data` field. */
export const get = (url, params) => api.get(url, { params }).then((r) => r.data.data)
export const send = (method, url, body) => api.request({ method, url, data: body }).then((r) => r.data)

export const errMsg = (e) => e?.response?.data?.message || e?.message || 'Something went wrong'

/** Load a private file (KYC etc.) with auth header and return an object URL. */
export async function fetchFileUrl(name) {
  const res = await api.get(`/files/${encodeURIComponent(name)}`, { responseType: 'blob' })
  return URL.createObjectURL(res.data)
}
