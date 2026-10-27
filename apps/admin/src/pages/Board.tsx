import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { businessToday, money, must, supabase, time, type ShiftStatus } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';

type BoardShift = {
  shift_id: string;
  status: ShiftStatus;
  truck_id: string;
  phone_id: string;
  truck: { unit_number: string } | null;
  phone: { label: string } | null;
  crew: { employee_id: string; left_at: string | null; employee: { full_name: string } | null }[];
  revenue: number;
  jobs: number;
  errors: number;
};

// Filter groups, in the order dispatch works through them.
const GROUPS = {
  all: null,
  review: ['submitted'],
  active: ['open', 'in_progress', 'returned', 'reopened'],
  done: ['locked', 'reconciled'],
} as const;
type Group = keyof typeof GROUPS;
const GROUP_LABEL: Record<Group, string> = { all: 'common.all', review: 'board.toReview', active: 'board.inProgress', done: 'board.done' };
const RANK: Partial<Record<ShiftStatus, number>> = { submitted: 0, returned: 1, reopened: 1, in_progress: 2, open: 3, locked: 4, reconciled: 5 };

async function loadBoard(date: string): Promise<BoardShift[]> {
  const shifts = await must(
    supabase
      .from('shift')
      .select('shift_id, status, truck_id, phone_id, truck:truck_id(unit_number), phone:phone_id(label), crew:shift_crew_member(employee_id, left_at, employee:employee_id(full_name))')
      .eq('shift_date', date)
      .neq('status', 'archived'),
  ) as unknown as Omit<BoardShift, 'revenue' | 'jobs' | 'errors'>[];
  const ids = shifts.map((s) => s.shift_id);
  const totals = ids.length
    ? await must(supabase.from('v_shift_totals').select('shift_id, revenue_pre_tax, jobs_completed').in('shift_id', ids))
    : [];
  const errors = await Promise.all(ids.map(async (id) => {
    const rows = await must(supabase.rpc('shift_problems', { p_shift_id: id, p_stage: 'lock' }));
    return new Set((rows as { severity: string; code: string }[]).filter((p) => p.severity === 'error').map((p) => p.code)).size;
  }));
  return shifts
    .map((s, i) => {
      const tot = totals.find((x) => x.shift_id === s.shift_id);
      return { ...s, revenue: Number(tot?.revenue_pre_tax ?? 0), jobs: Number(tot?.jobs_completed ?? 0), errors: errors[i] };
    })
    .sort((a, b) => (RANK[a.status] ?? 9) - (RANK[b.status] ?? 9)
      || (a.truck?.unit_number ?? '').localeCompare(b.truck?.unit_number ?? ''));
}

const shiftDay = (date: string, days: number) => {
  const d = new Date(`${date}T12:00:00`);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
};

export default function Board() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const [date, setDate] = useState(businessToday());
  const [group, setGroup] = useState<Group>('all');
  const [showNew, setShowNew] = useState(false);
  const [updatedAt, setUpdatedAt] = useState<string>(new Date().toISOString());
  const board = useLoad(async () => {
    const data = await loadBoard(date);
    setUpdatedAt(new Date().toISOString());
    return data;
  }, [date]);

  // Keep the board current without a manual refresh: every minute and when the tab regains focus.
  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState === 'visible') board.reload(true);
    };
    const timer = setInterval(refresh, 60_000);
    window.addEventListener('focus', refresh);
    return () => {
      clearInterval(timer);
      window.removeEventListener('focus', refresh);
    };
  }, [board.reload]);

  const all = board.data ?? [];
  const inGroup = (g: Group, s: BoardShift) => GROUPS[g] === null || (GROUPS[g] as readonly string[]).includes(s.status);
  const shown = all.filter((s) => inGroup(group, s));

  return (
    <>
      <div className="page-head">
        <h1>{t('board.title')}</h1>
        <div className="row">
          <button className="ghost" aria-label="−1" onClick={() => setDate(shiftDay(date, -1))}>‹</button>
          <input type="date" value={date} onChange={(e) => e.target.value && setDate(e.target.value)} aria-label={t('common.date')} />
          <button className="ghost" aria-label="+1" onClick={() => setDate(shiftDay(date, 1))}>›</button>
          {date !== businessToday() && <button className="link" onClick={() => setDate(businessToday())}>{t('board.today')}</button>}
        </div>
        <span className="muted small">
          {t('ui.updatedAt', { time: time(updatedAt, i18n.language) })}{' '}
          <button className="link" onClick={() => board.reload(true)}>{t('ui.refresh')}</button>
        </span>
        <button className="go right" onClick={() => setShowNew((v) => !v)}>+ {t('board.newShift')}</button>
      </div>

      {showNew && (
        <NewShift
          date={date}
          taken={all}
          onCreated={() => { setShowNew(false); board.reload(true); }}
          onCancel={() => setShowNew(false)}
        />
      )}

      <div className="chips" role="tablist">
        {(Object.keys(GROUPS) as Group[]).map((g) => {
          const n = all.filter((s) => inGroup(g, s)).length;
          return (
            <button key={g} role="tab" aria-selected={group === g}
              className={`chip ${group === g ? 'on' : ''} ${g === 'review' && n > 0 ? 'attention' : ''}`}
              onClick={() => setGroup(g)}>
              {t(GROUP_LABEL[g])} <span className="n">{n}</span>
            </button>
          );
        })}
      </div>

      <div className="card">
        {board.error && <div className="notice err">{board.error}</div>}
        {board.loading && !board.data ? <p className="muted">{t('common.loading')}</p>
          : !all.length ? <div className="empty">{t('board.empty')}</div>
          : !shown.length ? <div className="empty">{t('board.noMatch')}</div>
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
                  {shown.map((s) => (
                    <tr key={s.shift_id} className="clickable" tabIndex={0}
                      onClick={() => navigate(`/shift/${s.shift_id}`)}
                      onKeyDown={(e) => e.key === 'Enter' && navigate(`/shift/${s.shift_id}`)}>
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

function NewShift({ date, taken, onCreated, onCancel }: {
  date: string; taken: BoardShift[]; onCreated: () => void; onCancel: () => void;
}) {
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
  // Only offer what isn't already on a shift that day.
  const usedTrucks = new Set(taken.map((s) => s.truck_id));
  const usedPhones = new Set(taken.map((s) => s.phone_id));
  const usedPeople = new Set(taken.flatMap((s) => s.crew.map((c) => c.employee_id)));
  const trucks = options.data.trucks.filter((x) => !usedTrucks.has(x.truck_id));
  const phones = options.data.phones.filter((x) => !usedPhones.has(x.phone_id));
  const employees = options.data.employees.filter((x) => !usedPeople.has(x.employee_id));

  return (
    <div className="card">
      <h2>{t('board.newShift')} · {date}</h2>
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
      <p className="muted small">{t('board.pickCrew')} ({crew.length})</p>
      <div className="row checks">
        {employees.map((e) => (
          <label key={e.employee_id} className="chip" style={{ cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={crew.includes(e.employee_id)}
              onChange={(ev) => setCrew(ev.target.checked ? [...crew, e.employee_id] : crew.filter((x) => x !== e.employee_id))}
            />
            {e.full_name}
          </label>
        ))}
      </div>
      <div className="row" style={{ marginTop: 12 }}>
        <button
          className="go"
          disabled={action.busy || !truck || !phone || crew.length === 0}
          onClick={() => action.run(() => must(supabase.rpc('create_shift', {
            p_shift_date: date, p_truck_id: truck, p_phone_id: phone, p_crew: crew,
          })), t('board.created'))}
        >
          {t('board.create')}
        </button>
        <button className="ghost" onClick={onCancel}>{t('common.cancel')}</button>
      </div>
    </div>
  );
}
