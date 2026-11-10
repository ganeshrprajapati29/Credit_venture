import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './lib/auth'
import Layout from './components/Layout'
import { Spinner } from './components/ui'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Loans from './pages/Loans'
import LoanDetail from './pages/LoanDetail'
import Payments from './pages/Payments'
import Users from './pages/Users'
import UserDetail from './pages/UserDetail'
import Banners from './pages/Banners'
import Notifications from './pages/Notifications'
import Settings from './pages/Settings'
import Team from './pages/Team'
import Account from './pages/Account'

export default function App() {
  const { admin, loading } = useAuth()
  if (loading) return <Spinner className="h-full" />
  if (!admin)
    return (
      <Routes>
        <Route path="*" element={<Login />} />
      </Routes>
    )
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="loans" element={<Loans />} />
        <Route path="loans/:id" element={<LoanDetail />} />
        <Route path="payments" element={<Payments />} />
        <Route path="users" element={<Users />} />
        <Route path="users/:id" element={<UserDetail />} />
        <Route path="banners" element={<Banners />} />
        <Route path="notifications" element={<Notifications />} />
        <Route path="settings" element={<Settings />} />
        <Route path="team" element={<Team />} />
        <Route path="account" element={<Account />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
