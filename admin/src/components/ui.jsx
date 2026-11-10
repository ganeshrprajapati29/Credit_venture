import { useEffect, useState } from 'react'
import { ChevronLeft, ChevronRight, FileText, Inbox, Loader2, X } from 'lucide-react'
import { fetchFileUrl } from '../lib/api'
import { STATUS_STYLE, title } from '../lib/format'

export const cx = (...c) => c.filter(Boolean).join(' ')

export function Button({ variant = 'primary', size = 'md', loading, icon: Icon, className, children, ...p }) {
  const v = {
    primary: 'bg-brand-700 text-white hover:bg-brand-800 shadow-sm shadow-brand-700/20',
    success: 'bg-accent-600 text-white hover:bg-emerald-700 shadow-sm',
    danger: 'bg-rose-600 text-white hover:bg-rose-700 shadow-sm',
    outline: 'border border-slate-200 bg-white text-slate-700 hover:bg-slate-50',
    ghost: 'text-slate-600 hover:bg-slate-100',
  }[variant]
  const s = { sm: 'h-8 px-3 text-xs', md: 'h-10 px-4 text-sm', lg: 'h-11 px-5 text-sm' }[size]
  return (
    <button
      className={cx('inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer', v, s, className)}
      disabled={loading || p.disabled}
      {...p}
    >
      {loading ? <Loader2 className="size-4 animate-spin" /> : Icon ? <Icon className="size-4" /> : null}
      {children}
    </button>
  )
}

export function Card({ className, children, title: t, action, ...p }) {
  return (
    <div className={cx('rounded-2xl border border-slate-200/70 bg-white shadow-sm', className)} {...p}>
      {(t || action) && (
        <div className="flex items-center justify-between gap-3 border-b border-slate-100 px-5 py-3.5">
          <h3 className="font-semibold text-slate-800">{t}</h3>
          {action}
        </div>
      )}
      {children}
    </div>
  )
}

export function Badge({ status, children, className }) {
  return (
    <span className={cx('inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap', STATUS_STYLE[status] || 'bg-slate-100 text-slate-600', className)}>
      {children || title(status)}
    </span>
  )
}

export function Field({ label, hint, error, children, className }) {
  return (
    <label className={cx('block', className)}>
      {label && <span className="mb-1.5 block text-xs font-semibold text-slate-600">{label}</span>}
      {children}
      {hint && !error && <span className="mt-1 block text-xs text-slate-400">{hint}</span>}
      {error && <span className="mt-1 block text-xs text-rose-600">{error}</span>}
    </label>
  )
}

const inputCls = 'w-full rounded-xl border border-slate-200 bg-white px-3.5 py-2.5 text-sm outline-none transition focus:border-brand-500 focus:ring-4 focus:ring-brand-100 disabled:bg-slate-50'

export const Input = ({ className, ...p }) => <input className={cx(inputCls, className)} {...p} />
export const Textarea = ({ className, ...p }) => <textarea className={cx(inputCls, 'min-h-24', className)} {...p} />
export const Select = ({ className, children, ...p }) => (
  <select className={cx(inputCls, 'pr-8', className)} {...p}>
    {children}
  </select>
)

export function Toggle({ checked, onChange, label }) {
  return (
    <button type="button" onClick={() => onChange(!checked)} className="inline-flex items-center gap-3 cursor-pointer">
      <span className={cx('relative h-6 w-11 rounded-full transition', checked ? 'bg-accent-500' : 'bg-slate-300')}>
        <span className={cx('absolute top-0.5 size-5 rounded-full bg-white shadow transition', checked ? 'left-5.5' : 'left-0.5')} />
      </span>
      {label && <span className="text-sm text-slate-700">{label}</span>}
    </button>
  )
}

export function Spinner({ className }) {
  return (
    <div className={cx('flex items-center justify-center py-16', className)}>
      <Loader2 className="size-7 animate-spin text-brand-600" />
    </div>
  )
}

export function Empty({ text = 'Nothing here yet', icon: Icon = Inbox }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 py-14 text-slate-400">
      <Icon className="size-10" />
      <p className="text-sm">{text}</p>
    </div>
  )
}

export function Modal({ open, onClose, title: t, children, footer, wide }) {
  useEffect(() => {
    if (!open) return
    const onKey = (e) => e.key === 'Escape' && onClose?.()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])
  if (!open) return null
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-slate-900/50 p-0 backdrop-blur-sm sm:items-center sm:p-4" onClick={onClose}>
      <div className={cx('max-h-[92vh] w-full overflow-auto rounded-t-2xl bg-white shadow-2xl sm:rounded-2xl scroll-thin', wide ? 'sm:max-w-3xl' : 'sm:max-w-lg')} onClick={(e) => e.stopPropagation()}>
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-slate-100 bg-white px-5 py-4">
          <h3 className="text-base font-bold">{t}</h3>
          <button onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:bg-slate-100 cursor-pointer">
            <X className="size-5" />
          </button>
        </div>
        <div className="p-5">{children}</div>
        {footer && <div className="sticky bottom-0 flex justify-end gap-2 border-t border-slate-100 bg-white px-5 py-3">{footer}</div>}
      </div>
    </div>
  )
}

export function Stat({ label, value, icon: Icon, tone = 'brand', sub }) {
  const tones = {
    brand: 'bg-brand-50 text-brand-700',
    green: 'bg-emerald-50 text-emerald-600',
    amber: 'bg-amber-50 text-amber-600',
    rose: 'bg-rose-50 text-rose-600',
    violet: 'bg-violet-50 text-violet-600',
    sky: 'bg-sky-50 text-sky-600',
  }
  return (
    <Card className="p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</p>
          <p className="mt-2 truncate text-2xl font-extrabold text-slate-900">{value}</p>
          {sub && <p className="mt-1 text-xs text-slate-500">{sub}</p>}
        </div>
        {Icon && (
          <span className={cx('grid size-11 shrink-0 place-items-center rounded-xl', tones[tone])}>
            <Icon className="size-5" />
          </span>
        )}
      </div>
    </Card>
  )
}

export function Pagination({ page, pages, onChange, total }) {
  if (!pages || pages <= 1) return total ? <p className="px-5 py-3 text-xs text-slate-500">{total} record(s)</p> : null
  return (
    <div className="flex items-center justify-between gap-3 border-t border-slate-100 px-5 py-3 text-sm">
      <span className="text-xs text-slate-500">
        Page {page} of {pages} · {total} records
      </span>
      <div className="flex gap-2">
        <Button size="sm" variant="outline" icon={ChevronLeft} disabled={page <= 1} onClick={() => onChange(page - 1)}>
          Prev
        </Button>
        <Button size="sm" variant="outline" disabled={page >= pages} onClick={() => onChange(page + 1)}>
          Next <ChevronRight className="size-4" />
        </Button>
      </div>
    </div>
  )
}

export function Table({ head, children }) {
  return (
    <div className="overflow-x-auto scroll-thin">
      <table className="w-full min-w-[720px] text-left text-sm">
        <thead>
          <tr className="border-b border-slate-100 bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
            {head.map((h) => (
              <th key={h} className="px-5 py-3 font-semibold whitespace-nowrap">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">{children}</tbody>
      </table>
    </div>
  )
}

/** Shows a private (auth protected) document with preview + open-in-new-tab. */
export function SecureFile({ file, label }) {
  const [url, setUrl] = useState(null)
  const [err, setErr] = useState(false)
  const [zoom, setZoom] = useState(false)
  useEffect(() => {
    let u
    let alive = true
    if (file?.filename) {
      fetchFileUrl(file.filename)
        .then((x) => {
          u = x
          if (alive) setUrl(x)
        })
        .catch(() => alive && setErr(true))
    }
    return () => {
      alive = false
      if (u) URL.revokeObjectURL(u)
    }
  }, [file?.filename])

  const isPdf = file?.mimeType === 'application/pdf'
  return (
    <div className="overflow-hidden rounded-xl border border-slate-200 bg-slate-50">
      <div className="flex h-40 items-center justify-center bg-slate-100">
        {!file?.filename ? (
          <span className="text-xs text-slate-400">Not uploaded</span>
        ) : err ? (
          <span className="text-xs text-rose-500">Could not load</span>
        ) : !url ? (
          <Loader2 className="size-5 animate-spin text-slate-400" />
        ) : isPdf ? (
          <a href={url} target="_blank" rel="noreferrer" className="flex flex-col items-center gap-1 text-brand-700">
            <FileText className="size-10" />
            <span className="text-xs font-semibold">Open PDF</span>
          </a>
        ) : (
          <img src={url} alt={label} onClick={() => setZoom(true)} className="h-full w-full cursor-zoom-in object-cover" />
        )}
      </div>
      <div className="flex items-center justify-between px-3 py-2">
        <span className="text-xs font-semibold text-slate-600">{label}</span>
        {url && (
          <a href={url} target="_blank" rel="noreferrer" className="text-xs font-semibold text-brand-700 hover:underline">
            Open
          </a>
        )}
      </div>
      {zoom && url && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4" onClick={() => setZoom(false)}>
          <img src={url} alt={label} className="max-h-full max-w-full rounded-lg" />
        </div>
      )}
    </div>
  )
}

export function KV({ label, value, mono }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs font-medium text-slate-500">{label}</dt>
      <dd className={cx('mt-0.5 break-words text-sm font-semibold text-slate-800', mono && 'font-mono')}>{value ?? '—'}</dd>
    </div>
  )
}
