import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { businessToday, money, must, supabase } from '../lib/supabase';
import { useLoad } from '../lib/hooks';

// One day's Stripe payments, read through the stripe-day function (read-only key, admin only),
// next to the job with the same Opportunity ID in the app.
type Payment = {
  id: string; at: string; amount: number; refunded: number; status: string; method: string | null;
  reader: string | null; charge_metadata: Record<string, string>; payment_intent_metadata: Record<string, string>;
};
type Job = {
  opportunity_id: string; shift_id: string; revenue_total_incl_tax: number | null; tip_amount: number | null;
  shift: { shift_date: string; truck: { unit_number: string } | null } | null;
};

const QC_TAX = 1.14975; // GST 5% + QST 9.975%
const cents = (n: number) => Math.round(n * 100) / 100;

async function loadDay(date: string) {
  const { data, error } = await supabase.functions.invoke('stripe-day', { body: { date } });
  if (error) {
    const detail = await (error as any).context?.json?.().catch(() => null);
    throw new Error(detail?.error ?? error.message);
  }
  if ((data as any)?.error) throw new Error((data as any).error);
  const payments = ((data as any).payments as Payment[]).map((p) => {
    const m = { ...p.payment_intent_metadata, ...p.charge_metadata };
    const tip = Number(m.tip ?? 0);
    return {
      ...p, tip, opportunity: m.opportunity_id ?? '', login: (m.username ?? '').split('@')[0],
      typed: m.card_method_type === 'manual' || !p.reader, preTax: cents((p.amount - tip) / QC_TAX),
    };
  });
  const ids = [...new Set(payments.map((p) => p.opportunity).filter(Boolean))];
  const jobs = ids.length
    ? await must(supabase.from('job')
      .select('opportunity_id, shift_id, revenue_total_incl_tax, tip_amount, shift:shift_id(shift_date, truck:truck_id(unit_number))')
      .in('opportunity_id', ids)) as unknown as Job[]
    : [];
  return { payments, jobs };
}

export default function Payments() {
  const { t, i18n } = useTranslation();
  const [date, setDate] = useState(businessToday());
  const day = useLoad(() => loadDay(date), [date]);
  const lang = i18n.language;

  const payments = day.data?.payments ?? [];
  const ok = payments.filter((p) => p.status === 'succeeded');
  const byLogin = new Map<string, { count: number; amount: number; tips: number; preTax: number }>();
  for (const p of ok) {
    const s = byLogin.get(p.login) ?? { count: 0, amount: 0, tips: 0, preTax: 0 };
    s.count += 1; s.amount += p.amount - p.refunded; s.tips += p.tip; s.preTax += p.preTax;
    byLogin.set(p.login, s);
  }

  return (
    <>
      <div className="page-head"><h1>{t('stripe.title')}</h1></div>
      <div className="card">
        <p className="muted small">{t('stripe.intro')}</p>
        <div className="row">
          <label>{t('common.date')} <input type="date" value={date} onChange={(e) => setDate(e.target.value)} /></label>
          <button onClick={() => day.reload()} disabled={day.loading}>{t('ui.refresh')}</button>
        </div>
      </div>
      {day.error && <div className="notice err">{t('stripe.error')} {day.error}</div>}
      {day.loading && !day.data && <div className="muted">{t('common.loading')}</div>}
      {day.data && (
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
                    const job = day.data!.jobs.find((j) => j.opportunity_id === p.opportunity);
                    const expected = job ? cents(Number(job.revenue_total_incl_tax ?? 0) + Number(job.tip_amount ?? 0)) : null;
                    return (
                      <tr key={p.id} className={p.status === 'succeeded' ? '' : 'muted'}>
                        <td>{p.at.slice(11, 16)}</td>
                        <td>{p.opportunity || '—'}</td>
                        <td>{money(p.amount, lang)}{p.refunded > 0 && <span className="small"> ({t('stripe.refunded')} {money(p.refunded, lang)})</span>}</td>
                        <td>{money(p.tip, lang)}</td>
                        <td>{money(p.preTax, lang)}</td>
                        <td>{t(`stripe.st_${p.status}`, { defaultValue: p.status })}</td>
                        <td>{p.typed ? t('stripe.typed') : `${t('stripe.reader')} …${(p.reader ?? '').slice(-4)}`}</td>
                        <td>{p.login || '—'}</td>
                        <td>
                          {job ? (
                            <>
                              <Link to={`/shift/${job.shift_id}`}>{job.shift?.shift_date} · {job.shift?.truck?.unit_number ?? '—'}</Link>
                              {p.status === 'succeeded' && expected !== cents(p.amount) && (
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
