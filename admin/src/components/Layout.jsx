import { useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { Bell, CreditCard, FileStack, Image, KeyRound, LayoutDashboard, LogOut, Menu, Settings, Shield, Users, X } from 'lucide-react'
import { useAuth } from '../lib/auth'
import { cx } from './ui'
import { title } from '../lib/format'

const NAV = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/loans', label: 'Loan Applications', icon: FileStack },
  { to: '/payments', label: 'EMI Payments', icon: CreditCard },
  { to: '/users', label: 'Customers', icon: Users },
  { to: '/banners', label: 'App Banners', icon: Image, roles: ['superadmin', 'manager'] },
  { to: '/notifications', label: 'Notifications', icon: Bell },
  { to: '/settings', label: 'App Settings', icon: Settings },
  { to: '/team', label: 'Team & Roles', icon: Shield, roles: ['superadmin'] },
  { to: '/account', label: 'My Account', icon: KeyRound },
]

export default function Layout() {
  const { admin, logout, can } = useAuth()
  const [open, setOpen] = useState(false)
  const loc = useLocation()
  const current = NAV.find((n) => (n.end ? loc.pathname === n.to : loc.pathname.startsWith(n.to)))

  const sidebar = (
    <div className="flex h-full flex-col bg-brand-900 text-white">
      <div className="flex items-center gap-3 px-5 py-5">
        <img src={`${import.meta.env.BASE_URL}logo.svg`} alt="" className="size-10 rounded-xl shadow-lg" />
        <div>
          <p className="text-base font-extrabold leading-tight">Credit Ventures</p>
          <p className="text-[11px] font-medium text-brand-200">Admin Console</p>
        </div>
      </div>
      <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-2 scroll-thin">
        {NAV.filter((n) => !n.roles || can(...n.roles)).map((n) => (
          <NavLink
            key={n.to}
            to={n.to}
            end={n.end}
            onClick={() => setOpen(false)}
            className={({ isActive }) =>
              cx(
                'flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium transition',
                isActive ? 'bg-white text-brand-900 shadow' : 'text-brand-100 hover:bg-white/10'
              )
            }
          >
            <n.icon className="size-[18px]" />
            {n.label}
          </NavLink>
        ))}
      </nav>
      <div className="m-3 rounded-xl bg-white/10 p-3">
        <p className="truncate text-sm font-semibold">{admin?.name}</p>
        <p className="truncate text-xs text-brand-200">
          {admin?.email} · {title(admin?.role)}
        </p>
        <button onClick={logout} className="mt-3 flex w-full items-center justify-center gap-2 rounded-lg bg-white/10 py-2 text-xs font-semibold hover:bg-white/20 cursor-pointer">
          <LogOut className="size-4" /> Logout
        </button>
      </div>
    </div>
  )

  return (
    <div className="flex h-full">
      <aside className="hidden w-64 shrink-0 lg:block">{sidebar}</aside>
      {open && (
        <div className="fixed inset-0 z-40 lg:hidden" onClick={() => setOpen(false)}>
          <div className="absolute inset-0 bg-black/40" />
          <aside className="absolute inset-y-0 left-0 w-64" onClick={(e) => e.stopPropagation()}>
            {sidebar}
          </aside>
        </div>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-slate-200 bg-white/90 px-4 backdrop-blur sm:px-6">
          <button className="rounded-lg p-2 hover:bg-slate-100 lg:hidden cursor-pointer" onClick={() => setOpen(!open)}>
            {open ? <X className="size-5" /> : <Menu className="size-5" />}
          </button>
          <h1 className="truncate text-lg font-bold text-slate-900">{current?.label || 'Credit Ventures'}</h1>
        </header>
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 scroll-thin">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
