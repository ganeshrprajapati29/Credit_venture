import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { AlertTriangle, BadgeCheck, Banknote, Clock, FileStack, IndianRupee, Users, Wallet } from 'lucide-react'
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { get, errMsg } from '../lib/api'
import { date, inr, title } from '../lib/format'
import { Badge, Card, Spinner, Stat } from '../components/ui'

export default function Dashboard() {
  const [d, setD] = useState(null)
  const [err, setErr] = useState(null)
  useEffect(() => {
    get('/admin/dashboard').then(setD).catch((e) => setErr(errMsg(e)))
  }, [])

  if (err) return <p className="text-rose-600">{err}</p>
  if (!d) return <Spinner />
  const sc = d.statusCounts
  const pipeline = ['submitted', 'under_review', 'approved', 'disbursed', 'closed', 'rejected']

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Stat label="New applications" value={sc.submitted} icon={FileStack} sub={`${sc.under_review} under review`} />
        <Stat label="Approved (to disburse)" value={sc.approved} icon={BadgeCheck} tone="green" />
        <Stat label="Active loans" value={sc.disbursed} icon={Wallet} tone="violet" sub={`${sc.closed} closed`} />
        <Stat label="Customers" value={d.users} icon={Users} tone="sky" sub={`+${d.usersToday} today`} />
        <Stat label="Total disbursed" value={inr(d.disbursedAmount)} icon={Banknote} tone="green" sub={`Principal ${inr(d.disbursedPrincipal)}`} />
        <Stat label="EMI collected" value={inr(d.collectedAmount)} icon={IndianRupee} />
        <Stat label="Payments to verify" value={d.pendingPayments} icon={Clock} tone="amber" />
        <Stat label="Overdue EMIs" value={d.overdue.count} icon={AlertTriangle} tone="rose" sub={inr(d.overdue.amount)} />
      </div>

      <div className="grid gap-6 xl:grid-cols-3">
        <Card title="Applications – last 14 days" className="xl:col-span-2">
          <div className="h-72 p-4">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={d.trend} margin={{ left: -20, right: 8, top: 8 }}>
                <defs>
                  <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0" stopColor="#3d47cf" stopOpacity={0.35} />
                    <stop offset="1" stopColor="#3d47cf" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#eef2f7" />
                <XAxis dataKey="date" tickFormatter={(v) => v.slice(5)} tick={{ fontSize: 11 }} />
                <YAxis allowDecimals={false} tick={{ fontSize: 11 }} />
                <Tooltip formatter={(v, n) => (n === 'amount' ? inr(v) : v)} />
                <Area type="monotone" dataKey="applications" stroke="#3d47cf" strokeWidth={2.5} fill="url(#g1)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card title="Pipeline">
          <div className="space-y-3 p-5">
            {pipeline.map((s) => {
              const total = pipeline.reduce((a, k) => a + sc[k], 0) || 1
              return (
                <Link to={`/loans?status=${s}`} key={s} className="block">
                  <div className="mb-1 flex justify-between text-sm">
                    <span className="font-medium text-slate-600">{title(s)}</span>
                    <span className="font-bold">{sc[s]}</span>
                  </div>
                  <div className="h-2 rounded-full bg-slate-100">
                    <div className="h-2 rounded-full bg-brand-600" style={{ width: `${(sc[s] / total) * 100}%` }} />
                  </div>
                </Link>
              )
            })}
          </div>
        </Card>
      </div>

      <Card title="Recent activity" action={<Link to="/loans" className="text-sm font-semibold text-brand-700">View all</Link>}>
        <div className="divide-y divide-slate-100">
          {d.recent.length === 0 && <p className="p-5 text-sm text-slate-500">No applications yet.</p>}
          {d.recent.map((l) => (
            <Link key={l._id} to={`/loans/${l._id}`} className="flex items-center justify-between gap-4 px-5 py-3 hover:bg-slate-50">
              <div className="min-w-0">
                <p className="truncate font-semibold">
                  {l.basic?.firstName} {l.basic?.lastName}
                </p>
                <p className="text-xs text-slate-500">
                  {l.loanNumber} · {date(l.updatedAt)}
                </p>
              </div>
              <div className="flex items-center gap-3">
                <span className="hidden font-semibold sm:block">{inr(l.offer?.amount)}</span>
                <Badge status={l.status} />
              </div>
            </Link>
          ))}
        </div>
      </Card>
    </div>
  )
}
