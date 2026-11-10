import { useState } from 'react'
import toast from 'react-hot-toast'
import { Lock, Mail, ShieldCheck, TrendingUp, Zap } from 'lucide-react'
import { useAuth } from '../lib/auth'
import { errMsg } from '../lib/api'
import { Button, Field, Input } from '../components/ui'

export default function Login() {
  const { login } = useAuth()
  const [form, setForm] = useState({ email: '', password: '' })
  const [busy, setBusy] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setBusy(true)
    try {
      const a = await login(form.email, form.password)
      toast.success(`Welcome, ${a.name}`)
    } catch (err) {
      toast.error(errMsg(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-full lg:grid-cols-2">
      <div className="relative hidden overflow-hidden bg-gradient-to-br from-brand-700 via-brand-800 to-brand-900 p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="absolute -right-24 -top-24 size-96 rounded-full bg-white/5" />
        <div className="absolute -bottom-32 -left-16 size-96 rounded-full bg-accent-500/10" />
        <div className="relative flex items-center gap-3">
          <img src={`${import.meta.env.BASE_URL}logo.svg`} alt="" className="size-12 rounded-2xl" />
          <span className="text-2xl font-extrabold">Credit Ventures</span>
        </div>
        <div className="relative max-w-md">
          <h2 className="text-4xl font-extrabold leading-tight">Manage loans, KYC and collections in one place.</h2>
          <div className="mt-10 space-y-5">
            {[
              [Zap, 'Fast approvals', 'Review applications and documents in minutes'],
              [ShieldCheck, 'Secure KYC', 'Documents are stored privately and access-controlled'],
              [TrendingUp, 'Live insights', 'Track disbursals, EMIs and overdue accounts'],
            ].map(([Icon, t, s]) => (
              <div key={t} className="flex gap-4">
                <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-white/10">
                  <Icon className="size-5 text-emerald-300" />
                </span>
                <div>
                  <p className="font-semibold">{t}</p>
                  <p className="text-sm text-brand-100">{s}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
        <p className="relative text-xs text-brand-200">© {new Date().getFullYear()} Credit Ventures. All rights reserved.</p>
      </div>

      <div className="flex items-center justify-center p-6">
        <form onSubmit={submit} className="w-full max-w-sm">
          <img src={`${import.meta.env.BASE_URL}logo.svg`} alt="" className="mb-6 size-14 rounded-2xl lg:hidden" />
          <h1 className="text-2xl font-extrabold text-slate-900">Sign in to Admin</h1>
          <p className="mt-1 text-sm text-slate-500">Enter your credentials to continue</p>
          <div className="mt-8 space-y-4">
            <Field label="Email address">
              <div className="relative">
                <Mail className="absolute left-3.5 top-3 size-4 text-slate-400" />
                <Input type="email" required autoFocus className="pl-10" placeholder="admin@creditventures.in" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
              </div>
            </Field>
            <Field label="Password">
              <div className="relative">
                <Lock className="absolute left-3.5 top-3 size-4 text-slate-400" />
                <Input type="password" required className="pl-10" placeholder="••••••••" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
              </div>
            </Field>
            <Button type="submit" size="lg" loading={busy} className="w-full">
              Sign in
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
