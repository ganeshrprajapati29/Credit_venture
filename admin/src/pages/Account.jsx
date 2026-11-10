import { useState } from 'react'
import toast from 'react-hot-toast'
import { send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { title } from '../lib/format'
import { Button, Card, Field, Input, KV } from '../components/ui'

export default function Account() {
  const { admin } = useAuth()
  const [f, setF] = useState({ currentPassword: '', newPassword: '', confirm: '' })
  const [busy, setBusy] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    if (f.newPassword !== f.confirm) return toast.error('Passwords do not match')
    setBusy(true)
    try {
      await send('put', '/admin/auth/password', f)
      toast.success('Password updated')
      setF({ currentPassword: '', newPassword: '', confirm: '' })
    } catch (err) {
      toast.error(errMsg(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid max-w-4xl gap-6 md:grid-cols-2">
      <Card title="Profile">
        <dl className="grid gap-4 p-5">
          <KV label="Name" value={admin.name} />
          <KV label="Email" value={admin.email} />
          <KV label="Role" value={title(admin.role)} />
        </dl>
      </Card>
      <Card title="Change password">
        <form onSubmit={submit} className="space-y-4 p-5">
          <Field label="Current password">
            <Input type="password" required value={f.currentPassword} onChange={(e) => setF({ ...f, currentPassword: e.target.value })} />
          </Field>
          <Field label="New password" hint="Minimum 8 characters">
            <Input type="password" required minLength={8} value={f.newPassword} onChange={(e) => setF({ ...f, newPassword: e.target.value })} />
          </Field>
          <Field label="Confirm new password">
            <Input type="password" required value={f.confirm} onChange={(e) => setF({ ...f, confirm: e.target.value })} />
          </Field>
          <Button type="submit" loading={busy}>
            Update password
          </Button>
        </form>
      </Card>
    </div>
  )
}
