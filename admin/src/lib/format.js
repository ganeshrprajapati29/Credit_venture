export const inr = (n) =>
  n === undefined || n === null || n === ''
    ? '—'
    : `₹${Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`

export const date = (d) =>
  d ? new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '—'

export const dateTime = (d) =>
  d
    ? new Date(d).toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : '—'

export const title = (s = '') => String(s).replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())

export const STATUS_STYLE = {
  draft: 'bg-slate-100 text-slate-600',
  submitted: 'bg-blue-50 text-blue-700',
  under_review: 'bg-amber-50 text-amber-700',
  approved: 'bg-emerald-50 text-emerald-700',
  rejected: 'bg-rose-50 text-rose-700',
  disbursed: 'bg-indigo-50 text-indigo-700',
  closed: 'bg-teal-50 text-teal-700',
  cancelled: 'bg-slate-100 text-slate-500',
  pending: 'bg-amber-50 text-amber-700',
  verified: 'bg-emerald-50 text-emerald-700',
  paid: 'bg-emerald-50 text-emerald-700',
  overdue: 'bg-rose-50 text-rose-700',
  active: 'bg-emerald-50 text-emerald-700',
  blocked: 'bg-rose-50 text-rose-700',
  waived: 'bg-sky-50 text-sky-700',
  unpaid: 'bg-slate-100 text-slate-600',
}

export const LOAN_STATUSES = ['submitted', 'under_review', 'approved', 'disbursed', 'closed', 'rejected', 'cancelled', 'draft']
