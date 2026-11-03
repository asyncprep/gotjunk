// Lists one day's Stripe payments (read-only), to see where Stripe keeps the Opportunity ID,
// the tip and the card reader (questions F2 and F8). Only signed-in admins / senior ops may call it.
// The restricted key (STRIPE_API_KEY, Edge Function secret) never leaves this function, and
// customer names, emails and card numbers are not returned.
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const TZ = 'America/Toronto';

// Unix seconds of local midnight in Montréal for a YYYY-MM-DD date.
function localMidnight(date: string): number {
  const guess = new Date(`${date}T00:00:00Z`);
  const offset = new Intl.DateTimeFormat('en-US', { timeZone: TZ, timeZoneName: 'longOffset' })
    .formatToParts(guess).find((p) => p.type === 'timeZoneName')!.value; // e.g. "GMT-04:00"
  const m = offset.match(/GMT([+-])(\d{2}):(\d{2})/);
  const minutes = m ? (m[1] === '-' ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 0;
  return Math.floor(guess.getTime() / 1000) - minutes * 60;
}

async function stripe(path: string, key: string) {
  const res = await fetch(`https://api.stripe.com/v1/${path}`, { headers: { Authorization: `Bearer ${key}` } });
  const body = await res.json();
  if (!res.ok) throw new Error(body?.error?.message ?? `stripe_${res.status}`);
  return body;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const caller = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });
  const { data: callerRole } = await caller.rpc('current_app_role');
  if (callerRole !== 'admin' && callerRole !== 'senior_ops') {
    return json({ error: 'not_allowed: only administration can read Stripe' }, 403);
  }

  const key = Deno.env.get('STRIPE_API_KEY');
  if (!key) return json({ error: 'stripe_key_missing' }, 500);
  if (!key.startsWith('rk_')) return json({ error: 'not_a_restricted_key: use a read-only restricted key (rk_…)' }, 400);

  const { date } = await req.json().catch(() => ({}));
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return json({ error: 'invalid_date' }, 400);
  const from = localMidnight(date);
  const next = new Date(`${date}T12:00:00Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  const to = localMidnight(next.toISOString().slice(0, 10));

  try {
    const charges: any[] = [];
    let after = '';
    for (let page = 0; page < 5; page++) {
      const list = await stripe(
        `charges?limit=100&created[gte]=${from}&created[lt]=${to}&expand[]=data.payment_intent${after}`, key);
      charges.push(...list.data);
      if (!list.has_more) break;
      after = `&starting_after=${list.data[list.data.length - 1].id}`;
    }

    const payments = charges.map((c) => {
      const pi = typeof c.payment_intent === 'object' ? c.payment_intent : null;
      const pm = c.payment_method_details ?? {};
      return {
        id: c.id,
        at: new Date(c.created * 1000).toLocaleString('sv-SE', { timeZone: TZ }),
        amount: c.amount / 100,
        refunded: c.amount_refunded / 100,
        currency: c.currency,
        status: c.status,
        method: pm.type ?? null,
        reader: pm.card_present?.reader ?? pm.interac_present?.reader ?? null,
        description: c.description ?? pi?.description ?? null,
        statement_descriptor: c.calculated_statement_descriptor ?? null,
        charge_metadata: c.metadata ?? {},
        payment_intent_metadata: pi?.metadata ?? {},
        amount_details: pi?.amount_details ?? null,
        invoice: c.invoice ?? null,
        application: c.application ?? null,
        on_behalf_of: c.on_behalf_of ?? null,
        has_customer: Boolean(c.customer),
      };
    });

    return json({ date, count: payments.length, payments });
  } catch (e) {
    return json({ error: (e as Error).message }, 502);
  }
});
