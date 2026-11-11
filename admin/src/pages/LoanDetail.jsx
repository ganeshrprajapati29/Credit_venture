import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import toast from 'react-hot-toast'
import { ArrowLeft, Ban, BadgeCheck, Banknote, CheckCircle2, Circle, Eye, Lock, Phone, Save, XCircle } from 'lucide-react'
import { get, send, errMsg } from '../lib/api'
import { useAuth } from '../lib/auth'
import { date, dateTime, inr, title } from '../lib/format'
import { Badge, Button, Card, Field, Input, KV, Modal, SecureFile, Select, Spinner, Table, Textarea, Toggle, cx } from '../components/ui'

const BASE_SECTIONS = [
  ['basic', 'Basic details'],
  ['product', 'Loan details'],
  ['employment', 'Employment'],
  ['address', 'Address'],
  ['kyc', 'KYC documents'],
  ['bank', 'Bank account'],
]

export default function LoanDetail() {
  const { id } = useParams()
  const { can } = useAuth()
  const [d, setD] = useState(null)
  const [modal, setModal] = useState(null)
  const [busy, setBusy] = useState(false)
  const [remarks, setRemarks] = useState('')
  const [form, setForm] = useState({})
  const [showFull, setShowFull] = useState(false)
  const [products, setProducts] = useState([])
  useEffect(() => {
    get('/admin/settings').then((d) => setProducts(d.settings.loanProducts || [])).catch(() => {})
  }, [])

  const load = useCallback(() => {
    get(`/admin/loans/${id}`)
      .then((x) => {
        setD(x)
        setRemarks(x.loan.adminRemarks || '')
      })
      .catch((e) => toast.error(errMsg(e)))
  }, [id])
  useEffect(load, [load])

  if (!d) return <Spinner />
  const { loan, payments, previous } = d
  const b = loan.basic || {}
  const manager = can('superadmin', 'manager')
  const steps = loan.steps?.length ? loan.steps : ['employment']
  const productDef = products.find((p) => p.key === (loan.product || 'personal'))
  const SECTIONS = BASE_SECTIONS.filter(([k]) => (k === 'product' ? steps.includes('product') : k === 'employment' ? steps.includes('employment') : true))

  const act = async (fn, msg) => {
    setBusy(true)
    try {
      const r = await fn()
      toast.success(r.message || msg)
      setModal(null)
      load()
    } catch (e) {
      toast.error(errMsg(e))
    } finally {
      setBusy(false)
    }
  }

  const setVerify = (k, v) => act(() => send('patch', `/admin/loans/${id}/verification`, { [k]: v }), 'Updated')
  const setStatus = (status, extra = {}) => act(() => send('patch', `/admin/loans/${id}/status`, { status, ...extra }))

  const openApprove = () => {
    setForm({ amount: loan.offer?.amount, tenureMonths: loan.offer?.tenureMonths, interestRate: loan.offer?.interestRate, processingFee: loan.offer?.totalFee, remarks: '' })
    setModal('approve')
  }
  const openDisburse = () => {
    setForm({ amount: (loan.approved?.amount || 0) - (loan.approved?.processingFee || 0), utr: '', mode: 'IMPS', date: new Date().toISOString().slice(0, 10) })
    setModal('disburse')
  }

  const mask = (s) => (showFull || !s ? s : `${'•'.repeat(Math.max(0, String(s).length - 4))}${String(s).slice(-4)}`)
  const allVerified = SECTIONS.every(([k]) => loan.verification?.[k])
  const paidCount = loan.schedule?.filter((i) => i.status === 'paid').length || 0

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link to="/loans" className="rounded-xl border border-slate-200 bg-white p-2 hover:bg-slate-50">
            <ArrowLeft className="size-5" />
          </Link>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-xl font-extrabold">{b.firstName ? `${b.firstName} ${b.lastName}` : loan.user?.fullName || 'Applicant'}</h2>
              <Badge status={loan.status} />
              <span className="rounded-full bg-brand-50 px-2.5 py-0.5 text-xs font-bold text-brand-700">{loan.productName || 'Personal Loan'}</span>
            </div>
            <p className="text-sm text-slate-500">
              {loan.loanNumber} · Applied {dateTime(loan.submittedAt || loan.createdAt)}
            </p>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <a href={`tel:+91${loan.user?.mobile}`}>
            <Button variant="outline" icon={Phone}>
              +91 {loan.user?.mobile}
            </Button>
          </a>
          <Button variant="outline" icon={showFull ? Lock : Eye} onClick={() => setShowFull(!showFull)}>
            {showFull ? 'Mask data' : 'Show full data'}
          </Button>
          {manager && ['submitted', 'under_review'].includes(loan.status) && (
            <>
              <Button variant="danger" icon={XCircle} onClick={() => { setForm({ remarks: '' }); setModal('reject') }}>
                Reject
              </Button>
              <Button variant="success" icon={BadgeCheck} onClick={openApprove}>
                Approve
              </Button>
            </>
          )}
          {manager && loan.status === 'approved' && (
            <>
              <Button variant="outline" icon={XCircle} onClick={() => { setForm({ remarks: '' }); setModal('reject') }}>
                Reject
              </Button>
              <Button icon={Banknote} onClick={openDisburse}>
                Mark disbursed
              </Button>
            </>
          )}
          {manager && loan.status === 'disbursed' && (
            <Button variant="outline" icon={Ban} onClick={() => setModal('close')}>
              Close loan
            </Button>
          )}
        </div>
      </div>

      {loan.rejectionReason && loan.status === 'rejected' && (
        <div className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          <b>Rejected:</b> {loan.rejectionReason}
        </div>
      )}

      <div className="grid gap-6 xl:grid-cols-3">
        <div className="space-y-6 xl:col-span-2">
          {/* offer */}
          <Card title="Loan offer">
            <dl className="grid grid-cols-2 gap-4 p-5 sm:grid-cols-4">
              <KV label="Requested amount" value={inr(loan.offer?.amount)} />
              <KV label="Tenure" value={loan.offer?.tenureMonths ? `${loan.offer.tenureMonths} months` : '—'} />
              <KV label="EMI" value={inr(loan.offer?.emi)} />
              <KV label="Interest (p.a.)" value={loan.offer?.interestRate !== undefined ? `${loan.offer.interestRate}%` : '—'} />
              <KV label="Processing fee + GST" value={inr(loan.offer?.totalFee)} />
              <KV label="Net disbursal" value={inr(loan.offer?.disbursalAmount)} />
              <KV label="Eligible range" value={`${inr(loan.offer?.minAmount)} – ${inr(loan.offer?.maxAmount)}`} />
              <KV label="Promo code" value={loan.offer?.promoCode} />
            </dl>
            {loan.approved?.amount && (
              <div className="border-t border-slate-100 bg-emerald-50/50 px-5 py-4">
                <p className="mb-3 text-xs font-bold uppercase tracking-wide text-emerald-700">Approved terms</p>
                <dl className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                  <KV label="Amount" value={inr(loan.approved.amount)} />
                  <KV label="Tenure" value={`${loan.approved.tenureMonths} months`} />
                  <KV label="EMI" value={inr(loan.approved.emi)} />
                  <KV label="Rate" value={`${loan.approved.interestRate}%`} />
                  <KV label="Fee" value={inr(loan.approved.processingFee)} />
                  <KV label="Approved by" value={loan.approved.approvedBy} />
                  <KV label="Approved on" value={date(loan.approved.approvedAt)} />
                </dl>
              </div>
            )}
            {loan.disbursal?.utr && (
              <div className="border-t border-slate-100 bg-indigo-50/50 px-5 py-4">
                <p className="mb-3 text-xs font-bold uppercase tracking-wide text-indigo-700">Disbursal</p>
                <dl className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                  <KV label="Amount sent" value={inr(loan.disbursal.amount)} />
                  <KV label="UTR" value={loan.disbursal.utr} mono />
                  <KV label="Mode" value={loan.disbursal.mode} />
                  <KV label="Date" value={date(loan.disbursal.date)} />
                </dl>
              </div>
            )}
          </Card>

          <Section title="Basic details" k="basic" loan={loan} onVerify={setVerify}>
            <KV label="Full name (as per PAN)" value={`${b.firstName || ''} ${b.lastName || ''}`} />
            <KV label="Date of birth" value={date(b.dob)} />
            <KV label="Gender" value={title(b.gender)} />
            <KV label="Email" value={b.email} />
            <KV label="Education" value={b.education} />
            <KV label="Marital status" value={b.maritalStatus} />
            <KV label="Employment type" value={b.employmentType} />
            <KV label="Monthly income" value={inr(b.monthlyIncome)} />
            <KV label="Salary mode" value={b.salaryMode} />
            <KV label="Father's name" value={loan.personal?.fatherName} />
            <KV label="Mother's name" value={loan.personal?.motherName} />
            <KV label="Residence" value={title(loan.personal?.residenceType)} />
            <KV label="Purpose" value={loan.personal?.purpose} />
            <KV label="Language" value={loan.personal?.language} />
            <KV label="PEP declaration" value={loan.personal?.pepDeclaration ? 'Not a PEP' : '—'} />
            <KV label="Bureau consent" value={b.consents?.creditBureau ? `Yes · ${date(b.consents.acceptedAt)}` : 'No'} />
          </Section>

          {steps.includes('product') && (
            <Section title={productDef?.detailsTitle || 'Loan details'} k="product" loan={loan} onVerify={setVerify}>
              {(productDef?.fields || Object.keys(loan.productDetails || {}).map((key) => ({ key, label: key }))).map((f) => {
                const v = loan.productDetails?.[f.key]
                return <KV key={f.key} label={f.label} value={v === undefined || v === '' ? '—' : f.type === 'number' && String(f.label).includes('₹') ? inr(v) : String(v)} />
              })}
            </Section>
          )}

          {steps.includes('employment') && (
          <Section title="Employment" k="employment" loan={loan} onVerify={setVerify}>
            <KV label="Company" value={loan.employment?.companyName} />
            <KV label="Sector" value={loan.employment?.sector} />
            <KV label="Industry" value={loan.employment?.industryType} />
            <KV label="Nature of work" value={loan.employment?.natureOfWork} />
            <KV label="Designation" value={loan.employment?.designation} />
            <KV label="Office email" value={loan.employment?.officeEmail} />
            <KV label="Experience" value={loan.employment?.workExperienceMonths ? `${loan.employment.workExperienceMonths} months` : '—'} />
            <KV label="Company PIN" value={loan.employment?.companyPincode} />
            <div className="col-span-2">
              <KV label="Company address" value={loan.employment?.companyAddress} />
            </div>
          </Section>
          )}

          <Section title="Current address" k="address" loan={loan} onVerify={setVerify}>
            <div className="col-span-2">
              <KV label="Address" value={[loan.address?.line1, loan.address?.line2, loan.address?.landmark].filter(Boolean).join(', ')} />
            </div>
            <KV label="City" value={loan.address?.city} />
            <KV label="State" value={loan.address?.state} />
            <KV label="PIN code" value={loan.address?.pincode} />
            <KV label="Years at address" value={loan.address?.yearsAtAddress} />
            <div className="col-span-2">
              <KV label="Permanent address" value={loan.address?.sameAsPermanent ? 'Same as current' : loan.address?.permanentAddress} />
            </div>
          </Section>

          <Section title="KYC documents" k="kyc" loan={loan} onVerify={setVerify}>
            <KV label="Aadhaar number" value={mask(loan.kyc?.aadhaarNumber)} mono />
            <KV label="PAN number" value={loan.kyc?.panNumber} mono />
            <div className="col-span-full grid grid-cols-2 gap-3 md:grid-cols-3">
              <SecureFile file={loan.kyc?.aadhaarFront} label="Aadhaar – front" />
              <SecureFile file={loan.kyc?.aadhaarBack} label="Aadhaar – back" />
              <SecureFile file={loan.kyc?.panCard} label="PAN card" />
              <SecureFile file={loan.kyc?.selfie} label="Selfie" />
              <SecureFile file={loan.kyc?.salarySlip} label="Salary slip" />
            </div>
          </Section>

          <Section title="Bank account" k="bank" loan={loan} onVerify={setVerify}>
            <KV label="Account holder" value={loan.bank?.accountHolderName} />
            <KV label="Account number" value={mask(loan.bank?.accountNumber)} mono />
            <KV label="IFSC" value={loan.bank?.ifsc} mono />
            <KV label="Bank" value={loan.bank?.bankName} />
            <KV label="Branch" value={loan.bank?.branch} />
            <KV label="Type" value={title(loan.bank?.accountType)} />
            <KV label="Auto-debit consent" value={loan.bank?.autoDebitConsent ? 'Yes' : 'No'} />
            <div className="col-span-full grid grid-cols-2 gap-3 md:grid-cols-3">
              <SecureFile file={loan.bank?.bankProof} label="Bank proof" />
            </div>
          </Section>

          {loan.schedule?.length > 0 && (
            <Card title={`EMI schedule · ${paidCount}/${loan.schedule.length} paid`}>
              <Table head={['#', 'Due date', 'EMI', 'Principal', 'Interest', 'Balance', 'Status', '']}>
                {loan.schedule.map((i) => {
                  const overdue = i.status !== 'paid' && new Date(i.dueDate) < new Date()
                  return (
                    <tr key={i.installmentNo}>
                      <td className="px-5 py-3 font-semibold">{i.installmentNo}</td>
                      <td className="px-5 py-3">{date(i.dueDate)}</td>
                      <td className="px-5 py-3 font-semibold">{inr(i.amount)}</td>
                      <td className="px-5 py-3">{inr(i.principal)}</td>
                      <td className="px-5 py-3">{inr(i.interest)}</td>
                      <td className="px-5 py-3">{inr(i.balanceAfter)}</td>
                      <td className="px-5 py-3">
                        <Badge status={overdue ? 'overdue' : i.status} />
                        {i.paymentRef && <p className="mt-0.5 font-mono text-[11px] text-slate-400">{i.paymentRef}</p>}
                      </td>
                      <td className="px-5 py-3 text-right">
                        {manager && (
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() =>
                              act(() => send('patch', `/admin/loans/${id}/installments/${i.installmentNo}`, { status: i.status === 'paid' ? 'pending' : 'paid' }))
                            }
                          >
                            {i.status === 'paid' ? 'Undo' : 'Mark paid'}
                          </Button>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </Table>
            </Card>
          )}
        </div>

        <div className="space-y-6">
          <Card title="Verification checklist">
            <div className="space-y-1 p-3">
              {SECTIONS.map(([k, l]) => (
                <button key={k} onClick={() => setVerify(k, !loan.verification?.[k])} className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm hover:bg-slate-50 cursor-pointer">
                  {loan.verification?.[k] ? <CheckCircle2 className="size-5 text-emerald-500" /> : <Circle className="size-5 text-slate-300" />}
                  <span className={cx('font-medium', loan.verification?.[k] ? 'text-slate-800' : 'text-slate-500')}>{l}</span>
                </button>
              ))}
            </div>
            <p className={cx('border-t border-slate-100 px-5 py-3 text-xs font-semibold', allVerified ? 'text-emerald-600' : 'text-amber-600')}>
              {allVerified ? 'All checks complete – ready for decision' : 'Complete all checks before approving'}
            </p>
          </Card>

          <Card title="Internal remarks">
            <div className="space-y-3 p-5">
              <Textarea value={remarks} onChange={(e) => setRemarks(e.target.value)} placeholder="Notes visible only to the admin team" />
              <Button size="sm" variant="outline" icon={Save} loading={busy} onClick={() => act(() => send('patch', `/admin/loans/${id}/remarks`, { remarks }))}>
                Save remarks
              </Button>
            </div>
          </Card>

          <Card title="Customer">
            <dl className="grid gap-3 p-5">
              <KV label="Mobile" value={`+91 ${loan.user?.mobile}`} />
              <KV label="Account status" value={<Badge status={loan.user?.status} />} />
              <KV label="Registered" value={date(loan.user?.createdAt)} />
              <KV label="Device" value={[loan.user?.device?.brand, loan.user?.device?.model, loan.user?.device?.os && `${loan.user.device.os} ${loan.user.device.osVersion || ''}`].filter(Boolean).join(' · ')} />
              <KV label="App permissions granted" value={(loan.user?.consent?.permissions || []).join(', ') || '—'} />
              {loan.user?.device?.lastLatitude && (
                <KV
                  label="Last location"
                  value={
                    <a className="text-brand-700 underline" target="_blank" rel="noreferrer" href={`https://maps.google.com/?q=${loan.user.device.lastLatitude},${loan.user.device.lastLongitude}`}>
                      View on map
                    </a>
                  }
                />
              )}
              <Link to={`/users/${loan.user?._id}`} className="text-sm font-semibold text-brand-700">
                Open customer profile →
              </Link>
            </dl>
            {previous.length > 0 && (
              <div className="border-t border-slate-100 p-5">
                <p className="mb-2 text-xs font-bold uppercase text-slate-500">Other applications</p>
                {previous.map((p) => (
                  <Link key={p._id} to={`/loans/${p._id}`} className="flex justify-between py-1 text-sm hover:text-brand-700">
                    <span className="font-mono text-xs">{p.loanNumber}</span>
                    <Badge status={p.status} />
                  </Link>
                ))}
              </div>
            )}
          </Card>

          {payments.length > 0 && (
            <Card title="Payments submitted">
              <div className="divide-y divide-slate-100">
                {payments.map((p) => (
                  <div key={p._id} className="flex items-center justify-between px-5 py-3 text-sm">
                    <div>
                      <p className="font-semibold">{inr(p.amount)}</p>
                      <p className="font-mono text-xs text-slate-500">{p.utr}</p>
                    </div>
                    <Badge status={p.status} />
                  </div>
                ))}
              </div>
              <Link to="/payments" className="block border-t border-slate-100 px-5 py-3 text-sm font-semibold text-brand-700">
                Review payments →
              </Link>
            </Card>
          )}

          <Card title="Timeline">
            <ol className="relative space-y-4 p-5">
              {[...(loan.history || [])].reverse().map((h, i) => (
                <li key={i} className="relative pl-6">
                  <span className="absolute left-0 top-1.5 size-2.5 rounded-full bg-brand-500 ring-4 ring-brand-100" />
                  <p className="text-sm font-semibold">{title(h.status)}</p>
                  {h.remarks && <p className="text-xs text-slate-600">{h.remarks}</p>}
                  <p className="text-[11px] text-slate-400">
                    {h.by} · {dateTime(h.at)}
                  </p>
                </li>
              ))}
            </ol>
          </Card>
          {loan.agreement?.accepted && (
            <Card title="E-agreement">
              <dl className="grid gap-3 p-5">
                <KV label="Signed as" value={loan.agreement.signatureName} />
                <KV label="Signed at" value={dateTime(loan.agreement.acceptedAt)} />
                <KV label="IP address" value={loan.agreement.ip} mono />
              </dl>
            </Card>
          )}
        </div>
      </div>

      <Modal
        open={modal === 'approve'}
        onClose={() => setModal(null)}
        title="Approve loan"
        footer={
          <>
            <Button variant="outline" onClick={() => setModal(null)}>
              Cancel
            </Button>
            <Button variant="success" loading={busy} onClick={() => setStatus('approved', form)}>
              Approve loan
            </Button>
          </>
        }
      >
        {!allVerified && <p className="mb-4 rounded-xl bg-amber-50 px-3 py-2 text-xs font-medium text-amber-700">Some verification checks are still pending.</p>}
        <div className="grid grid-cols-2 gap-4">
          <Field label="Approved amount (₹)">
            <Input type="number" value={form.amount ?? ''} onChange={(e) => setForm({ ...form, amount: e.target.value })} />
          </Field>
          <Field label="Tenure (months)">
            <Input type="number" value={form.tenureMonths ?? ''} onChange={(e) => setForm({ ...form, tenureMonths: e.target.value })} />
          </Field>
          <Field label="Interest rate (% p.a.)">
            <Input type="number" step="0.01" value={form.interestRate ?? ''} onChange={(e) => setForm({ ...form, interestRate: e.target.value })} />
          </Field>
          <Field label="Processing fee incl. GST (₹)">
            <Input type="number" value={form.processingFee ?? ''} onChange={(e) => setForm({ ...form, processingFee: e.target.value })} />
          </Field>
          <Field label="Remarks" className="col-span-2">
            <Textarea value={form.remarks || ''} onChange={(e) => setForm({ ...form, remarks: e.target.value })} />
          </Field>
        </div>
      </Modal>

      <Modal
        open={modal === 'reject'}
        onClose={() => setModal(null)}
        title="Reject application"
        footer={
          <>
            <Button variant="outline" onClick={() => setModal(null)}>
              Cancel
            </Button>
            <Button variant="danger" loading={busy} onClick={() => setStatus('rejected', { remarks: form.remarks })}>
              Reject
            </Button>
          </>
        }
      >
        <Field label="Reason (shown to customer)">
          <Select value={form.remarks || ''} onChange={(e) => setForm({ ...form, remarks: e.target.value })}>
            <option value="">Select a reason</option>
            {['KYC documents unclear or invalid', 'Income criteria not met', 'Bank details mismatch', 'Low credit score', 'Unable to verify employment', 'Duplicate application', 'Other'].map((r) => (
              <option key={r}>{r}</option>
            ))}
          </Select>
        </Field>
        <Field label="Or write a custom reason" className="mt-3">
          <Textarea value={form.remarks || ''} onChange={(e) => setForm({ ...form, remarks: e.target.value })} />
        </Field>
      </Modal>

      <Modal
        open={modal === 'disburse'}
        onClose={() => setModal(null)}
        title="Record disbursal"
        footer={
          <>
            <Button variant="outline" onClick={() => setModal(null)}>
              Cancel
            </Button>
            <Button loading={busy} onClick={() => act(() => send('post', `/admin/loans/${id}/disburse`, form))}>
              Confirm disbursal
            </Button>
          </>
        }
      >
        <p className="mb-4 rounded-xl bg-slate-50 px-3 py-2 text-xs text-slate-600">
          Transfer the money manually to <b>{loan.bank?.accountHolderName}</b> · A/c <b className="font-mono">{loan.bank?.accountNumber}</b> · IFSC <b className="font-mono">{loan.bank?.ifsc}</b> ({loan.bank?.bankName}), then record the UTR here. The EMI schedule will be generated automatically.
        </p>
        <div className="grid grid-cols-2 gap-4">
          <Field label="Amount transferred (₹)">
            <Input type="number" value={form.amount ?? ''} onChange={(e) => setForm({ ...form, amount: e.target.value })} />
          </Field>
          <Field label="Mode">
            <Select value={form.mode} onChange={(e) => setForm({ ...form, mode: e.target.value })}>
              {['IMPS', 'NEFT', 'RTGS', 'UPI'].map((m) => (
                <option key={m}>{m}</option>
              ))}
            </Select>
          </Field>
          <Field label="UTR / reference no.">
            <Input value={form.utr} onChange={(e) => setForm({ ...form, utr: e.target.value.trim() })} />
          </Field>
          <Field label="Transfer date">
            <Input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
          </Field>
        </div>
      </Modal>

      <Modal
        open={modal === 'close'}
        onClose={() => setModal(null)}
        title="Close loan"
        footer={
          <>
            <Button variant="outline" onClick={() => setModal(null)}>
              Cancel
            </Button>
            <Button variant="danger" loading={busy} onClick={() => setStatus('closed', { force: true, remarks: 'Closed by admin' })}>
              Close loan
            </Button>
          </>
        }
      >
        <p className="text-sm text-slate-600">
          {paidCount < (loan.schedule?.length || 0)
            ? `${loan.schedule.length - paidCount} EMI(s) are still unpaid. Close only if the loan was settled offline.`
            : 'All EMIs are paid. The loan will be marked closed.'}
        </p>
      </Modal>
    </div>
  )
}

function Section({ title: t, k, loan, onVerify, children }) {
  const v = loan.verification?.[k]
  return (
    <Card
      title={t}
      action={
        <Toggle checked={!!v} onChange={(x) => onVerify(k, x)} label={v ? 'Verified' : 'Mark verified'} />
      }
    >
      <dl className="grid grid-cols-2 gap-4 p-5 md:grid-cols-4">{children}</dl>
    </Card>
  )
}
