import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'
import { ChevronDown, Plus, Save, Trash2, X } from 'lucide-react'
import { api, get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { inr, title } from '../lib/format'
import { Button, Card, Field, Input, Select, Spinner, Textarea, Toggle, cx } from '../components/ui'

const TABS = ['Loan products', 'Fee payment QR', 'Pricing defaults', 'Company & support', 'Repayment', 'Dropdown options', 'Legal', 'App']

export default function Settings() {
  const { can } = useAuth()
  const [s, setS] = useState(null)
  const [tab, setTab] = useState(TABS[0])
  const [busy, setBusy] = useState(false)
  const [qrUrl, setQrUrl] = useState(null)
  const readOnly = !can('superadmin')

  useEffect(() => {
    get('/admin/settings')
      .then((d) => {
        setS(d.settings)
        setQrUrl(d.feeQrUrl)
      })
      .catch((e) => toast.error(errMsg(e)))
  }, [])

  const set = (k, v) => setS((p) => ({ ...p, [k]: v }))
  const setNested = (obj, k, v) => setS((p) => ({ ...p, [obj]: { ...(p[obj] || {}), [k]: v } }))

  const save = async () => {
    setBusy(true)
    try {
      const r = await send('put', '/admin/settings', s)
      setS(r.data.settings)
      toast.success('Settings saved – app will pick them up instantly')
    } catch (e) {
      toast.error(errMsg(e))
    } finally {
      setBusy(false)
    }
  }

  const example = useMemo(() => {
    if (!s) return null
    const P = 50000
    const n = s.tenureOptions?.[0] || 3
    const r = s.interestRate / 12 / 100
    const emi = r ? Math.ceil((P * r * (1 + r) ** n) / ((1 + r) ** n - 1)) : Math.ceil(P / n)
    const fee = Math.max(s.minProcessingFee, (P * s.processingFeePercent) / 100)
    return { P, n, emi, fee: Math.round(fee * (1 + s.gstPercent / 100)) }
  }, [s])

  if (!s) return <Spinner />

  const num = (k, label, hint, step = 1) => (
    <Field label={label} hint={hint}>
      <Input type="number" step={step} disabled={readOnly} value={s[k] ?? ''} onChange={(e) => set(k, e.target.value === '' ? '' : Number(e.target.value))} />
    </Field>
  )
  const txt = (k, label, hint) => (
    <Field label={label} hint={hint}>
      <Input disabled={readOnly} value={s[k] ?? ''} onChange={(e) => set(k, e.target.value)} />
    </Field>
  )

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-2">
          {TABS.map((t) => (
            <button key={t} onClick={() => setTab(t)} className={cx('rounded-full px-3.5 py-1.5 text-xs font-semibold cursor-pointer', tab === t ? 'bg-brand-700 text-white' : 'bg-white text-slate-600 ring-1 ring-slate-200')}>
              {t}
            </button>
          ))}
        </div>
        {!readOnly && (
          <Button icon={Save} loading={busy} onClick={save}>
            Save changes
          </Button>
        )}
      </div>
      {readOnly && <p className="rounded-xl bg-amber-50 px-4 py-2 text-sm text-amber-700">Only a super admin can change settings.</p>}

      {tab === 'Loan products' && <ProductsEditor products={s.loanProducts || []} readOnly={readOnly} onChange={(v) => set('loanProducts', v)} />}

      {tab === 'Fee payment QR' && (
        <Card>
          <div className="grid gap-6 p-5 lg:grid-cols-3">
            <div className="space-y-5 lg:col-span-2">
              <p className="rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-800">
                After approval the customer pays the processing fee by scanning this QR in the app, then uploads the screenshot + UTR. You verify it in the loan page before disbursal.
                {!s.feePayment?.upiId && !qrUrl && <b> Right now the app shows a DEMO QR – add your UPI ID or upload your QR to go live.</b>}
              </p>
              <Field label="UPI ID" hint="e.g. yourbusiness@okaxis – the app generates a QR with the exact fee amount from this">
                <Input disabled={readOnly} value={s.feePayment?.upiId || ''} onChange={(e) => setNested('feePayment', 'upiId', e.target.value.trim())} />
              </Field>
              <Field label="Payee name">
                <Input disabled={readOnly} value={s.feePayment?.payeeName || ''} onChange={(e) => setNested('feePayment', 'payeeName', e.target.value)} />
              </Field>
              <Field label="Instructions shown in app">
                <Textarea disabled={readOnly} value={s.feePayment?.instructions || ''} onChange={(e) => setNested('feePayment', 'instructions', e.target.value)} />
              </Field>
            </div>
            <div>
              <p className="mb-2 text-xs font-semibold text-slate-600">QR image (optional)</p>
              <div className="flex aspect-square items-center justify-center overflow-hidden rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50">
                {qrUrl ? <img src={qrUrl} alt="Payment QR" className="h-full w-full object-contain" /> : <span className="px-6 text-center text-xs text-slate-400">No image. The app will generate a QR from the UPI ID (or a demo QR).</span>}
              </div>
              {!readOnly && (
                <div className="mt-3 flex gap-2">
                  <label className="flex-1">
                    <span className="inline-flex h-9 w-full cursor-pointer items-center justify-center rounded-xl bg-brand-700 text-xs font-semibold text-white hover:bg-brand-800">Upload QR</span>
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp"
                      className="hidden"
                      onChange={async (e) => {
                        const f = e.target.files?.[0]
                        if (!f) return
                        const fd = new FormData()
                        fd.append('image', f)
                        try {
                          const r = await api.post('/admin/settings/fee-qr', fd)
                          setQrUrl(r.data.data.feeQrUrl)
                          toast.success('QR uploaded')
                        } catch (err) {
                          toast.error(errMsg(err))
                        }
                      }}
                    />
                  </label>
                  {qrUrl && (
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={async () => {
                        await api.delete('/admin/settings/fee-qr')
                        setQrUrl(null)
                        toast.success('QR removed')
                      }}
                    >
                      Remove
                    </Button>
                  )}
                </div>
              )}
              <p className="mt-2 text-[11px] text-slate-400">Upload + Save are separate: the image saves instantly, the text fields save with “Save changes”.</p>
            </div>
          </div>
        </Card>
      )}

      {tab === 'Pricing defaults' && (
        <Card>
          <div className="grid gap-5 p-5 sm:grid-cols-2 lg:grid-cols-3">
            {num('minLoanAmount', 'Minimum loan amount (₹)')}
            {num('maxLoanAmount', 'Maximum loan amount (₹)')}
            {num('amountStep', 'Amount slider step (₹)')}
            {num('incomeMultiplier', 'Income multiplier', 'Max eligible = monthly income × this', 0.05)}
            {num('minMonthlyIncome', 'Minimum monthly income (₹)')}
            {num('interestRate', 'Interest rate (% per annum)', 'Reducing balance', 0.1)}
            {num('processingFeePercent', 'Processing fee (%)', null, 0.1)}
            {num('minProcessingFee', 'Minimum processing fee (₹)')}
            {num('gstPercent', 'GST on fee (%)')}
            {num('minAge', 'Minimum age')}
            {num('maxAge', 'Maximum age')}
            {num('latePaymentFeePerDay', 'Late fee per day (₹)')}
            <Field label="Tenure options (months)" hint="Comma separated, e.g. 3, 6, 9, 12" className="sm:col-span-2">
              <Input
                disabled={readOnly}
                value={(s.tenureOptions || []).join(', ')}
                onChange={(e) =>
                  set(
                    'tenureOptions',
                    e.target.value
                      .split(',')
                      .map((x) => Number(x.trim()))
                      .filter((x) => x > 0)
                  )
                }
              />
            </Field>
            <div className="flex items-end">
              <Toggle checked={!!s.acceptingApplications} onChange={(v) => !readOnly && set('acceptingApplications', v)} label="Accepting new applications" />
            </div>
          </div>
          {example && (
            <p className="border-t border-slate-100 bg-slate-50 px-5 py-3 text-sm text-slate-600">
              Example: {inr(example.P)} for {example.n} months → EMI <b>{inr(example.emi)}</b>, processing fee incl. GST <b>{inr(example.fee)}</b>
            </p>
          )}
        </Card>
      )}

      {tab === 'Company & support' && (
        <Card>
          <div className="grid gap-5 p-5 sm:grid-cols-2">
            {txt('appName', 'App name')}
            {txt('tagline', 'Tagline')}
            {txt('companyName', 'Company legal name')}
            {txt('lendingPartner', 'Lending partner (RBI regulated NBFC / bank)', 'Shown to customers as required by RBI digital lending rules')}
            {txt('nbfcRegistration', 'NBFC / CoR registration no.')}
            {txt('supportPhone', 'Support phone')}
            {txt('supportEmail', 'Support email')}
            {txt('supportWhatsapp', 'WhatsApp number')}
            {txt('supportHours', 'Support hours')}
            <Field label="Office address" className="sm:col-span-2">
              <Textarea disabled={readOnly} value={s.officeAddress || ''} onChange={(e) => set('officeAddress', e.target.value)} />
            </Field>
            <p className="text-sm font-bold text-slate-700 sm:col-span-2">Grievance redressal officer</p>
            {['name', 'email', 'phone'].map((k) => (
              <Field key={k} label={title(k)}>
                <Input disabled={readOnly} value={s.grievanceOfficer?.[k] || ''} onChange={(e) => setNested('grievanceOfficer', k, e.target.value)} />
              </Field>
            ))}
          </div>
        </Card>
      )}

      {tab === 'Repayment' && (
        <Card>
          <div className="grid gap-5 p-5 sm:grid-cols-2">
            <p className="text-sm text-slate-500 sm:col-span-2">Customers pay EMIs manually to this account / UPI and upload the screenshot + UTR in the app.</p>
            {[
              ['accountName', 'Account name'],
              ['accountNumber', 'Account number'],
              ['ifsc', 'IFSC'],
              ['bankName', 'Bank name'],
              ['upiId', 'UPI ID'],
            ].map(([k, l]) => (
              <Field key={k} label={l}>
                <Input disabled={readOnly} value={s.repayment?.[k] || ''} onChange={(e) => setNested('repayment', k, e.target.value)} />
              </Field>
            ))}
            <Field label="Instructions shown in app" className="sm:col-span-2">
              <Textarea disabled={readOnly} value={s.repayment?.instructions || ''} onChange={(e) => setNested('repayment', 'instructions', e.target.value)} />
            </Field>
          </div>
        </Card>
      )}

      {tab === 'Dropdown options' && <OptionsEditor options={s.options || {}} readOnly={readOnly} onChange={(o) => set('options', o)} />}

      {tab === 'Legal' && (
        <Card>
          <div className="grid gap-5 p-5">
            {txt('termsUrl', 'Terms of service URL', 'If set, the app opens this link. Otherwise the text below is shown.')}
            {txt('privacyUrl', 'Privacy policy URL')}
            <Field label="Terms of service text">
              <Textarea className="min-h-48" disabled={readOnly} value={s.termsText || ''} onChange={(e) => set('termsText', e.target.value)} />
            </Field>
            <Field label="Privacy policy text">
              <Textarea className="min-h-48" disabled={readOnly} value={s.privacyText || ''} onChange={(e) => set('privacyText', e.target.value)} />
            </Field>
          </div>
        </Card>
      )}

      {tab === 'App' && (
        <Card>
          <div className="grid gap-5 p-5 sm:grid-cols-2">
            {txt('latestAppVersion', 'Latest app version', 'e.g. 1.0.1 – users on older versions see an update prompt')}
            {txt('minAppVersion', 'Minimum supported version', 'Older versions are forced to update')}
            {txt('apkUrl', 'APK download URL')}
            <Field label="Login OTP mode" hint="Demo shows the OTP on the app screen. SMS needs SMS_PROVIDER keys in backend .env.">
              <Select disabled={readOnly} value={s.otpMode || 'demo'} onChange={(e) => set('otpMode', e.target.value)}>
                <option value="demo">Demo – show OTP on screen</option>
                <option value="sms">SMS – send real OTP</option>
              </Select>
            </Field>
            <div className="flex items-end">
              <Toggle checked={!!s.maintenanceMode} onChange={(v) => !readOnly && set('maintenanceMode', v)} label="Maintenance mode" />
            </div>
            <Field label="Maintenance message" className="sm:col-span-2">
              <Textarea disabled={readOnly} value={s.maintenanceMessage || ''} onChange={(e) => set('maintenanceMessage', e.target.value)} />
            </Field>
          </div>
        </Card>
      )}
    </div>
  )
}

function OptionsEditor({ options, onChange, readOnly }) {
  const [draft, setDraft] = useState({})
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {Object.entries(options).map(([key, values]) => (
        <Card key={key} title={title(key.replace(/([A-Z])/g, ' $1'))}>
          <div className="flex flex-wrap gap-2 p-4">
            {values.map((v) => (
              <span key={v} className="inline-flex items-center gap-1 rounded-full bg-slate-100 py-1 pl-3 pr-1.5 text-xs font-medium">
                {v}
                {!readOnly && (
                  <button className="rounded-full p-0.5 hover:bg-slate-200 cursor-pointer" onClick={() => onChange({ ...options, [key]: values.filter((x) => x !== v) })}>
                    <X className="size-3" />
                  </button>
                )}
              </span>
            ))}
          </div>
          {!readOnly && (
            <form
              className="flex gap-2 border-t border-slate-100 p-3"
              onSubmit={(e) => {
                e.preventDefault()
                const v = (draft[key] || '').trim()
                if (!v || values.includes(v)) return
                onChange({ ...options, [key]: [...values, v] })
                setDraft({ ...draft, [key]: '' })
              }}
            >
              <Input className="h-9 py-1.5" placeholder="Add option" value={draft[key] || ''} onChange={(e) => setDraft({ ...draft, [key]: e.target.value })} />
              <Button size="sm" type="submit" icon={Plus} className="h-9">
                Add
              </Button>
            </form>
          )}
        </Card>
      ))}
    </div>
  )
}

const STEP_LABELS = {
  basic: 'Basic details',
  offer: 'Offer',
  personal: 'Personal',
  product: 'Category details',
  employment: 'Employment',
  address: 'Address',
  kyc: 'KYC',
  bank: 'Bank',
  review: 'Review & sign',
}
const LOCKED_STEPS = ['basic', 'offer', 'kyc', 'bank', 'review']

function ProductsEditor({ products, onChange, readOnly }) {
  const [open, setOpen] = useState(products[0]?.key)
  const upd = (i, patch) => onChange(products.map((p, j) => (j === i ? { ...p, ...patch } : p)))
  const updField = (i, fi, patch) => upd(i, { fields: products[i].fields.map((f, j) => (j === fi ? { ...f, ...patch } : f)) })

  return (
    <div className="space-y-3">
      <p className="text-sm text-slate-500">Each loan type has its own limits, pricing, steps and form. Changes reach the app instantly after saving.</p>
      {products.map((p, i) => {
        const isOpen = open === p.key
        const num = (k, label, hint, step = 1) => (
          <Field label={label} hint={hint}>
            <Input type="number" step={step} disabled={readOnly} value={p[k] ?? ''} onChange={(e) => upd(i, { [k]: e.target.value === '' ? '' : Number(e.target.value) })} />
          </Field>
        )
        return (
          <Card key={p.key}>
            <button type="button" onClick={() => setOpen(isOpen ? null : p.key)} className="flex w-full items-center gap-3 px-5 py-4 text-left cursor-pointer">
              <span className="size-3 rounded-full" style={{ background: p.color || '#0F4F3C' }} />
              <span className="flex-1">
                <span className="font-bold">{p.name}</span>
                <span className="ml-2 text-xs text-slate-500">
                  {p.interestRate}% · ₹{Number(p.minAmount).toLocaleString('en-IN')} – ₹{Number(p.maxAmount).toLocaleString('en-IN')}
                </span>
              </span>
              <span className={cx('rounded-full px-2.5 py-0.5 text-xs font-semibold', p.active !== false ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-500')}>
                {p.active !== false ? 'Live' : 'Hidden'}
              </span>
              <ChevronDown className={cx('size-5 text-slate-400 transition', isOpen && 'rotate-180')} />
            </button>
            {isOpen && (
              <div className="space-y-6 border-t border-slate-100 p-5">
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                  <Field label="Name">
                    <Input disabled={readOnly} value={p.name || ''} onChange={(e) => upd(i, { name: e.target.value })} />
                  </Field>
                  <Field label="Tagline" className="lg:col-span-2">
                    <Input disabled={readOnly} value={p.tagline || ''} onChange={(e) => upd(i, { tagline: e.target.value })} />
                  </Field>
                  <div className="flex items-end gap-3">
                    <input type="color" disabled={readOnly} value={p.color || '#0F4F3C'} onChange={(e) => upd(i, { color: e.target.value })} className="h-10 w-12 cursor-pointer rounded-lg border border-slate-200" />
                    <Toggle checked={p.active !== false} onChange={(v) => !readOnly && upd(i, { active: v })} label="Show in app" />
                  </div>
                  {num('minAmount', 'Min amount (₹)')}
                  {num('maxAmount', 'Max amount (₹)')}
                  {num('amountStep', 'Slider step (₹)')}
                  {num('incomeMultiplier', 'Income multiplier', 'Max = income × this', 0.1)}
                  {num('minMonthlyIncome', 'Min monthly income (₹)')}
                  {num('interestRate', 'Interest (% p.a.)', null, 0.05)}
                  {num('processingFeePercent', 'Processing fee (%)', null, 0.05)}
                  {num('minProcessingFee', 'Min processing fee (₹)')}
                  {num('order', 'Display order')}
                  <Field label="Tenure options (months)" hint="Comma separated, e.g. 12, 24, 36" className="sm:col-span-2">
                    <Input
                      disabled={readOnly}
                      value={(p.tenureOptions || []).join(', ')}
                      onChange={(e) => upd(i, { tenureOptions: e.target.value.split(',').map((x) => Number(x.trim())).filter((x) => x > 0) })}
                    />
                  </Field>
                  <Field label="Income field label" className="sm:col-span-2">
                    <Input disabled={readOnly} value={p.incomeLabel || ''} onChange={(e) => upd(i, { incomeLabel: e.target.value })} />
                  </Field>
                </div>

                <Field label="Status steps shown to customer while pending" hint="Comma separated, in order. You move the application through these from the loan page.">
                  <Input
                    disabled={readOnly}
                    value={(p.reviewSteps || []).join(', ')}
                    onChange={(e) => upd(i, { reviewSteps: e.target.value.split(',').map((x) => x.trim()).filter(Boolean) })}
                  />
                </Field>

                <div>
                  <p className="mb-2 text-sm font-bold text-slate-700">Application steps</p>
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(STEP_LABELS).map(([k, l]) => {
                      const on = (p.steps || []).includes(k)
                      const locked = LOCKED_STEPS.includes(k)
                      return (
                        <button
                          key={k}
                          type="button"
                          disabled={readOnly || locked}
                          onClick={() => upd(i, { steps: on ? p.steps.filter((x) => x !== k) : [...(p.steps || []), k] })}
                          className={cx('rounded-full px-3 py-1.5 text-xs font-semibold ring-1 cursor-pointer disabled:cursor-default', on ? 'bg-brand-700 text-white ring-brand-700' : 'bg-white text-slate-500 ring-slate-200')}
                        >
                          {l}
                        </button>
                      )
                    })}
                  </div>
                </div>

                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <p className="text-sm font-bold text-slate-700">Category form fields {(p.steps || []).includes('product') ? '' : '(enable “Category details” step to show)'}</p>
                    {!readOnly && (
                      <Button size="sm" variant="outline" icon={Plus} onClick={() => upd(i, { fields: [...(p.fields || []), { key: `field${(p.fields || []).length + 1}`, label: 'New field', type: 'text', required: false }] })}>
                        Add field
                      </Button>
                    )}
                  </div>
                  <div className="space-y-2">
                    {(p.fields || []).length === 0 && <p className="text-xs text-slate-400">No extra fields for this loan type.</p>}
                    {(p.fields || []).map((f, fi) => (
                      <div key={fi} className="grid items-center gap-2 rounded-xl bg-slate-50 p-3 md:grid-cols-12">
                        <Input className="md:col-span-3" disabled={readOnly} value={f.label} onChange={(e) => updField(i, fi, { label: e.target.value })} placeholder="Label" />
                        <Input className="md:col-span-2 font-mono text-xs" disabled={readOnly} value={f.key} onChange={(e) => updField(i, fi, { key: e.target.value.replace(/[^A-Za-z0-9_]/g, '') })} placeholder="key" />
                        <Select className="md:col-span-2" disabled={readOnly} value={f.type} onChange={(e) => updField(i, fi, { type: e.target.value })}>
                          <option value="text">Text</option>
                          <option value="number">Number</option>
                          <option value="select">Dropdown</option>
                          <option value="pincode">PIN code</option>
                        </Select>
                        <Input
                          className="md:col-span-3"
                          disabled={readOnly || f.type !== 'select'}
                          value={(f.options || []).join(', ')}
                          onChange={(e) => updField(i, fi, { options: e.target.value.split(',').map((x) => x.trim()).filter(Boolean) })}
                          placeholder={f.type === 'select' ? 'Options, comma separated' : '—'}
                        />
                        <div className="flex items-center justify-between gap-2 md:col-span-2">
                          <label className="flex items-center gap-1.5 text-xs font-semibold text-slate-600">
                            <input type="checkbox" disabled={readOnly} checked={!!f.required} onChange={(e) => updField(i, fi, { required: e.target.checked })} />
                            Required
                          </label>
                          {!readOnly && (
                            <button type="button" className="rounded-lg p-1.5 text-slate-400 hover:bg-white hover:text-rose-600 cursor-pointer" onClick={() => upd(i, { fields: p.fields.filter((_, j) => j !== fi) })}>
                              <Trash2 className="size-4" />
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </Card>
        )
      })}
    </div>
  )
}
