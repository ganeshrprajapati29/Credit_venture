import { useCallback, useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import { ImagePlus, Pencil, Plus, Trash2 } from 'lucide-react'
import { api, get, errMsg } from '../lib/api'
import { Badge, Button, Card, Empty, Field, Input, Modal, Select, Spinner, Toggle } from '../components/ui'

const EMPTY = { title: '', subtitle: '', ctaText: 'Apply Now', ctaAction: 'apply', link: '', bgColor: '#1B2A6B', order: 0, active: true }

export default function Banners() {
  const [items, setItems] = useState(null)
  const [edit, setEdit] = useState(null)
  const [file, setFile] = useState(null)
  const [busy, setBusy] = useState(false)

  const load = useCallback(() => {
    get('/admin/banners')
      .then((d) => setItems(d.banners))
      .catch((e) => toast.error(errMsg(e)))
  }, [])
  useEffect(load, [load])

  const save = async () => {
    setBusy(true)
    try {
      const fd = new FormData()
      Object.entries(edit).forEach(([k, v]) => {
        if (['_id', 'image', 'imageUrl', 'createdAt', 'updatedAt', '__v'].includes(k)) return
        fd.append(k, v ?? '')
      })
      if (file) fd.append('image', file)
      if (edit._id) await api.put(`/admin/banners/${edit._id}`, fd)
      else await api.post('/admin/banners', fd)
      toast.success('Banner saved')
      setEdit(null)
      setFile(null)
      load()
    } catch (e) {
      toast.error(errMsg(e))
    } finally {
      setBusy(false)
    }
  }

  const remove = async (b) => {
    if (!window.confirm(`Delete banner "${b.title}"?`)) return
    try {
      await api.delete(`/admin/banners/${b._id}`)
      toast.success('Deleted')
      load()
    } catch (e) {
      toast.error(errMsg(e))
    }
  }

  const preview = file ? URL.createObjectURL(file) : edit?.imageUrl

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-slate-500">Banners appear in a carousel on the app home screen. Recommended image size 1200 × 600.</p>
        <Button icon={Plus} onClick={() => setEdit({ ...EMPTY })}>
          Add banner
        </Button>
      </div>
      {!items ? (
        <Spinner />
      ) : items.length === 0 ? (
        <Card>
          <Empty text="No banners yet" />
        </Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {items.map((b) => (
            <Card key={b._id} className="overflow-hidden">
              <div className="relative aspect-[2/1] overflow-hidden" style={{ background: b.bgColor }}>
                {b.imageUrl ? (
                  <img src={b.imageUrl} alt="" className="h-full w-full object-cover" />
                ) : (
                  <div className="flex h-full flex-col justify-center p-6 text-white">
                    <p className="text-xl font-extrabold">{b.title}</p>
                    <p className="mt-1 text-sm opacity-80">{b.subtitle}</p>
                    {b.ctaText && <span className="mt-3 w-fit rounded-full bg-white px-3 py-1 text-xs font-bold text-slate-900">{b.ctaText}</span>}
                  </div>
                )}
              </div>
              <div className="flex items-center justify-between p-4">
                <div className="min-w-0">
                  <p className="truncate font-semibold">{b.title}</p>
                  <p className="text-xs text-slate-500">Order {b.order}</p>
                </div>
                <div className="flex items-center gap-1">
                  <Badge status={b.active ? 'active' : 'cancelled'}>{b.active ? 'Live' : 'Hidden'}</Badge>
                  <Button size="sm" variant="ghost" icon={Pencil} onClick={() => setEdit({ ...b })} />
                  <Button size="sm" variant="ghost" icon={Trash2} onClick={() => remove(b)} />
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal
        open={!!edit}
        onClose={() => {
          setEdit(null)
          setFile(null)
        }}
        title={edit?._id ? 'Edit banner' : 'New banner'}
        footer={
          <Button loading={busy} onClick={save}>
            Save banner
          </Button>
        }
      >
        {edit && (
          <div className="space-y-4">
            <label className="flex aspect-[2/1] cursor-pointer items-center justify-center overflow-hidden rounded-xl border-2 border-dashed border-slate-200" style={{ background: preview ? undefined : edit.bgColor }}>
              {preview ? (
                <img src={preview} alt="" className="h-full w-full object-cover" />
              ) : (
                <span className="flex flex-col items-center gap-1 text-white/90">
                  <ImagePlus className="size-8" />
                  <span className="text-xs font-semibold">Upload image (optional)</span>
                </span>
              )}
              <input type="file" accept="image/png,image/jpeg,image/webp" className="hidden" onChange={(e) => setFile(e.target.files?.[0] || null)} />
            </label>
            <Field label="Title">
              <Input value={edit.title} onChange={(e) => setEdit({ ...edit, title: e.target.value })} />
            </Field>
            <Field label="Subtitle">
              <Input value={edit.subtitle || ''} onChange={(e) => setEdit({ ...edit, subtitle: e.target.value })} />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field label="Button text">
                <Input value={edit.ctaText || ''} onChange={(e) => setEdit({ ...edit, ctaText: e.target.value })} />
              </Field>
              <Field label="Button action">
                <Select value={edit.ctaAction} onChange={(e) => setEdit({ ...edit, ctaAction: e.target.value })}>
                  <option value="apply">Open loan application</option>
                  <option value="link">Open web link</option>
                  <option value="none">No action</option>
                </Select>
              </Field>
              {edit.ctaAction === 'link' && (
                <Field label="Link URL" className="col-span-2">
                  <Input value={edit.link || ''} onChange={(e) => setEdit({ ...edit, link: e.target.value })} />
                </Field>
              )}
              <Field label="Background colour">
                <div className="flex gap-2">
                  <input type="color" value={edit.bgColor} onChange={(e) => setEdit({ ...edit, bgColor: e.target.value })} className="h-10 w-12 cursor-pointer rounded-lg border border-slate-200" />
                  <Input value={edit.bgColor} onChange={(e) => setEdit({ ...edit, bgColor: e.target.value })} />
                </div>
              </Field>
              <Field label="Display order">
                <Input type="number" value={edit.order} onChange={(e) => setEdit({ ...edit, order: e.target.value })} />
              </Field>
            </div>
            <Toggle checked={edit.active} onChange={(v) => setEdit({ ...edit, active: v })} label="Show in app" />
          </div>
        )}
      </Modal>
    </div>
  )
}
