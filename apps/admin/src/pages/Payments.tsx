import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { businessToday, money, must, supabase, time } from '../lib/supabase';
import { useLoad } from '../lib/hooks';
import { cents, keptByOpportunity, readPayment, totalsByLogin, type StripePayment } from '../lib/stripePayments';

// One day's Stripe payments, read through the stripe-day function (read-only key, admin only),
// next to the job with the same Opportunity ID in the app.
type Job = {
  opportunity_id: string; shift_id: string; revenue_total_incl_tax: number | null; tip_amount: number | null;
  shift: { shift_date: string; truck: { unit_number: string } | null } | null;
};

async function loadDay(date: string) {
  const { data, error } = await supabase.functions.invoke('stripe-day', { body: { date } });
  if (error) {
    const detail = await (error as any).context?.json?.().catch(() => null);
    throw new Error(detail?.error ?? error.message);
  }
  if ((data as any)?.error) throw new Error((data as any).error);
  const payments = ((data as any).payments as StripePayment[]).map(readPayment);
  const ids = [...new Set(payments.map((p) => p.opportunity).filter(Boolean))];
  const jobs = ids.length
    ? await must(supabase.from('job')
      .select('opportunity_id, shift_id, revenue_total_incl_tax, tip_amount, shift:shift_id(shift_date, truck:truck_id(unit_number))')
      .in('opportunity_id', ids)) as unknown as Job[]
    : [];
  return { date, payments, jobs, updatedAt: new Date().toISOString() };
}

export default function Payments() {
  const { t, i18n } = useTranslation();
  const [date, setDate] = useState(businessToday());
  const day = useLoad(() => loadDay(date), [date]);
  const lang = i18n.language;

  // Keep the day current without a manual refresh: every minute and when the tab regains focus.
  useEffect(() => {
    const refresh = () => {
      if (document.visibilityState === 'visible') day.reload(true);
    };
    const timer = setInterval(refresh, 60_000);
    window.addEventListener('focus', refresh);
    return () => {
      clearInterval(timer);
      window.removeEventListener('focus', refresh);
    };
  }, [day.reload]);

  // While another date loads, the previous day's payments are not shown under the new date.
  const shown = day.data?.date === date ? day.data : null;
  const payments = shown?.payments ?? [];
  const byLogin = totalsByLogin(payments);
  const kept = keptByOpportunity(payments);

  return (
    <>
      <div className="page-head"><h1>{t('stripe.title')}</h1></div>
      <div className="card">
        <p className="muted small">{t('stripe.intro')}</p>
        <div className="row">
          <label>{t('common.date')} <input type="date" value={date} onChange={(e) => { if (e.target.value) setDate(e.target.value); }} /></label>
          <button onClick={() => day.reload()} disabled={day.loading}>{t('ui.refresh')}</button>
          {shown && <span className="muted small">{t('ui.updatedAt', { time: time(shown.updatedAt, lang) })}</span>}
        </div>
      </div>
      {day.error && <div className="notice err">{t('stripe.error')} {day.error}</div>}
      {day.loading && !shown && <div className="muted">{t('common.loading')}</div>}
      {shown && (
        <>
          <div className="card">
            <h2>{t('stripe.byLogin')}</h2>
            {byLogin.size === 0 ? <p className="muted">{t('stripe.none')}</p> : (
              <div className="table-wrap">
                <table>
                  <thead><tr>
                    <th>{t('stripe.login')}</th><th>{t('stripe.payments')}</th><th>{t('stripe.preTax')}</th>
                    <th>{t('stripe.tip')}</th><th>{t('stripe.amount')}</th>
                  </tr></thead>
                  <tbody>
                    {[...byLogin].map(([login, s]) => (
                      <tr key={login}>
                        <td>{login || '—'}</td><td>{s.count}</td><td>{money(cents(s.preTax), lang)}</td>
                        <td>{money(cents(s.tips), lang)}</td><td>{money(cents(s.amount), lang)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
          <div className="card">
            <h2>{t('stripe.list', { count: payments.length })}</h2>
            <div className="table-wrap">
              <table>
                <thead><tr>
                  <th>{t('stripe.time')}</th><th>{t('stripe.opportunity')}</th><th>{t('stripe.amount')}</th>
                  <th>{t('stripe.tip')}</th><th>{t('stripe.preTax')}</th><th>{t('stripe.status')}</th>
                  <th>{t('stripe.method')}</th><th>{t('stripe.login')}</th><th>{t('stripe.inApp')}</th>
                </tr></thead>
                <tbody>
                  {payments.map((p) => {
                    const job = shown.jobs.find((j) => j.opportunity_id === p.opportunity);
                    const expected = job ? cents(Number(job.revenue_total_incl_tax ?? 0) + Number(job.tip_amount ?? 0)) : null;
                    return (
                      <tr key={p.id} className={p.counts ? '' : 'muted'}>
                        <td>{p.at.slice(11, 16)}</td>
                        <td>{p.opportunity || '—'}</td>
                        <td>{money(p.amount, lang)}{p.refunded > 0 && <span className="small"> ({t('stripe.refunded')} {money(p.refunded, lang)})</span>}</td>
                        <td>{money(p.tip, lang)}</td>
                        <td>{money(p.preTax, lang)}</td>
                        <td>{p.fullyRefunded ? t('stripe.st_refunded') : t(`stripe.st_${p.status}`, { defaultValue: p.status })}</td>
                        <td>{p.typed ? t('stripe.typed') : `${t('stripe.reader')} …${(p.reader ?? '').slice(-4)}`}</td>
                        <td>{p.login || '—'}</td>
                        <td>
                          {job ? (
                            <>
                              <Link to={`/shift/${job.shift_id}`}>{job.shift?.shift_date} · {job.shift?.truck?.unit_number ?? '—'}</Link>
                              {p.counts && expected !== kept.get(p.opportunity) && (
                                <span className="problem warning small"> {t('stripe.differs', { amount: money(expected, lang) })}</span>
                              )}
                            </>
                          ) : <span className="muted">{t('stripe.notInApp')}</span>}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </>
  );
}
