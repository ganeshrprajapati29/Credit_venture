import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { Search } from 'lucide-react'
import { get, errMsg } from '../lib/api'
import { date, inr, LOAN_STATUSES, title } from '../lib/format'
import { Badge, Card, Empty, Input, Pagination, Select, Spinner, Table, cx } from '../components/ui'

export default function Loans() {
  const [params, setParams] = useSearchParams()
  const feeStatus = params.get('feeStatus') || ''
  const status = feeStatus ? 'fee' : params.get('status') || 'all'
  const product = params.get('product') || 'all'
  const [products, setProducts] = useState([])
  useEffect(() => {
    get('/admin/settings').then((d) => setProducts(d.settings.loanProducts || [])).catch(() => {})
  }, [])
  const page = Number(params.get('page') || 1)
  const [search, setSearch] = useState(params.get('search') || '')
  const [data, setData] = useState(null)
  const [err, setErr] = useState(null)

  useEffect(() => {
    setData(null)
    get('/admin/loans', { status: feeStatus ? undefined : status, feeStatus: feeStatus || undefined, product, page, search: params.get('search') || undefined, limit: 20 })
      .then(setData)
      .catch((e) => setErr(errMsg(e)))
  }, [status, feeStatus, product, page, params])

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
            onClick={() => update({ status: s === 'all' ? '' : s, feeStatus: '', page: '' })}
            className={cx('rounded-full px-3.5 py-1.5 text-xs font-semibold transition cursor-pointer', status === s ? 'bg-brand-700 text-white' : 'bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50')}
          >
            {s === 'all' ? 'All (excl. drafts)' : title(s)}
          </button>
        ))}
        <button
          onClick={() => update({ feeStatus: 'submitted', status: '', page: '' })}
          className={cx('rounded-full px-3.5 py-1.5 text-xs font-semibold transition cursor-pointer', status === 'fee' ? 'bg-amber-500 text-white' : 'bg-amber-50 text-amber-700 ring-1 ring-amber-200 hover:bg-amber-100')}
        >
          Processing fee to verify
        </button>
      </div>

      <Card>
        <form
          onSubmit={(e) => {
            e.preventDefault()
            update({ search, page: '' })
          }}
          className="flex gap-2 border-b border-slate-100 p-4"
        >
          <Select className="w-44" value={product} onChange={(e) => update({ product: e.target.value === 'all' ? '' : e.target.value, page: '' })}>
            <option value="all">All loan types</option>
            {products.map((p) => (
              <option key={p.key} value={p.key}>
                {p.name}
              </option>
            ))}
          </Select>
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
            <Table head={['Applicant', 'Loan type', 'Loan no.', 'Amount', 'Tenure / EMI', 'Income', 'Applied', 'Status']}>
              {data.items.map((l) => (
                <tr key={l._id} className="hover:bg-slate-50">
                  <td className="px-5 py-3">
                    <Link to={`/loans/${l._id}`} className="font-semibold text-slate-900 hover:text-brand-700">
                      {l.basic?.firstName ? `${l.basic.firstName} ${l.basic.lastName}` : l.user?.fullName || '—'}
                    </Link>
                    <p className="text-xs text-slate-500">+91 {l.user?.mobile}</p>
                  </td>
                  <td className="px-5 py-3 text-xs font-semibold text-brand-700">{l.productName || 'Personal Loan'}</td>
                  <td className="px-5 py-3 font-mono text-xs">{l.loanNumber}</td>
                  <td className="px-5 py-3 font-semibold">{inr(l.approved?.amount || l.offer?.amount)}</td>
                  <td className="px-5 py-3 text-xs">
                    {l.offer?.tenureMonths ? `${l.offer.tenureMonths} mo · ${inr(l.offer.emi)}` : '—'}
                  </td>
                  <td className="px-5 py-3">{inr(l.basic?.monthlyIncome)}</td>
                  <td className="px-5 py-3 text-xs text-slate-500">{date(l.submittedAt || l.createdAt)}</td>
                  <td className="px-5 py-3">
                    <Badge status={l.status} />
                    {l.status === 'approved' && l.feePayment?.status && (
                      <p className="mt-1 text-[11px] font-semibold text-amber-700">
                        Fee: {{ unpaid: 'awaiting payment', submitted: 'to verify', verified: 'verified', rejected: 'rejected', waived: 'waived' }[l.feePayment.status]}
                      </p>
                    )}
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
