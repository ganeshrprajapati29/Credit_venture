import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import toast from 'react-hot-toast'
import { ArrowLeft, KeyRound, ShieldBan, ShieldCheck } from 'lucide-react'
import { get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { date, dateTime, inr } from '../lib/format'
import { Badge, Button, Card, Field, Input, KV, Modal, Spinner } from '../components/ui'

export default function UserDetail() {
  const { id } = useParams()
  const { can } = useAuth()
  const [d, setD] = useState(null)
  const [mpinOpen, setMpinOpen] = useState(false)
  const [mpin, setMpin] = useState('')
  const [busy, setBusy] = useState(false)

  const load = useCallback(() => {
    get(`/admin/users/${id}`).then(setD).catch((e) => toast.error(errMsg(e)))
  }, [id])
  useEffect(load, [load])

  if (!d) return <Spinner />
  const { user, loans } = d

  const update = async (body, close) => {
    setBusy(true)
    try {
      const r = await send('patch', `/admin/users/${id}`, body)
      toast.success(r.message)
      close?.()
      load()
    } catch (e) {
      toast.error(errMsg(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link to="/users" className="rounded-xl border border-slate-200 bg-white p-2 hover:bg-slate-50">
            <ArrowLeft className="size-5" />
          </Link>
          <div>
            <h2 className="text-xl font-extrabold">{user.fullName || 'New user'}</h2>
            <p className="text-sm text-slate-500">+91 {user.mobile}</p>
          </div>
          <Badge status={user.status} />
        </div>
        {can('superadmin', 'manager') && (
          <div className="flex gap-2">
            <Button variant="outline" icon={KeyRound} onClick={() => setMpinOpen(true)}>
              Reset MPIN
            </Button>
            {user.status === 'active' ? (
              <Button variant="danger" icon={ShieldBan} loading={busy} onClick={() => update({ status: 'blocked' })}>
                Block
              </Button>
            ) : (
              <Button variant="success" icon={ShieldCheck} loading={busy} onClick={() => update({ status: 'active' })}>
                Unblock
              </Button>
            )}
          </div>
        )}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card title="Profile" className="lg:col-span-1">
          <dl className="grid gap-4 p-5">
            <KV label="Email" value={user.email} />
            <KV label="Registered" value={dateTime(user.createdAt)} />
            <KV label="Last login" value={dateTime(user.lastLoginAt)} />
            <KV label="Device" value={[user.device?.brand, user.device?.model].filter(Boolean).join(' ')} />
            <KV label="OS" value={[user.device?.os, user.device?.osVersion].filter(Boolean).join(' ')} />
            <KV label="App version" value={user.device?.appVersion} />
            <KV label="Permissions granted" value={(user.consent?.permissions || []).join(', ') || '—'} />
            <KV label="Consent accepted" value={dateTime(user.consent?.acceptedAt)} />
          </dl>
        </Card>
        <Card title="Loan history" className="lg:col-span-2">
          {loans.length === 0 ? (
            <p className="p-5 text-sm text-slate-500">No applications yet.</p>
          ) : (
            <div className="divide-y divide-slate-100">
              {loans.map((l) => (
                <Link key={l._id} to={`/loans/${l._id}`} className="flex items-center justify-between px-5 py-3 hover:bg-slate-50">
                  <div>
                    <p className="font-mono text-sm font-semibold">{l.loanNumber}</p>
                    <p className="text-xs text-slate-500">{date(l.submittedAt || l.createdAt)}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="font-semibold">{inr(l.approved?.amount || l.offer?.amount)}</span>
                    <Badge status={l.status} />
                  </div>
                </Link>
              ))}
            </div>
          )}
        </Card>
      </div>

      <Modal
        open={mpinOpen}
        onClose={() => setMpinOpen(false)}
        title="Reset customer MPIN"
        footer={
          <Button loading={busy} onClick={() => update({ resetMpin: mpin }, () => { setMpinOpen(false); setMpin('') })}>
            Set new MPIN
          </Button>
        }
      >
        <Field label="New 4-digit MPIN" hint="Share it with the customer after verifying their identity on call.">
          <Input inputMode="numeric" maxLength={4} value={mpin} onChange={(e) => setMpin(e.target.value.replace(/\D/g, ''))} />
        </Field>
      </Modal>
    </div>
  )
}
