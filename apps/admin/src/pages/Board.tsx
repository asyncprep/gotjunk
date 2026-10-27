import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { businessToday, money, must, supabase, type ShiftStatus } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';

type BoardShift = {
  shift_id: string;
  status: ShiftStatus;
  hours_type: string | null;
  truck: { unit_number: string } | null;
  phone: { label: string } | null;
  crew: { left_at: string | null; employee: { full_name: string } | null }[];
  revenue: number;
  jobs: number;
  errors: number;
};

async function loadBoard(date: string): Promise<BoardShift[]> {
  const shifts = await must(
    supabase
      .from('shift')
      .select('shift_id, status, hours_type, truck:truck_id(unit_number), phone:phone_id(label), crew:shift_crew_member(left_at, employee:employee_id(full_name))')
      .eq('shift_date', date)
      .neq('status', 'archived'),
  ) as unknown as Omit<BoardShift, 'revenue' | 'jobs' | 'errors'>[];
  const ids = shifts.map((s) => s.shift_id);
  const totals = ids.length
    ? await must(supabase.from('v_shift_totals').select('shift_id, revenue_pre_tax, jobs_completed').in('shift_id', ids))
    : [];
  const errors = await Promise.all(ids.map(async (id) => {
    const rows = await must(supabase.rpc('shift_problems', { p_shift_id: id, p_stage: 'lock' }));
    return (rows as { severity: string }[]).filter((p) => p.severity === 'error').length;
  }));
  return shifts
    .map((s, i) => {
      const tot = totals.find((x) => x.shift_id === s.shift_id);
      return { ...s, revenue: Number(tot?.revenue_pre_tax ?? 0), jobs: Number(tot?.jobs_completed ?? 0), errors: errors[i] };
    })
    .sort((a, b) => (a.truck?.unit_number ?? '').localeCompare(b.truck?.unit_number ?? ''));
}

export default function Board() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const [date, setDate] = useState(businessToday());
  const [showNew, setShowNew] = useState(false);
  const board = useLoad(() => loadBoard(date), [date]);

  return (
    <>
      <div className="row" style={{ marginBottom: 16 }}>
        <h1 style={{ margin: 0 }}>{t('board.title')}</h1>
        <input type="date" value={date} onChange={(e) => setDate(e.target.value)} aria-label={t('common.date')} />
        <button className="primary right" onClick={() => setShowNew((v) => !v)}>{t('board.newShift')}</button>
      </div>

      {showNew && <NewShift date={date} onCreated={() => { setShowNew(false); board.reload(); }} />}

      <div className="card">
        {board.error && <div className="notice err">{board.error}</div>}
        {board.loading && !board.data ? <p className="muted">{t('common.loading')}</p>
          : !board.data?.length ? <p className="muted">{t('board.empty')}</p>
          : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>{t('board.truck')}</th><th>{t('board.phone')}</th><th>{t('board.crew')}</th>
                    <th>{t('board.status')}</th><th className="num">{t('board.jobs')}</th>
                    <th className="num">{t('board.revenue')}</th><th className="num">{t('board.issues')}</th>
                  </tr>
                </thead>
                <tbody>
                  {board.data.map((s) => (
                    <tr key={s.shift_id} className="clickable" onClick={() => navigate(`/shift/${s.shift_id}`)}>
                      <td><strong>{s.truck?.unit_number}</strong></td>
                      <td>{s.phone?.label}</td>
                      <td>{s.crew.filter((c) => !c.left_at).map((c) => c.employee?.full_name).join(', ')}</td>
                      <td><span className={`pill ${s.status}`}>{t(`status.${s.status}`)}</span></td>
                      <td className="num">{s.jobs}</td>
                      <td className="num">{money(s.revenue, i18n.language)}</td>
                      <td className={`num ${s.errors ? 'problem error' : 'ok-text'}`}>{s.errors || '✓'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
      </div>
    </>
  );
}

function NewShift({ date, onCreated }: { date: string; onCreated: () => void }) {
  const { t } = useTranslation();
  const options = useLoad(async () => ({
    trucks: await must(supabase.from('truck').select('truck_id, unit_number').eq('active', true).order('unit_number')),
    phones: await must(supabase.from('phone').select('phone_id, label').eq('active', true).order('label')),
    employees: await must(supabase.from('employee').select('employee_id, full_name').eq('active', true).order('full_name')),
  }), []);
  const [truck, setTruck] = useState('');
  const [phone, setPhone] = useState('');
  const [crew, setCrew] = useState<string[]>([]);
  const action = useAction(onCreated);

  if (!options.data) return <div className="card muted">{options.error ?? t('common.loading')}</div>;
  const { trucks, phones, employees } = options.data;

  return (
    <div className="card">
      <h2>{t('board.newShift')} · {date}</h2>
      {action.notice && <div className={`notice ${action.notice.ok ? 'ok' : 'err'}`}>{action.notice.text}</div>}
      <div className="row">
        <select value={truck} onChange={(e) => setTruck(e.target.value)} aria-label={t('board.truck')}>
          <option value="">{t('board.truck')}…</option>
          {trucks.map((x) => <option key={x.truck_id} value={x.truck_id}>{x.unit_number}</option>)}
        </select>
        <select value={phone} onChange={(e) => setPhone(e.target.value)} aria-label={t('board.phone')}>
          <option value="">{t('board.phone')}…</option>
          {phones.map((x) => <option key={x.phone_id} value={x.phone_id}>{x.label}</option>)}
        </select>
      </div>
      <p className="muted small">{t('board.pickCrew')}</p>
      <div className="row checks">
        {employees.map((e) => (
          <label key={e.employee_id}>
            <input
              type="checkbox"
              checked={crew.includes(e.employee_id)}
              onChange={(ev) => setCrew(ev.target.checked ? [...crew, e.employee_id] : crew.filter((x) => x !== e.employee_id))}
            />
            {e.full_name}
          </label>
        ))}
      </div>
      <div className="row">
        <button
          className="primary"
          disabled={action.busy || !truck || !phone || crew.length === 0}
          onClick={() => action.run(() => must(supabase.rpc('create_shift', {
            p_shift_date: date, p_truck_id: truck, p_phone_id: phone, p_crew: crew,
          })))}
        >
          {t('board.create')}
        </button>
      </div>
    </div>
  );
}
