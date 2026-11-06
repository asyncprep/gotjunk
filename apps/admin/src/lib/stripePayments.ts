// Turns what the stripe-day function returns into what the Payments page shows. What a payment
// counts for is what was kept: a refund takes it out, and one job can be paid in several parts.
export type StripePayment = {
  id: string; at: string; amount: number; refunded: number; status: string; method: string | null;
  reader: string | null; charge_metadata: Record<string, string>; payment_intent_metadata: Record<string, string>;
};

export const QC_TAX = 1.14975; // GST 5% + QST 9.975%
export const cents = (n: number) => Math.round(n * 100) / 100;

export function readPayment(p: StripePayment) {
  const m = { ...p.payment_intent_metadata, ...p.charge_metadata };
  const kept = cents(p.amount - p.refunded);
  const fullyRefunded = p.refunded > 0 && kept <= 0;
  const tip = fullyRefunded ? 0 : Number(m.tip ?? 0);
  return {
    ...p, tip, kept, fullyRefunded,
    counts: p.status === 'succeeded' && !fullyRefunded,
    opportunity: m.opportunity_id ?? '',
    login: (m.username ?? '').split('@')[0],
    typed: m.card_method_type === 'manual' || !p.reader,
    preTax: cents(Math.max(kept - tip, 0) / QC_TAX),
  };
}

export type Payment = ReturnType<typeof readPayment>;

export function totalsByLogin(payments: Payment[]) {
  const totals = new Map<string, { count: number; amount: number; tips: number; preTax: number }>();
  for (const p of payments.filter((x) => x.counts)) {
    const s = totals.get(p.login) ?? { count: 0, amount: 0, tips: 0, preTax: 0 };
    s.count += 1; s.amount += p.kept; s.tips += p.tip; s.preTax += p.preTax;
    totals.set(p.login, s);
  }
  return totals;
}

/** What Stripe kept for each Opportunity ID, all its payments together. */
export function keptByOpportunity(payments: Payment[]) {
  const kept = new Map<string, number>();
  for (const p of payments.filter((x) => x.counts && x.opportunity)) {
    kept.set(p.opportunity, cents((kept.get(p.opportunity) ?? 0) + p.kept));
  }
  return kept;
}
