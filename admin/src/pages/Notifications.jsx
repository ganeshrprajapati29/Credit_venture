import { useCallback, useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { Send, Trash2 } from 'lucide-react'
import { api, get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { dateTime } from '../lib/format'
import { Button, Card, Empty, Field, Input, Pagination, Select, Spinner, Textarea } from '../components/ui'

export default function Notifications() {
  const { can } = useAuth()
  const [form, setForm] = useState({ title: '', body: '', type: 'info', mobile: '' })
  const [busy, setBusy] = useState(false)
  const [page, setPage] = useState(1)
  const [data, setData] = useState(null)

  const load = useCallback(() => {
    get('/admin/notifications', { page })
      .then(setData)
      .catch((e) => toast.error(errMsg(e)))
  }, [page])
  useEffect(load, [load])

  const submit = async (e) => {
    e.preventDefault()
    setBusy(true)
    try {
      const r = await send('post', '/admin/notifications', { ...form, mobile: form.mobile || undefined })
      toast.success(r.message)
      setForm({ title: '', body: '', type: 'info', mobile: '' })
      load()
    } catch (err) {
      toast.error(errMsg(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid gap-6 lg:grid-cols-5">
      {can('superadmin', 'manager') && (
        <Card title="Send in-app notification" className="h-fit lg:col-span-2">
          <form onSubmit={submit} className="space-y-4 p-5">
            <Field label="Send to" hint="Leave mobile empty to broadcast to every customer">
              <Input placeholder="10 digit mobile (optional)" value={form.mobile} onChange={(e) => setForm({ ...form, mobile: e.target.value.replace(/\D/g, '').slice(0, 10) })} />
            </Field>
            <Field label="Type">
              <Select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                <option value="info">Information</option>
                <option value="offer">Offer</option>
                <option value="loan">Loan update</option>
                <option value="payment">Payment reminder</option>
              </Select>
            </Field>
            <Field label="Title">
              <Input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
            </Field>
            <Field label="Message">
              <Textarea required value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
            </Field>
            <Button type="submit" icon={Send} loading={busy} className="w-full">
              Send
            </Button>
          </form>
        </Card>
      )}
      <Card title="Sent notifications" className="lg:col-span-3">
        {!data ? (
          <Spinner />
        ) : data.items.length === 0 ? (
          <Empty />
        ) : (
          <>
            <div className="divide-y divide-slate-100">
              {data.items.map((n) => (
                <div key={n._id} className="flex items-start justify-between gap-3 px-5 py-3">
                  <div className="min-w-0">
                    <p className="font-semibold">{n.title}</p>
                    <p className="text-sm text-slate-600">{n.body}</p>
                    <p className="mt-1 text-xs text-slate-400">
                      {n.user ? `To ${n.user.fullName || ''} +91 ${n.user.mobile}` : 'Broadcast'} · {n.type} · {dateTime(n.createdAt)} · read by {n.reads}
                    </p>
                  </div>
                  {can('superadmin', 'manager') && (
                    <Button
                      size="sm"
                      variant="ghost"
                      icon={Trash2}
                      onClick={async () => {
                        await api.delete(`/admin/notifications/${n._id}`)
                        load()
                      }}
                    />
                  )}
                </div>
              ))}
            </div>
            <Pagination page={data.page} pages={data.pages} total={data.total} onChange={setPage} />
          </>
        )}
      </Card>
    </div>
  )
}
