import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { dateTime, isAdminRole, money, must, supabase, time, type ShiftStatus } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';
import { useAuth } from '../lib/auth';
import AskDialog from '../components/AskDialog';

type Named = { name_fr: string; name_en: string } | null;
const named = (n: Named, lang: string) => (n ? (lang === 'en' ? n.name_en : n.name_fr) : '');

async function loadShift(id: string) {
  const [shift, totals, problems, jobs, visits, photos, cash, items, checks, crew, tips, reasons, employees] =
    await Promise.all([
      must(supabase.from('shift').select('*, truck:truck_id(unit_number), phone:phone_id(label)').eq('shift_id', id).single()),
      must(supabase.from('v_shift_totals').select('*').eq('shift_id', id).maybeSingle()),
      must(supabase.rpc('shift_problems', { p_shift_id: id, p_stage: 'lock' })),
      must(supabase.from('job').select('*, reason:cancellation_reason_id(name_fr, name_en)').eq('shift_id', id).order('created_at')),
      must(supabase.from('disposal_visit')
        .select('*, site:site_id(name), lines:disposal_material_txn(*, material:material_type_id(name_fr, name_en))')
        .eq('shift_id', id).order('visit_at')),
      must(supabase.from('photo').select('photo_id, entity_id, photo_kind, storage_path').eq('shift_id', id)),
      must(supabase.from('cash_submission').select('*').eq('shift_id', id).maybeSingle()),
      must(supabase.from('checklist_item').select('item_id, label_fr, label_en, required').eq('active', true).order('sort_order')),
      must(supabase.from('shift_checklist_check').select('item_id, checked').eq('shift_id', id)),
      must(supabase.from('shift_crew_member')
        .select('shift_crew_id, employee_id, joined_at, left_at, employee:employee_id(full_name), frozen:rank_id_snapshot(name_fr, name_en)')
        .eq('shift_id', id).order('joined_at')),
      must(supabase.from('v_shift_tips_by_employee').select('employee_id, tips').eq('shift_id', id)),
      must(supabase.from('cancellation_reason').select('reason_id, name_fr, name_en').eq('active', true).order('sort_order')),
      must(supabase.from('employee').select('employee_id, full_name').eq('active', true).order('full_name')),
    ]);
  return { shift, totals, problems, jobs, visits, photos, cash, items, checks, crew, tips, reasons, employees } as any;
}

export default function ShiftReview() {
  const { shiftId = '' } = useParams();
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const { session, role } = useAuth();
  const view = useLoad(() => loadShift(shiftId), [shiftId]);
  const action = useAction(view.reload);
  const [reasonPick, setReasonPick] = useState<Record<string, string>>({});
  const [cashForm, setCashForm] = useState<{ counted?: string; envelope?: string; resolution?: string }>({});
  const [newMember, setNewMember] = useState('');
  const [asking, setAsking] = useState<'return' | 'reopen' | null>(null);

  if (!view.data) return <p className="muted">{view.error ?? t('common.loading')}</p>;
  const d = view.data;
  const s = d.shift;
  const status = s.status as ShiftStatus;
  const tot = d.totals ?? {};
  const errors = d.problems.filter((p: any) => p.severity === 'error');
  const warnings = d.problems.filter((p: any) => p.severity === 'warning');
  const checked = new Set(d.checks.filter((c: any) => c.checked).map((c: any) => c.item_id));
  const photosFor = (entityId: string) => d.photos.filter((p: any) => p.entity_id === entityId);
  const tipFor = (employeeId: string) => d.tips.find((x: any) => x.employee_id === employeeId)?.tips ?? 0;

  const updateShift = (patch: Record<string, unknown>, okText?: string) =>
    action.run(() => must(supabase.from('shift').update(patch).eq('shift_id', shiftId).select()), okText);
  const openPhoto = async (path: string) => {
    const { data } = await supabase.storage.from('photos').createSignedUrl(path, 300);
    if (data?.signedUrl) window.open(data.signedUrl, '_blank', 'noopener');
  };
  const saveCash = () => action.run(() => must(supabase.from('cash_submission').update({
    ...(cashForm.counted !== undefined ? { counted_cash: cashForm.counted === '' ? null : Number(cashForm.counted) } : {}),
    ...(cashForm.envelope !== undefined ? { envelope_id: cashForm.envelope || null } : {}),
    ...(cashForm.resolution !== undefined ? { mismatch_resolution: cashForm.resolution || null } : {}),
    received_by: session?.user.id,
  }).eq('shift_id', shiftId).select()), t('shift.countSaved'));
  const toggleCheck = (itemId: string, value: boolean) => action.run(() => must(
    supabase.from('shift_checklist_check').upsert({ shift_id: shiftId, item_id: itemId, checked: value }, { onConflict: 'shift_id,item_id' }).select()));
  const checkAll = () => action.run(() => must(supabase.from('shift_checklist_check').upsert(
    d.items.map((i: any) => ({ shift_id: shiftId, item_id: i.item_id, checked: true })), { onConflict: 'shift_id,item_id' }).select()));

  return (
    <>
      <p><Link to="/">← {t('common.back')}</Link></p>

      <div className="card">
        <div className="row">
          <h1 style={{ margin: 0 }}>{s.truck?.unit_number} · {s.phone?.label}</h1>
          <span className={`pill ${status}`}>{t(`status.${status}`)}</span>
          <span className="muted">{s.shift_date}</span>
        </div>
        <p className="muted">
          {t('shift.hoursType')}: {s.hours_type ? t(`hours.${s.hours_type}`) : '—'}
          {s.hours_type_confirmed_at ? ` (${t('shift.confirmed')})` : ''} · {t('shift.start')} {time(s.start_time, lang)} · {t('shift.finish')} {time(s.finish_time, lang)}
          {s.return_reason && <> · {t('shift.returnedFor')}: « {s.return_reason} »</>}
          {s.reopen_reason && <> · {t('shift.reopenedFor')}: « {s.reopen_reason} »</>}
        </p>
        <div className="row">
          {['submitted', 'reopened', 'returned', 'in_progress'].includes(status) && s.hours_type && !s.hours_type_confirmed_at && (
            <button disabled={action.busy} onClick={() => updateShift({ hours_type_confirmed_at: new Date().toISOString() }, t('ui.saved'))}>{t('shift.confirmHours')}</button>
          )}
          {status === 'submitted' && <>
            <button disabled={action.busy} onClick={() => setAsking('return')}>{t('shift.return')}</button>
            <button className="go" disabled={action.busy} onClick={() => updateShift({ status: 'locked' }, t('shift.locked'))}>{t('shift.lock')}</button>
          </>}
          {(status === 'locked' || (status === 'reconciled' && isAdminRole(role))) && (
            <button disabled={action.busy} onClick={() => setAsking('reopen')}>{t('shift.reopen')}</button>
          )}
          {status === 'locked' && isAdminRole(role) && (
            <button disabled={action.busy} onClick={() => updateShift({ status: 'reconciled' }, t('ui.saved'))}>{t('shift.reconcile')}</button>
          )}
        </div>
      </div>

      <div className="card">
        <h2>{t('shift.scoreboard')}</h2>
        <div className="tiles">
          <div className="tile"><div className="v">{money(tot.revenue_pre_tax, lang)}</div><div className="k">{t('shift.revenuePreTax')}</div></div>
          <div className="tile"><div className="v">{tot.jobs_completed ?? 0}</div><div className="k">{t('shift.jobsCompleted')}</div></div>
          <div className="tile"><div className="v">{money(tot.tips, lang)}</div><div className="k">{t('shift.tips')}</div></div>
          <div className="tile"><div className="v">{money(tot.net_disposal, lang)}</div><div className="k">{t('shift.netDisposal')}</div></div>
          <div className="tile"><div className="v">{money(tot.expected_cash, lang)}</div><div className="k">{t('shift.expectedCash')}</div></div>
          <div className="tile"><div className="v">{tot.revenue_per_hour ? money(tot.revenue_per_hour, lang) : '—'}</div><div className="k">{t('shift.rph')}</div></div>
        </div>
      </div>

      <div className="card">
        <h2>{t('shift.checks')}</h2>
        {!errors.length && !warnings.length && <p className="ok-text">✓ {t('shift.ready')}</p>}
        {[...new Map([...errors, ...warnings].map((p: any) => [`${p.severity}:${p.code}`, p])).values()].map((p: any) => (
          <div key={`${p.severity}:${p.code}`} className={`problem ${p.severity}`}>
            {p.severity === 'error' ? '✕' : '!'} {t(`problem.${p.code}`, { defaultValue: p.code })}
            {' '}<span className="muted small">
              {d.problems.filter((x: any) => x.code === p.code && x.detail).map((x: any) => x.detail).slice(0, 3).join(', ')}
            </span>
          </div>
        ))}
      </div>

      <div className="grid2">
        <div className="card">
          <h2>{t('shift.jobs')}</h2>
          <div className="table-wrap">
            <table>
              <thead><tr>
                <th>{t('shift.opportunity')}</th><th>{t('shift.outcome')}</th><th>{t('shift.method')}</th>
                <th className="num">{t('shift.preTax')}</th><th className="num">{t('shift.inclTax')}</th><th className="num">{t('shift.tip')}</th><th />
              </tr></thead>
              <tbody>
                {d.jobs.map((j: any) => (
                  <tr key={j.job_id}>
                    <td>{j.opportunity_id}</td>
                    <td>{t(`outcome.${j.outcome ?? 'draft'}`)}{j.reason && <div className="muted small">{named(j.reason, lang)}</div>}</td>
                    <td>{j.payment_method_code ?? '—'}</td>
                    <td className="num">{money(j.revenue_pre_tax, lang)}</td>
                    <td className="num">{money(j.revenue_total_incl_tax, lang)}</td>
                    <td className="num">{money(j.tip_amount, lang)}</td>
                    <td>
                      {j.outcome === 'cancelled_pending' && (
                        <div className="row">
                          <select value={reasonPick[j.job_id] ?? ''} onChange={(e) => setReasonPick({ ...reasonPick, [j.job_id]: e.target.value })}>
                            <option value="">{t('shift.reason')}…</option>
                            {d.reasons.map((r: any) => <option key={r.reason_id} value={r.reason_id}>{named(r, lang)}</option>)}
                          </select>
                          <button disabled={!reasonPick[j.job_id] || action.busy} onClick={() => action.run(() => must(supabase.from('job')
                            .update({ outcome: 'cancelled_confirmed', cancellation_reason_id: reasonPick[j.job_id] })
                            .eq('job_id', j.job_id).select()), t('shift.finalized'))}>{t('shift.finalize')}</button>
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
                {!d.jobs.length && <tr><td colSpan={7} className="muted">{t('common.none')}</td></tr>}
              </tbody>
            </table>
          </div>
        </div>

        <div className="card">
          <h2>{t('shift.disposal')}</h2>
          {!d.visits.length && <p className="muted">{t('common.none')}</p>}
          {d.visits.map((v: any) => (
            <div key={v.disposal_visit_id} style={{ marginBottom: 14 }}>
              <div className="row">
                <strong>{v.site?.name}</strong>
                <span className="muted">{time(v.visit_at, lang)} · {t('shift.ticket')} {v.ticket_number ?? '—'}</span>
                {photosFor(v.disposal_visit_id).map((p: any, i: number) => (
                  <button key={p.photo_id} className="link" onClick={() => openPhoto(p.storage_path)}>📷 {i + 1}</button>
                ))}
              </div>
              <div className="table-wrap">
                <table>
                  <thead><tr>
                    <th>{t('shift.material')}</th><th className="num">{t('shift.weight')}</th>
                    <th className="num">{t('shift.billable')}</th><th className="num">{t('shift.rate')}</th><th className="num">{t('shift.amount')}</th>
                  </tr></thead>
                  <tbody>
                    {v.lines.map((l: any) => (
                      <tr key={l.material_txn_id}>
                        <td>{named(l.material, lang)}</td>
                        <td className="num">{l.weight_kg}</td>
                        <td className="num">{l.billable_kg}</td>
                        <td className="num">{l.rate_per_ton_applied}</td>
                        <td className="num">{money(l.signed_amount, lang)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>

        <div className="card">
          <h2>{t('shift.cash')}</h2>
          {!d.cash ? <p className="muted">{t('shift.noCash')}</p> : (
            <div className="stack">
              <div>
                {t('shift.expectedCash')}: <strong>{money(tot.expected_cash, lang)}</strong> · {t('shift.counted')}: <strong>{money(d.cash.counted_cash, lang)}</strong>
                {d.cash.counted_cash !== null && <> · {t('shift.variance')}: <strong>{money(Number(d.cash.counted_cash) - Number(tot.expected_cash ?? 0), lang)}</strong></>}
                {photosFor(d.cash.cash_submission_id).map((p: any, i: number) => (
                  <button key={p.photo_id} className="link" style={{ marginLeft: 8 }} onClick={() => openPhoto(p.storage_path)}>📷 {i + 1}</button>
                ))}
              </div>
              <div className="row">
                <input className="narrow" inputMode="decimal" placeholder={t('shift.counted')}
                  defaultValue={d.cash.counted_cash ?? ''} onChange={(e) => setCashForm({ ...cashForm, counted: e.target.value })} />
                <input className="narrow" placeholder={t('shift.envelope')}
                  defaultValue={d.cash.envelope_id ?? ''} onChange={(e) => setCashForm({ ...cashForm, envelope: e.target.value })} />
              </div>
              <input style={{ width: '100%' }} placeholder={t('shift.resolution')}
                defaultValue={d.cash.mismatch_resolution ?? ''} onChange={(e) => setCashForm({ ...cashForm, resolution: e.target.value })} />
              <div><button disabled={action.busy} onClick={saveCash}>{t('shift.recordCount')}</button></div>
            </div>
          )}
        </div>

        <div className="card">
          <h2>{t('shift.checklist')}</h2>
          <div className="checks">
            {d.items.map((i: any) => (
              <label key={i.item_id}>
                <input type="checkbox" checked={checked.has(i.item_id)} disabled={action.busy}
                  onChange={(e) => toggleCheck(i.item_id, e.target.checked)} />
                {lang === 'en' ? i.label_en : i.label_fr}
              </label>
            ))}
          </div>
          <div className="row"><button disabled={action.busy} onClick={checkAll}>{t('shift.checkAll')}</button></div>
        </div>

        <div className="card">
          <h2>{t('shift.crew')}</h2>
          <div className="table-wrap">
            <table>
              <thead><tr><th>{t('common.name')}</th><th>{t('shift.rankFrozen')}</th><th className="num">{t('shift.tipShare')}</th><th /></tr></thead>
              <tbody>
                {d.crew.map((m: any) => (
                  <tr key={m.shift_crew_id}>
                    <td>{m.employee?.full_name}{m.left_at && <div className="muted small">{t('shift.left')} {dateTime(m.left_at, lang)}</div>}</td>
                    <td>{named(m.frozen, lang) || '—'}</td>
                    <td className="num">{money(tipFor(m.employee_id), lang)}</td>
                    <td>{!m.left_at && (
                      <button className="link" disabled={action.busy} onClick={() => action.run(() => must(supabase.from('shift_crew_member')
                        .update({ left_at: new Date().toISOString() }).eq('shift_crew_id', m.shift_crew_id).select()))}>{t('shift.markLeft')}</button>
                    )}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="row">
            <select value={newMember} onChange={(e) => setNewMember(e.target.value)}>
              <option value="">{t('shift.addMember')}…</option>
              {d.employees.filter((e: any) => !d.crew.some((m: any) => m.employee_id === e.employee_id))
                .map((e: any) => <option key={e.employee_id} value={e.employee_id}>{e.full_name}</option>)}
            </select>
            <button disabled={!newMember || action.busy} onClick={() => action.run(async () => {
              await must(supabase.from('shift_crew_member').insert({ shift_id: shiftId, employee_id: newMember }).select());
              setNewMember('');
            })}>{t('common.add')}</button>
          </div>
        </div>
      </div>
      <AskDialog
        open={asking !== null}
        kind="text"
        title={asking === 'reopen' ? t('shift.reopenTitle') : t('shift.returnTitle')}
        message={asking === 'reopen' ? t('shift.reopenHelp') : t('shift.returnHelp')}
        confirmLabel={asking === 'reopen' ? t('shift.reopen') : t('shift.return')}
        danger
        onClose={() => setAsking(null)}
        onConfirm={(reason) => {
          const kind = asking;
          setAsking(null);
          if (kind === 'reopen') updateShift({ status: 'reopened', reopen_reason: reason }, t('shift.reopened'));
          else updateShift({ status: 'returned', return_reason: reason }, t('shift.returned'));
        }}
      />
    </>
  );
}
