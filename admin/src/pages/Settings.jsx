import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'
import { Plus, Save, X } from 'lucide-react'
import { get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { inr, title } from '../lib/format'
import { Button, Card, Field, Input, Spinner, Textarea, Toggle, cx } from '../components/ui'

const TABS = ['Loan product', 'Company & support', 'Repayment', 'Dropdown options', 'Legal', 'App']

export default function Settings() {
  const { can } = useAuth()
  const [s, setS] = useState(null)
  const [tab, setTab] = useState(TABS[0])
  const [busy, setBusy] = useState(false)
  const readOnly = !can('superadmin')

  useEffect(() => {
    get('/admin/settings')
      .then((d) => setS(d.settings))
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

      {tab === 'Loan product' && (
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
