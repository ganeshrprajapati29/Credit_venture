import { useCallback, useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { Plus } from 'lucide-react'
import { get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { dateTime, title } from '../lib/format'
import { Badge, Button, Card, Field, Input, Modal, Select, Spinner, Table } from '../components/ui'

const ROLE_HELP = {
  superadmin: 'Full access including settings and team',
  manager: 'Approve, reject, disburse, verify payments, banners',
  verifier: 'View applications and mark verification checks',
}

export default function Team() {
  const { can, admin: me } = useAuth()
  const [items, setItems] = useState(null)
  const [form, setForm] = useState(null)
  const [busy, setBusy] = useState(false)

  const load = useCallback(() => {
    get('/admin/team')
      .then((d) => setItems(d.admins))
      .catch((e) => toast.error(errMsg(e)))
  }, [])
  useEffect(() => {
    if (can('superadmin')) load()
  }, [load, can])

  if (!can('superadmin')) return <p className="text-slate-500">Only super admins can manage the team.</p>
  if (!items) return <Spinner />

  const save = async () => {
    setBusy(true)
    try {
      if (form._id) await send('patch', `/admin/team/${form._id}`, { name: form.name, role: form.role, password: form.password || undefined })
      else await send('post', '/admin/team', form)
      toast.success('Saved')
      setForm(null)
      load()
    } catch (e) {
      toast.error(errMsg(e))
    } finally {
      setBusy(false)
    }
  }

  const toggle = async (a) => {
    try {
      await send('patch', `/admin/team/${a._id}`, { active: !a.active })
      load()
    } catch (e) {
      toast.error(errMsg(e))
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button icon={Plus} onClick={() => setForm({ name: '', email: '', password: '', role: 'verifier' })}>
          Add member
        </Button>
      </div>
      <Card>
        <Table head={['Name', 'Email', 'Role', 'Last login', 'Status', '']}>
          {items.map((a) => (
            <tr key={a._id}>
              <td className="px-5 py-3 font-semibold">{a.name}</td>
              <td className="px-5 py-3">{a.email}</td>
              <td className="px-5 py-3">{title(a.role)}</td>
              <td className="px-5 py-3 text-xs text-slate-500">{dateTime(a.lastLoginAt)}</td>
              <td className="px-5 py-3">
                <Badge status={a.active ? 'active' : 'blocked'}>{a.active ? 'Active' : 'Disabled'}</Badge>
              </td>
              <td className="space-x-1 px-5 py-3 text-right">
                <Button size="sm" variant="ghost" onClick={() => setForm({ ...a, password: '' })}>
                  Edit
                </Button>
                {a._id !== me._id && (
                  <Button size="sm" variant="ghost" onClick={() => toggle(a)}>
                    {a.active ? 'Disable' : 'Enable'}
                  </Button>
                )}
              </td>
            </tr>
          ))}
        </Table>
      </Card>

      <Modal open={!!form} onClose={() => setForm(null)} title={form?._id ? 'Edit member' : 'Add team member'} footer={<Button loading={busy} onClick={save}>Save</Button>}>
        {form && (
          <div className="space-y-4">
            <Field label="Name">
              <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </Field>
            <Field label="Email">
              <Input type="email" disabled={!!form._id} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            </Field>
            <Field label={form._id ? 'New password (leave blank to keep)' : 'Password'} hint="Minimum 8 characters">
              <Input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} />
            </Field>
            <Field label="Role" hint={ROLE_HELP[form.role]}>
              <Select value={form.role} disabled={form._id === me._id} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                <option value="verifier">Verifier</option>
                <option value="manager">Manager</option>
                <option value="superadmin">Super admin</option>
              </Select>
            </Field>
          </div>
        )}
      </Modal>
    </div>
  )
}
