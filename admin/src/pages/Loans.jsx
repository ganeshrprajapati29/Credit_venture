import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { Search } from 'lucide-react'
import { get, errMsg } from '../lib/api'
import { date, inr, LOAN_STATUSES, title } from '../lib/format'
import { Badge, Card, Empty, Input, Pagination, Spinner, Table, cx } from '../components/ui'

export default function Loans() {
  const [params, setParams] = useSearchParams()
  const status = params.get('status') || 'all'
  const page = Number(params.get('page') || 1)
  const [search, setSearch] = useState(params.get('search') || '')
  const [data, setData] = useState(null)
  const [err, setErr] = useState(null)

  useEffect(() => {
    setData(null)
    get('/admin/loans', { status, page, search: params.get('search') || undefined, limit: 20 })
      .then(setData)
      .catch((e) => setErr(errMsg(e)))
  }, [status, page, params])

  const update = (patch) => {
    const p = Object.fromEntries(params)
    Object.assign(p, patch)
    Object.keys(p).forEach((k) => (p[k] === '' || p[k] === undefined) && delete p[k])
    setParams(p)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {['all', ...LOAN_STATUSES].map((s) => (
          <button
            key={s}
            onClick={() => update({ status: s === 'all' ? '' : s, page: '' })}
            className={cx('rounded-full px-3.5 py-1.5 text-xs font-semibold transition cursor-pointer', status === s ? 'bg-brand-700 text-white' : 'bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50')}
          >
            {s === 'all' ? 'All (excl. drafts)' : title(s)}
          </button>
        ))}
      </div>

      <Card>
        <form
          onSubmit={(e) => {
            e.preventDefault()
            update({ search, page: '' })
          }}
          className="flex gap-2 border-b border-slate-100 p-4"
        >
          <div className="relative flex-1">
            <Search className="absolute left-3.5 top-3 size-4 text-slate-400" />
            <Input className="pl-10" placeholder="Search by name, mobile, loan no. or PAN" value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
        </form>
        {err ? (
          <p className="p-5 text-rose-600">{err}</p>
        ) : !data ? (
          <Spinner />
        ) : data.items.length === 0 ? (
          <Empty text="No applications found" />
        ) : (
          <>
            <Table head={['Applicant', 'Loan no.', 'Amount', 'Tenure / EMI', 'Income', 'Applied', 'Status']}>
              {data.items.map((l) => (
                <tr key={l._id} className="hover:bg-slate-50">
                  <td className="px-5 py-3">
                    <Link to={`/loans/${l._id}`} className="font-semibold text-slate-900 hover:text-brand-700">
                      {l.basic?.firstName ? `${l.basic.firstName} ${l.basic.lastName}` : l.user?.fullName || '—'}
                    </Link>
                    <p className="text-xs text-slate-500">+91 {l.user?.mobile}</p>
                  </td>
                  <td className="px-5 py-3 font-mono text-xs">{l.loanNumber}</td>
                  <td className="px-5 py-3 font-semibold">{inr(l.approved?.amount || l.offer?.amount)}</td>
                  <td className="px-5 py-3 text-xs">
                    {l.offer?.tenureMonths ? `${l.offer.tenureMonths} mo · ${inr(l.offer.emi)}` : '—'}
                  </td>
                  <td className="px-5 py-3">{inr(l.basic?.monthlyIncome)}</td>
                  <td className="px-5 py-3 text-xs text-slate-500">{date(l.submittedAt || l.createdAt)}</td>
                  <td className="px-5 py-3">
                    <Badge status={l.status} />
                    {l.status === 'draft' && <p className="mt-1 text-[11px] text-slate-400">at: {title(l.currentStep)}</p>}
                  </td>
                </tr>
              ))}
            </Table>
            <Pagination page={data.page} pages={data.pages} total={data.total} onChange={(p) => update({ page: String(p) })} />
          </>
        )}
      </Card>
    </div>
  )
}
