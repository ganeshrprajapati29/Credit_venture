import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import toast from 'react-hot-toast'
import { Search } from 'lucide-react'
import { get, errMsg } from '../lib/api'
import { date } from '../lib/format'
import { Badge, Card, Empty, Input, Pagination, Spinner, Table } from '../components/ui'

export default function Users() {
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [q, setQ] = useState('')
  const [data, setData] = useState(null)

  useEffect(() => {
    setData(null)
    get('/admin/users', { page, search: q || undefined })
      .then(setData)
      .catch((e) => toast.error(errMsg(e)))
  }, [page, q])

  return (
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
          <Input className="pl-10" placeholder="Search by name, mobile or email" value={search} onChange={(e) => setSearch(e.target.value)} />
        </div>
      </form>
      {!data ? (
        <Spinner />
      ) : data.items.length === 0 ? (
        <Empty text="No customers yet" />
      ) : (
        <>
          <Table head={['Customer', 'Email', 'Device', 'Loans', 'Last status', 'Joined', 'Account']}>
            {data.items.map((u) => (
              <tr key={u._id} className="hover:bg-slate-50">
                <td className="px-5 py-3">
                  <Link to={`/users/${u._id}`} className="font-semibold hover:text-brand-700">
                    {u.fullName || 'New user'}
                  </Link>
                  <p className="text-xs text-slate-500">+91 {u.mobile}</p>
                </td>
                <td className="px-5 py-3 text-xs">{u.email || '—'}</td>
                <td className="px-5 py-3 text-xs text-slate-500">{[u.device?.brand, u.device?.model].filter(Boolean).join(' ') || '—'}</td>
                <td className="px-5 py-3 font-semibold">{u.loans}</td>
                <td className="px-5 py-3">{u.lastStatus ? <Badge status={u.lastStatus} /> : '—'}</td>
                <td className="px-5 py-3 text-xs text-slate-500">{date(u.createdAt)}</td>
                <td className="px-5 py-3">
                  <Badge status={u.status} />
                </td>
              </tr>
            ))}
          </Table>
          <Pagination page={data.page} pages={data.pages} total={data.total} onChange={setPage} />
        </>
      )}
    </Card>
  )
}
