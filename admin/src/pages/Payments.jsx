import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import toast from 'react-hot-toast'
import { Check, Search, X } from 'lucide-react'
import { get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { dateTime, inr, title } from '../lib/format'
import { Badge, Button, Card, Empty, Field, Input, Modal, Pagination, SecureFile, Spinner, Table, Textarea, cx } from '../components/ui'

export default function Payments() {
  const { can } = useAuth()
  const [status, setStatus] = useState('pending')
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [q, setQ] = useState('')
  const [data, setData] = useState(null)
  const [sel, setSel] = useState(null)
  const [remarks, setRemarks] = useState('')
  const [busy, setBusy] = useState(false)

  const load = useCallback(() => {
    setData(null)
    get('/admin/payments', { status, page, search: q || undefined })
      .then(setData)
      .catch((e) => toast.error(errMsg(e)))
  }, [status, page, q])
  useEffect(load, [load])

  const review = async (st) => {
    setBusy(true)
    try {
      const r = await send('patch', `/admin/payments/${sel._id}`, { status: st, remarks })
      toast.success(r.message)
      setSel(null)
      load()
    } catch (e) {
      toast.error(errMsg(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {['pending', 'verified', 'rejected', 'all'].map((s) => (
          <button
            key={s}
            onClick={() => {
              setStatus(s)
              setPage(1)
            }}
            className={cx('rounded-full px-3.5 py-1.5 text-xs font-semibold cursor-pointer', status === s ? 'bg-brand-700 text-white' : 'bg-white text-slate-600 ring-1 ring-slate-200')}
          >
            {title(s)}
          </button>
        ))}
      </div>
      <Card>
        <form
          className="flex gap-2 border-b border-slate-100 p-4"
          onSubmit={(e) => {
            e.preventDefault()
            setQ(search)
            setPage(1)
          }}
        >
          <div className="relative flex-1">
            <Search className="absolute left-3.5 top-3 size-4 text-slate-400" />
            <Input className="pl-10" placeholder="Search UTR" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
        </form>
        {!data ? (
          <Spinner />
        ) : data.items.length === 0 ? (
          <Empty text="No payments" />
        ) : (
          <>
            <Table head={['Customer', 'Loan', 'EMI #', 'Amount', 'UTR / Mode', 'Submitted', 'Status', '']}>
              {data.items.map((p) => (
                <tr key={p._id} className="hover:bg-slate-50">
                  <td className="px-5 py-3">
                    <p className="font-semibold">{p.user?.fullName || '—'}</p>
                    <p className="text-xs text-slate-500">+91 {p.user?.mobile}</p>
                  </td>
                  <td className="px-5 py-3">
                    <Link className="font-mono text-xs text-brand-700" to={`/loans/${p.loan?._id}`}>
                      {p.loan?.loanNumber}
                    </Link>
                  </td>
                  <td className="px-5 py-3">{p.installmentNo || 'Auto'}</td>
                  <td className="px-5 py-3 font-semibold">{inr(p.amount)}</td>
                  <td className="px-5 py-3">
                    <p className="font-mono text-xs">{p.utr}</p>
                    <p className="text-xs uppercase text-slate-400">{p.mode}</p>
                  </td>
                  <td className="px-5 py-3 text-xs text-slate-500">{dateTime(p.createdAt)}</td>
                  <td className="px-5 py-3">
                    <Badge status={p.status} />
                  </td>
                  <td className="px-5 py-3 text-right">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => {
                        setSel(p)
                        setRemarks('')
                      }}
                    >
                      {p.status === 'pending' ? 'Review' : 'View'}
                    </Button>
                  </td>
                </tr>
              ))}
            </Table>
            <Pagination page={data.page} pages={data.pages} total={data.total} onChange={setPage} />
          </>
        )}
      </Card>

      <Modal
        open={!!sel}
        onClose={() => setSel(null)}
        title="Payment proof"
        footer={
          sel?.status === 'pending' &&
          can('superadmin', 'manager') && (
            <>
              <Button variant="danger" icon={X} loading={busy} onClick={() => review('rejected')}>
                Reject
              </Button>
              <Button variant="success" icon={Check} loading={busy} onClick={() => review('verified')}>
                Verify payment
              </Button>
            </>
          )
        }
      >
        {sel && (
          <div className="space-y-4">
            <SecureFile file={sel.proof} label="Screenshot" />
            <div className="grid grid-cols-2 gap-3 text-sm">
              <p>
                <span className="text-slate-500">Amount:</span> <b>{inr(sel.amount)}</b>
              </p>
              <p>
                <span className="text-slate-500">UTR:</span> <b className="font-mono">{sel.utr}</b>
              </p>
              <p>
                <span className="text-slate-500">EMI #:</span> <b>{sel.installmentNo || 'Next due'}</b>
              </p>
              <p>
                <span className="text-slate-500">Status:</span> <Badge status={sel.status} />
              </p>
            </div>
            {sel.remarks && <p className="rounded-lg bg-slate-50 p-3 text-sm">{sel.remarks}</p>}
            {sel.status === 'pending' && (
              <Field label="Remarks (required for rejection)">
                <Textarea value={remarks} onChange={(e) => setRemarks(e.target.value)} />
              </Field>
            )}
            <p className="text-xs text-slate-500">Match the UTR and amount with your bank statement before verifying.</p>
          </div>
        )}
      </Modal>
    </div>
  )
}
