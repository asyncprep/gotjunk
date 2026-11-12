import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { businessToday, must, supabase } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';
import { useAuth } from '../lib/auth';
import SortableRows from '../components/SortableRows';
import AskDialog from '../components/AskDialog';
import { toast } from '../components/Toasts';
import { explainError } from '../i18n';

type Field = { key: string; label: string; type: 'text' | 'number' | 'bool' | 'select'; options?: string[]; hint?: string };
/** orderKey: the table is ordered by dragging rows; the order column itself is hidden. */
type TableDef = { table: string; pk: string; order: string; orderKey?: string; fields: Field[] };

const TABS = ['rates', 'profitShare', 'reasons', 'checklist', 'ranks', 'routes', 'trucks', 'phones', 'sites', 'materials', 'payments', 'settings'] as const;
type Tab = typeof TABS[number];

// "Prix refusé" -> "prix_refuse": codes are stable identifiers, generated when left empty.
const slug = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 40);

export default function Config() {
  const { t } = useTranslation();
  const { canEditConfig } = useAuth();
  const [tab, setTab] = useState<Tab>('rates');
  const code: Field = { key: 'code', label: t('common.code'), type: 'text', hint: t('ui.codeAuto') };
  const active: Field = { key: 'active', label: t('common.active'), type: 'bool' };

  const defs: Record<Exclude<Tab, 'rates' | 'settings' | 'profitShare'>, TableDef> = {
    reasons: { table: 'cancellation_reason', pk: 'reason_id', order: 'sort_order', orderKey: 'sort_order', fields: [
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' }, code, active] },
    checklist: { table: 'checklist_item', pk: 'item_id', order: 'sort_order', orderKey: 'sort_order', fields: [
      { key: 'label_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'label_en', label: t('common.nameEn'), type: 'text' },
      { key: 'required', label: t('common.required'), type: 'bool' }, code, active] },
    ranks: { table: 'rank', pk: 'rank_id', order: 'sort_order', orderKey: 'sort_order', fields: [
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' }, code, active] },
    routes: { table: 'route_name', pk: 'route_name_id', order: 'sort_order', orderKey: 'sort_order', fields: [
      { key: 'name', label: t('paste.route'), type: 'text' }, active] },
    trucks: { table: 'truck', pk: 'truck_id', order: 'unit_number', fields: [
      { key: 'unit_number', label: t('config.unit'), type: 'text' }, active] },
    phones: { table: 'phone', pk: 'phone_id', order: 'label', fields: [
      { key: 'label', label: t('config.label'), type: 'text' }, active] },
    sites: { table: 'site', pk: 'site_id', order: 'name', fields: [
      { key: 'name', label: t('common.name'), type: 'text' },
      { key: 'address', label: t('config.address'), type: 'text' },
      { key: 'site_type', label: t('config.siteType'), type: 'select', options: ['eco_junk', 'eco_depot', 'outside_dump', 'other'] },
      { key: 'issues_tickets', label: t('config.issuesTickets'), type: 'bool' },
      { key: 'requires_ticket_photo', label: t('config.needsPhoto'), type: 'bool' }, code, active] },
    materials: { table: 'material_type', pk: 'material_type_id', order: 'code', fields: [
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' }, code, active] },
    payments: { table: 'payment_method', pk: 'code', order: 'code', fields: [
      { key: 'name_fr', label: t('common.nameFr'), type: 'text' },
      { key: 'name_en', label: t('common.nameEn'), type: 'text' },
      { key: 'is_cash', label: t('config.isCash'), type: 'bool' }, code, active] },
  };

  return (
    <>
      <div className="page-head"><h1>{t('config.title')}</h1></div>
      {!canEditConfig && <div className="notice info">{t('config.readOnly')}</div>}
      <div className="tabs" role="tablist">
        {TABS.map((k) => (
          <button key={k} role="tab" aria-selected={tab === k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>
            {t(`config.${k}`)}
          </button>
        ))}
      </div>
      {tab === 'rates' ? <Rates readOnly={!canEditConfig} />
        : tab === 'profitShare' ? <ProfitShare readOnly={!canEditConfig} />
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
  const blank = () => Object.fromEntries(def.fields.map((f) => [f.key, f.type === 'bool' ? f.key === 'active' : '']));
  const [draft, setDraft] = useState<Record<string, unknown>>(blank);
  const sortable = Boolean(def.orderKey) && !readOnly;

  const input = (f: Field, value: unknown, onChange: (v: unknown) => void, existing: boolean) => {
    // A code identifies the record in integrations and history: it can be set once, not changed.
    const locked = readOnly || (f.key === 'code' && existing);
    if (f.type === 'bool') {
      return <input type="checkbox" checked={Boolean(value)} disabled={readOnly} onChange={(e) => onChange(e.target.checked)} />;
    }
    if (f.type === 'select') {
      return (
        <select value={String(value ?? '')} disabled={readOnly} onChange={(e) => onChange(e.target.value)}>
          <option value="" />
          {f.options!.map((o) => <option key={o} value={o}>{o}</option>)}
        </select>
      );
    }
    return (
      <input className={f.type === 'number' || f.key === 'code' ? 'narrow' : ''} type={f.type === 'number' ? 'number' : 'text'}
        value={String(value ?? '')} disabled={locked} placeholder={!existing ? f.hint ?? '' : ''} title={!existing ? f.hint : undefined}
        onChange={(e) => onChange(f.type === 'number' ? (e.target.value === '' ? null : Number(e.target.value)) : e.target.value)} />
    );
  };

  const reorder = async (ordered: any[]) => {
    const key = def.orderKey!;
    const withOrder = ordered.map((r, i) => ({ ...r, [key]: (i + 1) * 10 }));
    rows.setData(withOrder); // optimistic: the row stays where it was dropped
    try {
      await Promise.all(withOrder
        .filter((r, i) => r[key] !== ordered[i][key])
        .map((r) => must(supabase.from(def.table).update({ [key]: r[key] }).eq(def.pk, r[def.pk]).select())));
      toast(t('ui.reordered'));
    } catch (e) {
      toast(explainError((e as Error).message), false);
      rows.reload(true);
    }
  };

  const saveRow = (r: any, changed: Record<string, unknown>) => action.run(async () => {
    await must(supabase.from(def.table).update(changed).eq(def.pk, r[def.pk]).select());
    const { [String(r[def.pk])]: _done, ...rest } = edits;
    setEdits(rest);
  }, t('ui.saved'));

  const addRow = () => action.run(async () => {
    const row: Record<string, unknown> = { ...draft };
    if ('code' in row && !String(row.code ?? '').trim()) {
      row.code = slug(String(row.name_fr || row.name || row.label_fr || row.label || ''));
    }
    for (const f of def.fields) if (f.type !== 'bool' && row[f.key] === '') delete row[f.key];
    if (def.orderKey) row[def.orderKey] = ((rows.data?.length ?? 0) + 1) * 10;
    await must(supabase.from(def.table).insert(row).select());
    setDraft(blank());
  }, t('ui.saved'));

  const cells = (r: any) => {
    const id = String(r[def.pk]);
    const changed = edits[id];
    return (
      <>
        {def.fields.map((f) => (
          <td key={f.key}>
            {input(f, changed && f.key in changed ? changed[f.key] : r[f.key],
              (v) => setEdits({ ...edits, [id]: { ...changed, [f.key]: v } }), true)}
          </td>
        ))}
        <td>
          {changed && !readOnly && (
            <div className="row">
              <button className="primary" disabled={action.busy} onClick={() => saveRow(r, changed)}>{t('common.save')}</button>
              <button className="ghost" onClick={() => { const { [id]: _x, ...rest } = edits; setEdits(rest); }}>{t('common.cancel')}</button>
            </div>
          )}
        </td>
      </>
    );
  };

  const data = rows.data ?? [];
  const rowClass = (r: any) => (edits[String(r[def.pk])] ? 'dirty' : '');

  return (
    <div className="card">
      {rows.error && <div className="notice err">{rows.error}</div>}
      {sortable && <p className="muted small">⠿ {t('ui.dragHint')}</p>}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>{sortable && <th aria-label={t('ui.dragHandle')} />}{def.fields.map((f) => <th key={f.key}>{f.label}</th>)}<th /></tr>
          </thead>
          {sortable ? (
            <SortableRows rows={data} getId={(r) => String(r[def.pk])} onReorder={reorder} className={rowClass}>
              {cells}
            </SortableRows>
          ) : (
            <tbody>{data.map((r) => <tr key={String(r[def.pk])} className={rowClass(r)}>{cells(r)}</tr>)}</tbody>
          )}
          {!readOnly && (
            <tfoot>
              <tr>
                {sortable && <td />}
                {def.fields.map((f) => <td key={f.key}>{input(f, draft[f.key], (v) => setDraft({ ...draft, [f.key]: v }), false)}</td>)}
                <td><button className="go" disabled={action.busy} onClick={addRow}>{t('common.add')}</button></td>
              </tr>
            </tfoot>
          )}
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
    sites: await must(supabase.from('site').select('site_id, name').eq('active', true).order('name')) as any[],
    materials: await must(supabase.from('material_type').select('material_type_id, name_fr, name_en').eq('active', true).order('code')) as any[],
  }), []);
  const action = useAction(data.reload);
  const [ending, setEnding] = useState<any | null>(null);
  const [draft, setDraft] = useState<Record<string, any>>({
    direction: 'cost', min_billable_kg: 0, min_applies_to: 'transaction', effective_from: businessToday(),
  });

  if (!data.data) return <div className="card muted">{data.error ?? t('common.loading')}</div>;
  const { rates, sites, materials } = data.data;
  const mat = (m: any) => (m ? (lang === 'en' ? m.name_en : m.name_fr) : '');
  const current = rates.filter((r) => r.active && !r.effective_to);
  const past = rates.filter((r) => !(r.active && !r.effective_to));

  const rateRow = (r: any) => (
    <tr key={r.rate_config_id}>
      <td>{r.site?.name}</td><td>{mat(r.material)}</td>
      <td className="num">{Number(r.rate_per_ton).toFixed(2)}</td><td>{t(`config.${r.direction}`)}</td>
      <td className="num">{r.min_billable_kg}</td><td>{t(`config.${r.min_applies_to}`)}</td>
      <td>{r.effective_from}</td><td>{r.effective_to ?? '—'}</td>
      <td>{!readOnly && !r.effective_to && <button className="link" onClick={() => setEnding(r)}>{t('config.endRate')}</button>}</td>
    </tr>
  );
  const head = (
    <thead><tr>
      <th>{t('shift.site')}</th><th>{t('shift.material')}</th><th className="num">{t('config.ratePerTon')}</th>
      <th>{t('config.direction')}</th><th className="num">{t('config.minKg')}</th><th>{t('config.minApplies')}</th>
      <th>{t('config.from')}</th><th>{t('config.to')}</th><th />
    </tr></thead>
  );

  return (
    <>
      <div className="card">
        <div className="table-wrap"><table>{head}<tbody>{current.map(rateRow)}</tbody></table></div>
        {!readOnly && (
          <>
            <h2 style={{ marginTop: 20 }}>{t('config.newRate')}</h2>
            <div className="row">
              <select value={draft.site_id ?? ''} onChange={(e) => setDraft({ ...draft, site_id: e.target.value })}>
                <option value="">{t('shift.site')}…</option>
                {sites.map((s) => <option key={s.site_id} value={s.site_id}>{s.name}</option>)}
              </select>
              <select value={draft.material_type_id ?? ''} onChange={(e) => setDraft({ ...draft, material_type_id: e.target.value })}>
                <option value="">{t('shift.material')}…</option>
                {materials.map((m) => <option key={m.material_type_id} value={m.material_type_id}>{mat(m)}</option>)}
              </select>
              <select value={draft.direction} onChange={(e) => setDraft({
                ...draft, direction: e.target.value,
                ...(e.target.value === 'no_charge' ? { rate_per_ton: 0 } : {}),
                // Credits never use a minimum billable weight (decision R3c).
                ...(e.target.value === 'credit' ? { min_billable_kg: 0, min_applies_to: 'never' } : {}),
              })}>
                {['cost', 'credit', 'no_charge'].map((d) => <option key={d} value={d}>{t(`config.${d}`)}</option>)}
              </select>
              <input className="narrow" type="number" min={0} placeholder={t('config.ratePerTon')} value={draft.rate_per_ton ?? ''}
                disabled={draft.direction === 'no_charge'}
                onChange={(e) => setDraft({ ...draft, rate_per_ton: e.target.value === '' ? undefined : Number(e.target.value) })} />
            </div>
            <div className="row">
              <label>{t('config.minKg')} <input className="narrow" type="number" min={0} value={draft.min_billable_kg}
                disabled={draft.direction === 'credit'}
                onChange={(e) => setDraft({ ...draft, min_billable_kg: Number(e.target.value) })} /></label>
              <select value={draft.min_applies_to} disabled={draft.direction === 'credit'} onChange={(e) => setDraft({ ...draft, min_applies_to: e.target.value })}>
                {['transaction', 'never'].map((d) => <option key={d} value={d}>{t(`config.${d}`)}</option>)}
              </select>
              <label>{t('config.from')} <input type="date" value={draft.effective_from}
                onChange={(e) => setDraft({ ...draft, effective_from: e.target.value })} /></label>
              <button className="go" disabled={action.busy || !draft.site_id || !draft.material_type_id || draft.rate_per_ton === undefined}
                onClick={() => action.run(() => must(supabase.rpc('add_site_rate', {
                  p_site_id: draft.site_id, p_material_type_id: draft.material_type_id, p_rate_per_ton: draft.rate_per_ton,
                  p_direction: draft.direction, p_min_billable_kg: draft.min_billable_kg, p_min_applies_to: draft.min_applies_to,
                  p_effective_from: draft.effective_from,
                })), t('config.rateAdded'))}>
                {t('common.add')}
              </button>
            </div>
          </>
        )}
      </div>
      {past.length > 0 && (
        <details className="card">
          <summary className="muted">{t('config.pastRates')} ({past.length})</summary>
          <div className="table-wrap"><table>{head}<tbody>{past.map(rateRow)}</tbody></table></div>
        </details>
      )}
      <AskDialog
        open={Boolean(ending)}
        kind="date"
        title={t('config.endRateTitle')}
        message={ending ? `${ending.site?.name} · ${mat(ending.material)} — ${t('config.endRateHelp')}` : ''}
        initial={businessToday()}
        confirmLabel={t('config.endRate')}
        danger
        onClose={() => setEnding(null)}
        onConfirm={async (end) => {
          const r = ending;
          setEnding(null);
          await action.run(() => must(supabase.from('site_rate_config').update({ effective_to: end }).eq('rate_config_id', r.rate_config_id).select()), t('config.rateEnded'));
        }}
      />
    </>
  );
}

function Settings({ readOnly }: { readOnly: boolean }) {
  const { t } = useTranslation();
  // The profit-share plan has its own tab with one field per value.
  const rows = useLoad(() => must(supabase.from('app_setting').select('key, value, description')
    .neq('key', PLAN_KEY).order('key')) as Promise<any[]>, []);
  const action = useAction(rows.reload);
  const [edits, setEdits] = useState<Record<string, string>>({});

  return (
    <div className="card">
      <table>
        <thead><tr><th>{t('common.code')}</th><th>{t('config.value')}</th><th>{t('config.description')}</th><th /></tr></thead>
        <tbody>
          {(rows.data ?? []).map((r) => (
            <tr key={r.key} className={edits[r.key] !== undefined ? 'dirty' : ''}>
              <td><code>{r.key}</code></td>
              <td><input value={edits[r.key] ?? JSON.stringify(r.value)} disabled={readOnly}
                onChange={(e) => setEdits({ ...edits, [r.key]: e.target.value })} /></td>
              <td className="muted">{r.description}</td>
              <td>{edits[r.key] !== undefined && !readOnly && (
                <button className="primary" onClick={() => action.run(async () => {
                  await must(supabase.from('app_setting').update({ value: JSON.parse(edits[r.key]) }).eq('key', r.key).select());
                  const { [r.key]: _done, ...rest } = edits;
                  setEdits(rest);
                }, t('ui.saved'))}>{t('common.save')}</button>
              )}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}


const PLAN_KEY = 'profit_share_plan';

/** Defaults are the paper sheet's (Aug 2024); the crew app falls back to the same values. */
const PLAN_DEFAULTS = {
  wage_per_hour: 26, franchise_pct: 16, fuel_pct: { one_truck: 4, split_day: 5.5, two_trucks: 7 }, swing_truck_fee: 60,
  min_revenue: 2000, min_revenue_per_hour: 135,
  small_team_hours: 18, small_team_min_crew: 2, small_team_min_revenue: 1500,
  training_min_revenue: 1500, training_min_revenue_per_hour: 125, training_hours_max: 3,
  training_hours_off_revenue_per_hour: true,
  low_cogs_max_pct: 43, mid_cogs_max_pct: 47, max_cogs_pct: 50,
  hours_types: ['regular_junk'] as string[],
};
type Plan = typeof PLAN_DEFAULTS;
type NumberKey = { [K in keyof Plan]: Plan[K] extends number ? K : never }[keyof Plan];
const HOURS_TYPES = ['regular_junk', 'warehouse', 'non_junk'];
const FUEL_MODES = ['one_truck', 'split_day', 'two_trucks'] as const;
const PCT_KEYS = ['share_pct_low_cogs', 'share_pct_mid_cogs', 'share_pct_high_cogs'];

/** Every number the profit share uses: the plan (one setting) and the % per rank and COGS band. */
function ProfitShare({ readOnly }: { readOnly: boolean }) {
  const { t, i18n } = useTranslation();
  const data = useLoad(async () => ({
    setting: await must(supabase.from('app_setting').select('value').eq('key', PLAN_KEY).maybeSingle()) as any,
    ranks: await must(supabase.from('rank')
      .select('rank_id, name_fr, name_en, active, share_pct_low_cogs, share_pct_mid_cogs, share_pct_high_cogs, share_to_trainer')
      .order('sort_order')) as any[],
  }), []);
  const action = useAction(data.reload);
  const [plan, setPlan] = useState<Plan | null>(null);
  const [rankEdits, setRankEdits] = useState<Record<string, Record<string, number | boolean | null>>>({});

  if (!data.data) return <div className="card muted">{data.error ?? t('common.loading')}</div>;
  const stored = data.data.setting?.value ?? {};
  const saved: Plan = { ...PLAN_DEFAULTS, ...stored, fuel_pct: { ...PLAN_DEFAULTS.fuel_pct, ...(stored.fuel_pct ?? {}) } };
  const p = plan ?? saved;
  const set = (patch: Partial<Plan>) => setPlan({ ...p, ...patch });
  const bandsOk = p.low_cogs_max_pct < p.mid_cogs_max_pct && p.mid_cogs_max_pct < p.max_cogs_pct;

  const num = (key: NumberKey, unit: string) => (
    <label key={key}>{t(`ps.${key}`)} ({unit})
      <input type="number" min={0} step="any" value={p[key]} disabled={readOnly}
        onChange={(e) => set({ [key]: e.target.value === '' ? 0 : Number(e.target.value) } as Partial<Plan>)} />
    </label>
  );

  const rankName = (r: any) => (i18n.language === 'en' ? r.name_en : r.name_fr);
  const pctCell = (r: any, key: string) => {
    const changed = rankEdits[r.rank_id];
    const value = changed && key in changed ? changed[key] : r[key];
    return (
      <td key={key} className="num">
        <input className="narrow" type="number" min={0} max={100} step="any" value={(value as number | null) ?? ''} disabled={readOnly}
          placeholder="—" onChange={(e) => setRankEdits({
            ...rankEdits, [r.rank_id]: { ...changed, [key]: e.target.value === '' ? null : Number(e.target.value) },
          })} />
      </td>
    );
  };
  const dropRankEdit = (id: string) => { const { [id]: _x, ...rest } = rankEdits; setRankEdits(rest); };

  return (
    <>
      <div className="card">
        <p className="muted small">{t('ps.intro')}</p>
        <h2>{t('ps.costs')}</h2>
        <div className="cash-form">
          {num('wage_per_hour', '$/h')}
          {num('franchise_pct', '%')}
          {FUEL_MODES.map((m) => (
            <label key={m}>{t(`ps.fuel_${m}`)} (%)
              <input type="number" min={0} step="any" value={p.fuel_pct[m]} disabled={readOnly}
                onChange={(e) => set({ fuel_pct: { ...p.fuel_pct, [m]: e.target.value === '' ? 0 : Number(e.target.value) } })} />
            </label>
          ))}
          {num('swing_truck_fee', '$')}
        </div>
        <h2 style={{ marginTop: 20 }}>{t('ps.minimums')}</h2>
        <div className="cash-form">
          {num('min_revenue', '$')}
          {num('min_revenue_per_hour', '$/h')}
          {num('small_team_hours', 'h')}
          {num('small_team_min_crew', t('ps.people'))}
          {num('small_team_min_revenue', '$')}
        </div>
        <h2 style={{ marginTop: 20 }}>{t('ps.training')}</h2>
        <div className="cash-form">
          {num('training_min_revenue', '$')}
          {num('training_min_revenue_per_hour', '$/h')}
          {num('training_hours_max', 'h')}
        </div>
        <div className="checks">
          <label>
            <input type="checkbox" checked={p.training_hours_off_revenue_per_hour} disabled={readOnly}
              onChange={(e) => set({ training_hours_off_revenue_per_hour: e.target.checked })} />
            {t('ps.training_hours_off_revenue_per_hour')}
          </label>
        </div>
        <h2 style={{ marginTop: 20 }}>{t('ps.bands')}</h2>
        <div className="cash-form">
          {num('low_cogs_max_pct', '%')}
          {num('mid_cogs_max_pct', '%')}
          {num('max_cogs_pct', '%')}
        </div>
        {!bandsOk && <div className="notice err">{t('ps.bandsOrder')}</div>}
        <h2 style={{ marginTop: 20 }}>{t('ps.hoursTypes')}</h2>
        <div className="checks">
          {HOURS_TYPES.map((h) => (
            <label key={h}>
              <input type="checkbox" checked={p.hours_types.includes(h)} disabled={readOnly}
                onChange={(e) => set({ hours_types: e.target.checked ? [...p.hours_types, h] : p.hours_types.filter((x) => x !== h) })} />
              {t(`hours.${h}`)}
            </label>
          ))}
        </div>
        {plan !== null && !readOnly && (
          <div className="row" style={{ marginTop: 16 }}>
            <button className="primary" disabled={action.busy || !bandsOk} onClick={() => action.run(async () => {
              await must(supabase.from('app_setting').update({ value: p }).eq('key', PLAN_KEY).select());
              setPlan(null);
            }, t('ui.saved'))}>{t('common.save')}</button>
            <button className="ghost" onClick={() => setPlan(null)}>{t('common.cancel')}</button>
          </div>
        )}
      </div>
      <div className="card">
        <h2>{t('ps.rankPct')}</h2>
        <p className="muted small">{t('ps.rankPctHint')}</p>
        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>{t('config.ranks')}</th>
              <th className="num">{t('ps.bandLow', { max: p.low_cogs_max_pct })}</th>
              <th className="num">{t('ps.bandMid', { min: p.low_cogs_max_pct, max: p.mid_cogs_max_pct })}</th>
              <th className="num">{t('ps.bandHigh', { min: p.mid_cogs_max_pct, max: p.max_cogs_pct })}</th>
              <th>{t('ps.toTrainer')}</th>
              <th />
            </tr></thead>
            <tbody>
              {data.data.ranks.filter((r) => r.active).map((r) => {
                const changed = rankEdits[r.rank_id];
                return (
                  <tr key={r.rank_id} className={changed ? 'dirty' : ''}>
                    <td>{rankName(r)}</td>
                    {PCT_KEYS.map((k) => pctCell(r, k))}
                    <td>
                      <input type="checkbox" disabled={readOnly} aria-label={`${t('ps.toTrainer')} – ${rankName(r)}`}
                        checked={!!(changed && 'share_to_trainer' in changed ? changed.share_to_trainer : r.share_to_trainer)}
                        onChange={(e) => setRankEdits({ ...rankEdits, [r.rank_id]: { ...changed, share_to_trainer: e.target.checked } })} />
                    </td>
                    <td>{changed && !readOnly && (
                      <div className="row">
                        <button className="primary" disabled={action.busy} onClick={() => action.run(async () => {
                          await must(supabase.from('rank').update(changed).eq('rank_id', r.rank_id).select());
                          dropRankEdit(r.rank_id);
                        }, t('ui.saved'))}>{t('common.save')}</button>
                        <button className="ghost" onClick={() => dropRankEdit(r.rank_id)}>{t('common.cancel')}</button>
                      </div>
                    )}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
