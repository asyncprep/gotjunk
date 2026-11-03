import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { explainError } from '../i18n';
import { must, supabase, type Position, type ShiftStatus } from '../lib/supabase';
import { useLoad } from '../lib/hooks';
import { montrealIso, normalize, parseTracker, type PastedRoute } from '../lib/trackerPaste';

// Dispatch copies the day's block from the tracker spreadsheet and pastes it here: routes are
// created (or, pasted again later, updated with start and end times) without typing them twice.

type Existing = {
  shift_id: string; status: ShiftStatus; truck_id: string; route_code: string | null;
  crew: { employee_id: string }[];
};
type Option = { id: string; label: string };
type Plan = {
  key: string; route: PastedRoute; routeName: string | null; truckId: string | null; phoneId: string | null;
  members: { employeeId: string | null; position: Position | null; name: string; start: string | null; end: string | null }[];
  existing: Existing | null; problems: string[];
};

const FROZEN: ShiftStatus[] = ['locked', 'reconciled', 'archived'];

function find(options: Option[], text: string): string | null {
  const n = normalize(text);
  const exact = options.filter((o) => normalize(o.label) === n);
  if (exact.length === 1) return exact[0].id;
  // "Gabriel Gayle-Gooding" vs "Gabriel Gooding": same first and last word.
  const words = n.split(' ');
  const loose = options.filter((o) => {
    const w = normalize(o.label).split(' ');
    return w[0] === words[0] && w[w.length - 1] === words[words.length - 1];
  });
  return loose.length === 1 ? loose[0].id : null;
}

export default function PasteRoutes({ date, existing, onDone, onCancel }: {
  date: string; existing: Existing[]; onDone: () => void; onCancel: () => void;
}) {
  const { t } = useTranslation();
  const options = useLoad(async () => {
    const [routes, trucks, phones, employees] = await Promise.all([
      must(supabase.from('route_name').select('route_name_id, name').eq('active', true).order('sort_order')),
      must(supabase.from('truck').select('truck_id, unit_number').eq('active', true).order('unit_number')),
      must(supabase.from('phone').select('phone_id, label').eq('active', true).order('label')),
      must(supabase.from('employee').select('employee_id, full_name').eq('active', true).order('full_name')),
    ]);
    return {
      routes: (routes as any[]).map((x) => ({ id: x.name, label: x.name })) as Option[],
      trucks: (trucks as any[]).map((x) => ({ id: x.truck_id, label: x.unit_number })) as Option[],
      phones: (phones as any[]).map((x) => ({ id: x.phone_id, label: x.label })) as Option[],
      employees: (employees as any[]).map((x) => ({ id: x.employee_id, label: x.full_name })) as Option[],
    };
  }, []);
  const [text, setText] = useState('');
  // Dispatch's picks for what the paste didn't match: "truck:C1", "phone:C1", "person:C1:2".
  const [picks, setPicks] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [results, setResults] = useState<{ route: string; ok: boolean; text: string }[]>([]);

  const plans = useMemo<Plan[]>(() => {
    if (!options.data) return [];
    const o = options.data;
    return parseTracker(text).map((route, i) => {
      const key = route.route || String(i + 1);
      // The route's name from Configuration → Routes (ids are the names themselves).
      const routeName = picks[`route:${key}`] || (route.route ? find(o.routes, route.route) : null);
      const truckId = picks[`truck:${key}`] || find(o.trucks, route.truck);
      const phoneId = picks[`phone:${key}`] || find(o.phones, route.phone);
      const members = route.members.map((m, j) => ({
        ...m, employeeId: picks[`person:${key}:${j}`] || find(o.employees, m.name),
        position: (picks[`position:${key}:${j}`] as Position) || m.position,
      }));
      const driverId = members.find((m) => m.position === 'driver')?.employeeId;
      const match = existing.find((s) => routeName && s.route_code && normalize(s.route_code) === normalize(routeName))
        ?? existing.find((s) => !s.route_code && s.truck_id === truckId && s.crew.some((c) => c.employee_id === driverId))
        ?? null;
      const problems: string[] = [];
      if (route.route && !routeName) problems.push(t('paste.unknownRoute', { name: route.route }));
      if (!truckId) problems.push(t('paste.unknownTruck', { name: route.truck || '—' }));
      if (!phoneId) problems.push(t('paste.unknownPhone', { name: route.phone || '—' }));
      members.forEach((m) => { if (!m.employeeId) problems.push(t('paste.unknownPerson', { name: m.name })); });
      if (members.some((m) => !m.position) || members.filter((m) => m.position === 'driver').length !== 1) {
        problems.push(t('position.oneDriver'));
      }
      if (match && FROZEN.includes(match.status)) problems.push(t('paste.frozen'));
      return { key, route, routeName, truckId, phoneId, members, existing: match, problems };
    });
  }, [text, picks, options.data, existing, t]);

  async function apply(p: Plan) {
    const starts = p.members.map((m) => m.start).filter(Boolean).sort() as string[];
    const ends = p.members.map((m) => m.end).filter(Boolean).sort() as string[];
    const routeStart = starts[0] ?? null;
    const routeEnd = ends.length ? ends[ends.length - 1] : null;
    const crew = [...p.members].sort((a, b) => (a.position === 'driver' ? -1 : 0) - (b.position === 'driver' ? -1 : 0));

    let shiftId = p.existing?.shift_id;
    let onRoute = new Set(p.existing?.crew.map((c) => c.employee_id) ?? []);
    if (!shiftId) {
      shiftId = await must(supabase.rpc('create_shift', {
        p_shift_date: date, p_truck_id: p.truckId, p_phone_id: p.phoneId,
        p_crew: crew.map((m) => m.employeeId), p_positions: crew.map((m) => m.position), p_lead: crew[0].employeeId,
      })) as unknown as string;
      onRoute = new Set(crew.map((m) => m.employeeId!));
    }

    const shift: Record<string, unknown> = { truck_id: p.truckId, phone_id: p.phoneId };
    if (p.routeName) shift.route_code = p.routeName;
    if (routeStart) shift.start_time = montrealIso(date, routeStart);
    if (routeEnd && (!routeStart || routeEnd > routeStart)) shift.finish_time = montrealIso(date, routeEnd);
    if (p.route.secondTruck) shift.fuel_mode = 'two_trucks';
    await must(supabase.from('shift').update(shift).eq('shift_id', shiftId).select('shift_id'));

    for (const m of crew) {
      const from = m.start ?? routeStart;
      // A member who stopped before the route finished has left; the others stay on until it ends.
      const left = m.end && routeEnd && m.end < routeEnd && (!from || m.end > from) ? montrealIso(date, m.end) : null;
      const times = { ...(from ? { joined_at: montrealIso(date, from) } : {}), left_at: left };
      if (onRoute.has(m.employeeId!)) {
        await must(supabase.from('shift_crew_member').update(times)
          .eq('shift_id', shiftId).eq('employee_id', m.employeeId!).select('shift_crew_id'));
      } else {
        await must(supabase.from('shift_crew_member')
          .insert({ shift_id: shiftId, employee_id: m.employeeId, position: m.position, ...times }).select('shift_crew_id'));
      }
    }
    return p.existing ? t('paste.updated') : t('paste.created');
  }

  async function applyAll() {
    setBusy(true);
    const out: typeof results = [];
    for (const p of plans.filter((x) => x.problems.length === 0)) {
      try {
        out.push({ route: p.key, ok: true, text: await apply(p) });
      } catch (e) {
        out.push({ route: p.key, ok: false, text: explainError((e as Error).message) });
      }
    }
    setResults(out);
    setBusy(false);
    if (out.length && out.every((r) => r.ok)) { setText(''); setPicks({}); }
    onDone();
  }

  if (!options.data) return <div className="card muted">{options.error ?? t('common.loading')}</div>;
  const o = options.data;
  const ready = plans.filter((p) => p.problems.length === 0);
  const pick = (k: string, list: Option[], value: string | null) => (
    <select value={value ?? ''} onChange={(e) => setPicks({ ...picks, [k]: e.target.value })}>
      <option value="">{t('paste.choose')}</option>
      {list.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}
    </select>
  );

  return (
    <div className="card">
      <h2>{t('paste.title')} · {date}</h2>
      <p className="muted small">{t('paste.help')}</p>
      <textarea rows={6} wrap="off" style={{ width: '100%', fontFamily: 'monospace' }} value={text}
        placeholder={t('paste.placeholder')} onChange={(e) => { setText(e.target.value); setResults([]); }} />

      {results.length > 0 && text.trim() === '' && (
        <div className={`notice ${results.every((r) => r.ok) ? 'ok' : 'err'}`}>
          {results.map((r) => <div key={r.route}>{r.route} : {r.text}</div>)}
        </div>
      )}
      {text.trim() !== '' && plans.length === 0 && <div className="notice err">{t('paste.nothing')}</div>}
      {plans.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>{t('paste.route')}</th><th>{t('board.truck')}</th><th>{t('board.phone')}</th>
              <th>{t('board.crew')}</th><th>{t('paste.result')}</th>
            </tr></thead>
            <tbody>
              {plans.map((p) => (
                <tr key={p.key}>
                  <td><strong>{p.routeName ?? (p.route.route ? pick(`route:${p.key}`, o.routes, null) : '—')}</strong></td>
                  <td>
                    {p.truckId ? o.trucks.find((x) => x.id === p.truckId)?.label : pick(`truck:${p.key}`, o.trucks, null)}
                    {p.route.secondTruck && <div className="small muted">+ {p.route.secondTruck} ({t('paste.twoTrucks')})</div>}
                  </td>
                  <td>{p.phoneId ? o.phones.find((x) => x.id === p.phoneId)?.label : pick(`phone:${p.key}`, o.phones, null)}</td>
                  <td>
                    {p.members.map((m, j) => (
                      <div key={j} className="small">
                        {m.employeeId ? o.employees.find((x) => x.id === m.employeeId)?.label : <>{m.name} → {pick(`person:${p.key}:${j}`, o.employees, null)}</>}
                        {' '}({m.position ? t(`position.${m.position}`) : (
                          <select value="" onChange={(e) => setPicks({ ...picks, [`position:${p.key}:${j}`]: e.target.value })}>
                            <option value="">{t('position.pick')}</option>
                            <option value="driver">{t('position.driver')}</option>
                            <option value="navigator">{t('position.navigator')}</option>
                            <option value="onboarding">{t('position.onboarding')}</option>
                          </select>
                        )})
                        {' '}<span className="muted">{m.start ?? '…'} – {m.end ?? '…'}</span>
                      </div>
                    ))}
                  </td>
                  <td>
                    {p.problems.length
                      ? p.problems.map((x) => <div key={x} className="problem error small">{x}</div>)
                      : <span className="ok-text">{p.existing ? t('paste.willUpdate') : t('paste.willCreate')}</span>}
                    {results.filter((r) => r.route === p.key).map((r) => (
                      <div key={r.text} className={`small ${r.ok ? 'ok-text' : 'problem error'}`}>{r.text}</div>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <div className="row" style={{ marginTop: 12 }}>
        <button className="go" disabled={busy || ready.length === 0} onClick={applyAll}>
          {t('paste.apply', { count: ready.length })}
        </button>
        <button className="ghost" onClick={onCancel}>{t('common.cancel')}</button>
      </div>
    </div>
  );
}
