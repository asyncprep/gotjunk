import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { businessToday, must, supabase } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';
import { useAuth } from '../lib/auth';

type Field = { key: string; label: string; type: 'text' | 'number' | 'bool' | 'select'; options?: string[] };
type TableDef = { table: string; pk: string; order: string; fields: Field[] };

const TABS = ['rates', 'trucks', 'phones', 'sites', 'materials', 'payments', 'reasons', 'checklist', 'settings'] as const;
type Tab = typeof TABS[number];

export default function Config() {
  const { t } = useTranslation();
  const { canEditConfig } = useAuth();
  const [tab, setTab] = useState<Tab>('rates');

  const defs: Record<Exclude<Tab, 'rates' | 'settings'>, TableDef> = {
    trucks: { table: 'truck', pk: 'truck_id', order: 'unit_number', fields: [
      { key: 'unit_number', label: t('config.unit'), type: 'text' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
    phones: { table: 'phone', pk: 'phone_id', order: 'label', fields: [
      { key: 'label', label: t('config.label'), type: 'text' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
    sites: { table: 'site', pk: 'site_id', order: 'name', fields: [
      { key: 'code', label: t('common.code'), type: 'text' },
      { key: 'name', label: t('common.name'), type: 'text' },
      { key: 'site_type', label: t('config.siteType'), type: 'select', options: ['eco_junk', 'eco_depot', 'outside_dump', 'other'] },
      { key: 'issues_tickets', label: t('config.issuesTickets'), type: 'bool' },
      { key: 'requires_ticket_photo', label: t('config.needsPhoto'), type: 'bool' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
    materials: { table: 'material_type', pk: 'material_type_id', order: 'code', fields: [
      { key: 'code', label: t('common.code'), type: 'text' },
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
    payments: { table: 'payment_method', pk: 'code', order: 'code', fields: [
      { key: 'code', label: t('common.code'), type: 'text' },
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' },
      { key: 'is_cash', label: t('config.isCash'), type: 'bool' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
    reasons: { table: 'cancellation_reason', pk: 'reason_id', order: 'sort_order', fields: [
      { key: 'code', label: t('common.code'), type: 'text' },
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' },
      { key: 'sort_order', label: t('common.order'), type: 'number' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
    checklist: { table: 'checklist_item', pk: 'item_id', order: 'sort_order', fields: [
      { key: 'code', label: t('common.code'), type: 'text' },
      { key: 'label_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'label_en', label: t('common.nameEn'), type: 'text' },
      { key: 'sort_order', label: t('common.order'), type: 'number' },
      { key: 'required', label: t('common.required'), type: 'bool' },
      { key: 'active', label: t('common.active'), type: 'bool' }] },
  };

  return (
    <>
      <h1>{t('config.title')}</h1>
      {!canEditConfig && <div className="notice">{t('config.readOnly')}</div>}
      <div className="tabs">
        {TABS.map((k) => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>{t(`config.${k}`)}</button>
        ))}
      </div>
      {tab === 'rates' ? <Rates readOnly={!canEditConfig} />
        : tab === 'settings' ? <Settings readOnly={!canEditConfig} />
        : <EditableTable key={tab} def={defs[tab]} readOnly={!canEditConfig} />}
    </>
  );
}

function EditableTable({ def, readOnly }: { def: TableDef; readOnly: boolean }) {
  const { t } = useTranslation();
  const rows = useLoad(() => must(supabase.from(def.table).select('*').order(def.order)) as Promise<any[]>, [def.table]);
  const action = useAction(rows.reload);
  const [edits, setEdits] = useState<Record<string, Record<string, unknown>>>({});
  const [draft, setDraft] = useState<Record<string, unknown>>({ active: true });

  const input = (f: Field, value: unknown, onChange: (v: unknown) => void) => {
    if (f.type === 'bool') return <input type="checkbox" checked={Boolean(value)} disabled={readOnly} onChange={(e) => onChange(e.target.checked)} />;
    if (f.type === 'select') {
      return (
        <select value={String(value ?? '')} disabled={readOnly} onChange={(e) => onChange(e.target.value)}>
          <option value="" />
          {f.options!.map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
      );
    }
    return (
      <input className={f.type === 'number' ? 'narrow' : ''} type={f.type === 'number' ? 'number' : 'text'}
        value={String(value ?? '')} disabled={readOnly}
        onChange={(e) => onChange(f.type === 'number' ? (e.target.value === '' ? null : Number(e.target.value)) : e.target.value)} />
    );
  };

  return (
    <div className="card">
      {action.notice && <div className={`notice ${action.notice.ok ? 'ok' : 'err'}`}>{action.notice.text}</div>}
      {rows.error && <div className="notice err">{rows.error}</div>}
      <div className="table-wrap">
        <table>
          <thead><tr>{def.fields.map((f) => <th key={f.key}>{f.label}</th>)}<th /></tr></thead>
          <tbody>
            {(rows.data ?? []).map((r) => {
              const id = String(r[def.pk]);
              const changed = edits[id];
              return (
                <tr key={id}>
                  {def.fields.map((f) => (
                    <td key={f.key}>
                      {input(f, changed && f.key in changed ? changed[f.key] : r[f.key],
                        (v) => setEdits({ ...edits, [id]: { ...changed, [f.key]: v } }))}
                    </td>
                  ))}
                  <td>
                    {changed && !readOnly && (
                      <button className="primary" disabled={action.busy} onClick={() => action.run(async () => {
                        await must(supabase.from(def.table).update(changed).eq(def.pk, r[def.pk]).select());
                        const { [id]: _done, ...rest } = edits;
                        setEdits(rest);
                      })}>{t('common.save')}</button>
                    )}
                  </td>
                </tr>
              );
            })}
            {!readOnly && (
              <tr>
                {def.fields.map((f) => <td key={f.key}>{input(f, draft[f.key], (v) => setDraft({ ...draft, [f.key]: v }))}</td>)}
                <td>
                  <button disabled={action.busy} onClick={() => action.run(async () => {
                    await must(supabase.from(def.table).insert(draft).select());
                    setDraft({ active: true });
                  })}>{t('common.add')}</button>
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Rates({ readOnly }: { readOnly: boolean }) {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const data = useLoad(async () => ({
    rates: await must(supabase.from('site_rate_config')
      .select('*, site:site_id(name), material:material_type_id(name_fr, name_en)')
      .order('effective_from', { ascending: false })) as any[],
    sites: await must(supabase.from('site').select('site_id, name').eq('active', true).order('name')),
    materials: await must(supabase.from('material_type').select('material_type_id, name_fr, name_en').eq('active', true).order('code')),
  }), []);
  const action = useAction(data.reload);
  const [draft, setDraft] = useState<Record<string, any>>({
    direction: 'cost', min_billable_kg: 0, min_applies_to: 'transaction', effective_from: businessToday(),
  });

  if (!data.data) return <div className="card muted">{data.error ?? t('common.loading')}</div>;
  const { rates, sites, materials } = data.data;
  const mat = (m: any) => (m ? (lang === 'en' ? m.name_en : m.name_fr) : '');

  return (
    <div className="card">
      {action.notice && <div className={`notice ${action.notice.ok ? 'ok' : 'err'}`}>{action.notice.text}</div>}
      <div className="table-wrap">
        <table>
          <thead><tr>
            <th>{t('shift.site')}</th><th>{t('shift.material')}</th><th className="num">{t('config.ratePerTon')}</th>
            <th>{t('config.direction')}</th><th className="num">{t('config.minKg')}</th><th>{t('config.minApplies')}</th>
            <th>{t('config.from')}</th><th>{t('config.to')}</th><th />
          </tr></thead>
          <tbody>
            {rates.map((r) => (
              <tr key={r.rate_config_id} className={r.active ? '' : 'muted'}>
                <td>{r.site?.name}</td><td>{mat(r.material)}</td>
                <td className="num">{r.rate_per_ton}</td><td>{t(`config.${r.direction}`)}</td>
                <td className="num">{r.min_billable_kg}</td><td>{t(`config.${r.min_applies_to}`)}</td>
                <td>{r.effective_from}</td><td>{r.effective_to ?? '—'}</td>
                <td>{!readOnly && !r.effective_to && (
                  <button className="link" onClick={() => {
                    const end = window.prompt(`${t('config.to')} (YYYY-MM-DD)`, businessToday());
                    if (end) action.run(() => must(supabase.from('site_rate_config').update({ effective_to: end }).eq('rate_config_id', r.rate_config_id).select()));
                  }}>{t('config.endRate')}</button>
                )}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!readOnly && (
        <>
          <h2 style={{ marginTop: 16 }}>{t('config.newRate')}</h2>
          <div className="row">
            <select value={draft.site_id ?? ''} onChange={(e) => setDraft({ ...draft, site_id: e.target.value })}>
              <option value="">{t('shift.site')}…</option>
              {sites.map((s) => <option key={s.site_id} value={s.site_id}>{s.name}</option>)}
            </select>
            <select value={draft.material_type_id ?? ''} onChange={(e) => setDraft({ ...draft, material_type_id: e.target.value })}>
              <option value="">{t('shift.material')}…</option>
              {materials.map((m) => <option key={m.material_type_id} value={m.material_type_id}>{mat(m)}</option>)}
            </select>
            <select value={draft.direction} onChange={(e) => setDraft({ ...draft, direction: e.target.value })}>
              {['cost', 'credit', 'no_charge'].map((d) => <option key={d} value={d}>{t(`config.${d}`)}</option>)}
            </select>
            <input className="narrow" type="number" placeholder={t('config.ratePerTon')} value={draft.rate_per_ton ?? ''}
              onChange={(e) => setDraft({ ...draft, rate_per_ton: e.target.value === '' ? undefined : Number(e.target.value) })} />
          </div>
          <div className="row">
            <label>{t('config.minKg')} <input className="narrow" type="number" value={draft.min_billable_kg}
              onChange={(e) => setDraft({ ...draft, min_billable_kg: Number(e.target.value) })} /></label>
            <select value={draft.min_applies_to} onChange={(e) => setDraft({ ...draft, min_applies_to: e.target.value })}>
              {['transaction', 'never'].map((d) => <option key={d} value={d}>{t(`config.${d}`)}</option>)}
            </select>
            <label>{t('config.from')} <input type="date" value={draft.effective_from}
              onChange={(e) => setDraft({ ...draft, effective_from: e.target.value })} /></label>
            <button className="primary" disabled={action.busy || !draft.site_id || !draft.material_type_id || draft.rate_per_ton === undefined}
              onClick={() => action.run(() => must(supabase.from('site_rate_config').insert(draft).select()))}>{t('common.add')}</button>
          </div>
        </>
      )}
    </div>
  );
}

function Settings({ readOnly }: { readOnly: boolean }) {
  const { t } = useTranslation();
  const rows = useLoad(() => must(supabase.from('app_setting').select('key, value, description').order('key')) as Promise<any[]>, []);
  const action = useAction(rows.reload);
  const [edits, setEdits] = useState<Record<string, string>>({});

  return (
    <div className="card">
      {action.notice && <div className={`notice ${action.notice.ok ? 'ok' : 'err'}`}>{action.notice.text}</div>}
      <table>
        <thead><tr><th>{t('common.code')}</th><th>{t('config.value')}</th><th>{t('config.description')}</th><th /></tr></thead>
        <tbody>
          {(rows.data ?? []).map((r) => (
            <tr key={r.key}>
              <td><code>{r.key}</code></td>
              <td><input value={edits[r.key] ?? JSON.stringify(r.value)} disabled={readOnly}
                onChange={(e) => setEdits({ ...edits, [r.key]: e.target.value })} /></td>
              <td className="muted">{r.description}</td>
              <td>{edits[r.key] !== undefined && !readOnly && (
                <button className="primary" onClick={() => action.run(async () => {
                  await must(supabase.from('app_setting').update({ value: JSON.parse(edits[r.key]) }).eq('key', r.key).select());
                  const { [r.key]: _done, ...rest } = edits;
                  setEdits(rest);
                })}>{t('common.save')}</button>
              )}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
