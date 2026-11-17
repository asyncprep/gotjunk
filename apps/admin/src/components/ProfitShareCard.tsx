import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { money } from '../lib/supabase';
import { computeProfitShare, crewHours, planFromSetting, type CrewShareInput, type ShareBlock } from '../lib/profitShare';

type CrewRow = {
  employee_id: string; joined_at: string | null; left_at: string | null; trainer: boolean; damage_hold: boolean;
  employee?: { full_name: string } | null;
  frozen?: { name_fr: string; name_en: string; share_to_trainer: boolean;
    share_pct_low_cogs: number | null; share_pct_mid_cogs: number | null; share_pct_high_cogs: number | null } | null;
};

const num = (v: unknown) => (v === null || v === undefined || v === '' ? 0 : Number(v));
const pctOrNull = (v: unknown) => (v === null || v === undefined ? null : Number(v));
const date = (v: string | null | undefined) => (v ? new Date(v) : null);

/** The crew app's Profit share card, on the route page: same inputs, same calculation. */
export default function ProfitShareCard({ shift, crew, jobs, totals, planSetting }: {
  shift: any; crew: CrewRow[]; jobs: any[]; totals: any; planSetting: unknown;
}) {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const start = date(shift.start_time);
  const finish = date(shift.finish_time);
  const live = !!start && !finish;
  // While the route is going, hours count up to now: recalculate every minute, like the app.
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    if (!live) return;
    const id = setInterval(() => setNow(new Date()), 60_000);
    return () => clearInterval(id);
  }, [live]);

  // One line per person, even if they left and came back.
  const byPerson = new Map<string, CrewShareInput>();
  for (const c of crew) {
    const h = crewHours({ routeStart: start, routeFinish: finish, joinedAt: date(c.joined_at), leftAt: date(c.left_at), now });
    const prior = byPerson.get(c.employee_id);
    byPerson.set(c.employee_id, {
      employeeId: c.employee_id,
      name: c.employee?.full_name,
      hours: (prior?.hours ?? 0) + h,
      pctLowCogs: pctOrNull(c.frozen?.share_pct_low_cogs),
      pctMidCogs: pctOrNull(c.frozen?.share_pct_mid_cogs),
      pctHighCogs: pctOrNull(c.frozen?.share_pct_high_cogs),
      shareToTrainer: !!c.frozen?.share_to_trainer,
      trainer: c.trainer || !!prior?.trainer,
      damageHold: c.damage_hold || !!prior?.damageHold,
    });
  }
  const plan = planFromSetting(planSetting);
  const swingTrucks = num(shift.swing_truck_count) || (shift.swing_truck ? 1 : 0);
  const r = computeProfitShare(plan, {
    revenue: num(totals.revenue_pre_tax),
    jobs: num(totals.jobs_completed),
    cancels: jobs.filter((j) => j.outcome === 'cancelled_pending' || j.outcome === 'cancelled_confirmed').length,
    dumps: num(totals.net_disposal),
    crew: [...byPerson.values()],
    hoursType: shift.hours_type,
    fuelMode: shift.fuel_mode ?? 'one_truck',
    swingTrucks,
    trainingDay: !!shift.training_day,
    trainingHoursRemoved: num(shift.training_hours_removed),
  });

  const m = (v: number) => money(v, lang);
  const pct = (v: number) => `${new Intl.NumberFormat(lang === 'en' ? 'en-CA' : 'fr-CA', { maximumFractionDigits: 2 }).format(v)} %`;
  const hrs = (v: number) => new Intl.NumberFormat(lang === 'en' ? 'en-CA' : 'fr-CA', { maximumFractionDigits: 2 }).format(v);
  const status = r.qualifies ? t('share.qualifies') : live ? t('share.notYet') : t('share.notQualified');
  const trainerName = r.shares.find((s) => s.trainer)?.name;
  const block = (b: ShareBlock) => ({
    revenue: t('share.blockRevenue', { value: m(r.revenue), min: m(r.minRevenue) }),
    revenuePerHour: t('share.blockRph', { value: m(r.revenuePerHour), min: m(r.minRevenuePerHour) }),
    cogs: t('share.blockCogs', { max: pct(plan.maxCogsPct) }),
    hoursType: t('share.blockHours'),
  })[b];

  return (
    <div className="card">
      <div className="row">
        <h2 style={{ margin: 0 }}>{t('share.title')}</h2>
        <span className={`pill ${r.qualifies ? 'locked' : live ? 'in_progress' : 'returned'}`}>{status}</span>
      </div>
      <p className="muted small">{t('share.subtitle')}{live && <> {t('share.live')}</>}</p>
      {r.blocks.map((b) => <div key={b} className="problem warning small">! {block(b)}</div>)}

      <div className="tiles" style={{ marginTop: 12 }}>
        <div className="tile"><div className="v">{m(r.total)}</div><div className="k">{t('share.total')}</div></div>
        <div className="tile"><div className="v">{r.revenuePerHour ? m(r.revenuePerHour) : '—'}</div><div className="k">{t('share.rph')}</div></div>
        <div className="tile"><div className="v">{r.revenue > 0 ? pct(r.cogsPct) : '—'}</div><div className="k">{t('share.cogs')}</div></div>
        <div className="tile"><div className="v">{hrs(r.teamHours)} h</div><div className="k">{t('share.teamHours')}</div></div>
        <div className="tile"><div className="v">{r.averageJobSize ? m(r.averageJobSize) : '—'}</div><div className="k">{t('share.averageJob')}</div></div>
        <div className="tile"><div className="v">{pct(Math.round(r.cancelRate * 10000) / 100)}</div><div className="k">{t('share.cancelRate')}</div></div>
      </div>

      {r.shares.length > 0 && (
        <table style={{ marginTop: 12 }}>
          <thead>
            <tr><th>{t('share.person')}</th><th className="num">{t('share.pct')}</th><th className="num">{t('share.amount')}</th><th className="num">{t('share.paid')}</th></tr>
          </thead>
          <tbody>
            {r.shares.map((s) => {
              const note = s.held ? t('share.heldForDamage')
                : s.toTrainer ? (trainerName ? t('share.toTrainer', { name: trainerName }) : t('share.toTrainerNone'))
                  : s.trainer ? (s.fromTrainees > 0 ? t('share.trainerWith', { amount: m(s.fromTrainees) }) : t('share.trainer')) : '';
              return (
                <tr key={s.employeeId}>
                  <td>{s.name ?? '—'}{note && <div className={`small ${s.held ? 'err-text' : 'muted'}`}>{note}</div>}</td>
                  <td className="num">{s.pct == null ? <span className="muted small">{t('share.noRank')}</span> : pct(s.pct)}</td>
                  <td className="num">{m(s.amount)}</td>
                  <td className="num">{s.held ? <s>{m(s.amount + s.fromTrainees)}</s> : m(s.payout)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
      {r.qualifies && r.shares.some((s) => s.pct == null) && (
        <div className="problem warning small">! {t('share.missingRank', { names: r.shares.filter((s) => s.pct == null).map((s) => s.name ?? '—').join(', ') })}</div>
      )}
      {r.waitingForTrainer > 0 && <div className="problem warning small">! {t('share.waitingForTrainer', { amount: m(r.waitingForTrainer) })}</div>}

      <details style={{ marginTop: 12 }}>
        <summary>{t('share.details')}</summary>
        <table>
          <tbody>
            <tr><td>{t('share.revenue')}</td><td className="num">{m(r.revenue)}</td></tr>
            <tr><td>{t('share.wages', { hours: hrs(r.wageHours), rate: m(plan.wagePerHour) })}</td><td className="num">{m(r.wages)}</td></tr>
            <tr><td>{t('share.dumps')}</td><td className="num">{m(r.dumps)}</td></tr>
            <tr><td>{t('share.franchise', { pct: pct(plan.franchisePct) })}</td><td className="num">{m(r.franchise)}</td></tr>
            <tr><td>{t('share.fuel', { pct: pct(r.fuelPct) })}</td><td className="num">{m(r.fuel)}</td></tr>
            {r.swingTruck > 0 && <tr><td>{t('share.swing', { count: swingTrucks })}</td><td className="num">{m(r.swingTruck)}</td></tr>}
            <tr><th>{t('share.totalCogs')}</th><th className="num">{m(r.cogs)}</th></tr>
            <tr><th>{t('share.cogs')}</th><th className="num">{r.revenue > 0 ? pct(r.cogsPct) : '—'}</th></tr>
          </tbody>
        </table>
      </details>

      <p className="muted small" style={{ marginTop: 12 }}>
        {t('share.inputs')}: {t('share.fuelMode')} — {t(`share.fuel_${shift.fuel_mode ?? 'one_truck'}`)}
        {' · '}{t('share.swingTrucks')} — {swingTrucks}
        {' · '}{t('share.trainingDay')} — {shift.training_day ? t('share.trainingHours', { hours: hrs(num(shift.training_hours_removed)) }) : t('share.no')}
      </p>
    </div>
  );
}
