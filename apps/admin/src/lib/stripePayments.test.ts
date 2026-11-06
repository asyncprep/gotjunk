import { describe, expect, it } from 'vitest';
import { keptByOpportunity, readPayment, totalsByLogin, type StripePayment } from './stripePayments';

const charge = (over: Partial<StripePayment> & { tip?: string; opp?: string }): StripePayment => ({
  id: 'ch_1', at: '2026-11-05 08:53:35', amount: 100, refunded: 0, status: 'succeeded', method: 'card_present',
  reader: 'tmr_1', payment_intent_metadata: {},
  charge_metadata: { opportunity_id: over.opp ?? '1', tip: over.tip ?? '0', username: 'alex.maxwell@junk.com' },
  ...over,
});

describe('Stripe payments', () => {
  it('leaves a charge refunded in full out of the totals (a job charged twice by mistake)', () => {
    const payments = [charge({ amount: 1032.48 }), charge({ id: 'ch_2', amount: 1032.48, refunded: 1032.48, tip: '12' })].map(readPayment);
    const s = totalsByLogin(payments).get('alex.maxwell')!;
    expect(s.count).toBe(1);
    expect(s.amount).toBe(1032.48);
    expect(s.tips).toBe(0);
    expect(s.preTax).toBe(898);
    expect(payments[1].fullyRefunded).toBe(true);
    expect(payments[1].counts).toBe(false);
  });

  it('counts what was kept after a partial refund', () => {
    const p = readPayment(charge({ amount: 229.95, refunded: 114.97 }));
    expect(p.kept).toBe(114.98);
    expect(p.preTax).toBe(100);
    expect(p.counts).toBe(true);
  });

  it('adds up a job paid in two parts, and ignores failed attempts', () => {
    const kept = keptByOpportunity([
      charge({ amount: 210, opp: '19782395' }),
      charge({ id: 'ch_2', amount: 500, opp: '19782395' }),
      charge({ id: 'ch_3', amount: 500, opp: '19782395', status: 'failed' }),
    ].map(readPayment));
    expect(kept.get('19782395')).toBe(710);
  });
});
