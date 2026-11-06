import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import i18n from '../i18n';
import Payments from './Payments';

const { invoke, from } = vi.hoisted(() => ({ invoke: vi.fn(), from: vi.fn() }));
vi.mock('../lib/supabase', async (original) => ({
  ...(await original<typeof import('../lib/supabase')>()),
  supabase: { functions: { invoke }, from },
}));

const charge = (id: string, opportunity_id: string, amount: number, refunded = 0) => ({
  id, at: '2026-11-05 09:00:00', amount, refunded, status: 'succeeded', method: 'card_present', reader: 'tmr_abcd',
  payment_intent_metadata: {}, charge_metadata: { opportunity_id, tip: '0', username: 'alex.maxwell@junk.com' },
});

beforeAll(async () => {
  await i18n.changeLanguage('en');
});
beforeEach(() => {
  invoke.mockReset();
  from.mockReset();
  invoke.mockImplementation(async () => ({
    data: { payments: [charge('ch_1', '100', 1032.48), charge('ch_2', '100', 1032.48, 1032.48), charge('ch_3', '200', 210), charge('ch_4', '200', 500)] },
    error: null,
  }));
  // The app has 200 = $710 (paid in two parts) and 100 = $1,032.48: neither differs from Stripe.
  from.mockReturnValue({
    select: () => ({
      in: async () => ({
        data: [
          { opportunity_id: '100', shift_id: 's1', revenue_total_incl_tax: 1032.48, tip_amount: 0, shift: null },
          { opportunity_id: '200', shift_id: 's2', revenue_total_incl_tax: 710, tip_amount: 0, shift: null },
        ],
        error: null,
      }),
    }),
  });
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
});

const show = () => render(<MemoryRouter><Payments /></MemoryRouter>);

describe('Payments', () => {
  it('leaves refunds out of the totals, and adds up a job paid in two parts', async () => {
    show();
    const row = (await screen.findAllByText('alex.maxwell'))[0];
    const cells = within(row.closest('tr')!).getAllByRole('cell').map((c) => c.textContent);
    expect(cells[1]).toBe('3');
    expect(cells[4]).toBe('$1,742.48');
    expect(screen.getByText('Refunded')).toBeTruthy();
    expect(screen.queryByText(/the app says/)).toBeNull();
  });

  it('reads Stripe again every minute', async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
    show();
    await waitFor(() => expect(invoke).toHaveBeenCalledTimes(1));
    await act(async () => { vi.advanceTimersByTime(60_000); });
    expect(invoke).toHaveBeenCalledTimes(2);
    await act(async () => { vi.advanceTimersByTime(120_000); });
    expect(invoke).toHaveBeenCalledTimes(4);
  });

  it('does not ask Stripe for an empty date', async () => {
    const { container } = show();
    await waitFor(() => expect(invoke).toHaveBeenCalledTimes(1));
    fireEvent.change(container.querySelector('input[type=date]')!, { target: { value: '' } });
    expect(invoke).toHaveBeenCalledTimes(1);
    expect(screen.queryByText(/invalid_date/)).toBeNull();
  });
});
