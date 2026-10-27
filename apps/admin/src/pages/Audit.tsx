import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { businessToday, dateTime, must, supabase } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';

const ENTITIES = ['shift', 'job', 'disposal_visit', 'disposal_material_txn', 'cash_submission', 'shift_crew_member',
  'shift_checklist_check', 'photo', 'site_rate_config', 'employee', 'employee_rank_history', 'app_user', 'app_setting'];

export default function Audit() {
  const { t, i18n } = useTranslation();
  const [entity, setEntity] = useState('');
  const log = useLoad(() => {
    let q = supabase.from('audit_log').select('*').order('audit_id', { ascending: false }).limit(200);
    if (entity) q = q.eq('entity_type', entity);
    return must(q) as Promise<any[]>;
  }, [entity]);

  return (
    <>
      <div className="page-head"><h1>{t('audit.title')}</h1></div>
      <Export />
      <div className="card">
        <div className="row" style={{ marginBottom: 10 }}>
          <select value={entity} onChange={(e) => setEntity(e.target.value)}>
            <option value="">{t('common.all')}</option>
            {ENTITIES.map((e) => <option key={e} value={e}>{e}</option>)}
          </select>
        </div>
        {log.error && <div className="notice err">{log.error}</div>}
        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>{t('audit.when')}</th><th>{t('audit.record')}</th><th>{t('audit.action')}</th>
              <th>{t('audit.by')}</th><th>{t('audit.reason')}</th><th>{t('audit.changes')}</th>
            </tr></thead>
            <tbody>
              {(log.data ?? []).map((r) => (
                <tr key={r.audit_id}>
                  <td style={{ whiteSpace: 'nowrap' }}>{dateTime(r.occurred_at, i18n.language)}</td>
                  <td>{r.entity_type}</td>
                  <td>{r.action}</td>
                  <td>{t(`role.${r.actor_role}`, { defaultValue: r.actor_role })}</td>
                  <td>{r.reason ?? ''}</td>
                  <td className="small muted">{summarize(r)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}

// For updates show "field: old → new"; for inserts/deletes just the field count.
function summarize(r: any): string {
  const c = r.field_changes;
  if (!c) return '';
  if (r.action === 'update' || String(r.action).startsWith('status:')) {
    return Object.entries(c)
      .filter(([k]) => !k.endsWith('_at') && !k.endsWith('_by'))
      .map(([k, v]: [string, any]) => `${k}: ${fmt(v?.old)} → ${fmt(v?.new)}`)
      .join(' · ');
  }
  return `${Object.keys(c).length} fields`;
}
const fmt = (v: unknown) => (v === null || v === undefined ? '∅' : typeof v === 'object' ? JSON.stringify(v) : String(v));

function Export() {
  const { t } = useTranslation();
  const [from, setFrom] = useState(businessToday());
  const [to, setTo] = useState(businessToday());
  const action = useAction(() => undefined);

  async function exportCsv() {
    const shifts = await must(supabase.from('shift')
      .select('shift_id, shift_date, status, hours_type, start_time, finish_time, total_hours, truck:truck_id(unit_number)')
      .gte('shift_date', from).lte('shift_date', to).order('shift_date')) as any[];
    const ids = shifts.map((s) => s.shift_id);
    const totals = ids.length ? await must(supabase.from('v_shift_totals').select('*').in('shift_id', ids)) as any[] : [];
    const header = ['shift_date', 'truck', 'status', 'hours_type', 'start_time', 'finish_time', 'total_hours',
      'jobs_completed', 'jobs_cancelled', 'revenue_pre_tax', 'revenue_total_incl_tax', 'discounts', 'tips',
      'expected_cash', 'net_disposal', 'revenue_per_hour', 'shift_id'];
    const lines = shifts.map((s) => {
      const tot = totals.find((x) => x.shift_id === s.shift_id) ?? {};
      return [s.shift_date, s.truck?.unit_number, s.status, s.hours_type, s.start_time, s.finish_time, s.total_hours,
        tot.jobs_completed, tot.jobs_cancelled, tot.revenue_pre_tax, tot.revenue_total_incl_tax, tot.discounts, tot.tips,
        tot.expected_cash, tot.net_disposal, tot.revenue_per_hour, s.shift_id];
    });
    const csv = [header, ...lines]
      .map((row) => row.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(','))
      .join('\r\n');
    const url = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `shifts_${from}_${to}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <div className="card">
      <h2>{t('audit.exportTitle')}</h2>
      <div className="row">
        <label>{t('audit.fromDate')} <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} /></label>
        <label>{t('audit.toDate')} <input type="date" value={to} onChange={(e) => setTo(e.target.value)} /></label>
        <button disabled={action.busy} onClick={() => action.run(exportCsv)}>{t('common.export')}</button>
      </div>
    </div>
  );
}
