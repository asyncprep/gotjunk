import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import i18n from '../i18n';
import { supabase } from '../lib/supabase';
import CashPanel from './CashPanel';

const noop = () => undefined;
const cash = (over: Record<string, unknown> = {}) => ({
  cash_submission_id: 'c1', counted_cash: null, envelope_id: null, mismatch_resolution: null,
  verified_at: null, receiver: null, ...over,
});
const photo = { photo_id: 'p1', storage_path: 's/p1.jpg', captured_at: '2026-10-28T14:00:00Z', photo_kind: 'cash_submission' };

beforeAll(async () => {
  await i18n.changeLanguage('en');
  // Never reach the network: pretend every photo file is already in storage.
  vi.spyOn(supabase.storage, 'from').mockReturnValue({
    createSignedUrls: async (paths: string[]) => ({
      data: paths.map((path) => ({ path, signedUrl: `https://files.test/${path}`, error: null })),
      error: null,
    }),
  } as never);
});
afterEach(cleanup);

describe('CashPanel', () => {
  it('flags cash the crew has not declared yet', () => {
    render(<CashPanel expected={124.98} cash={null} photos={[]} busy={false} lang="en" onChange={noop} onSave={noop} />);
    expect(screen.getByText(/hasn’t declared the cash/)).toBeTruthy();
    expect(screen.getByText(/\$124\.98/)).toBeTruthy();
  });

  it('says there is no cash when none was expected', () => {
    render(<CashPanel expected={0} cash={null} photos={[]} busy={false} lang="en" onChange={noop} onSave={noop} />);
    expect(screen.getByText('No cash reported.')).toBeTruthy();
  });

  it('waits for the count, and warns when the cash photo is missing', () => {
    render(<CashPanel expected={114.98} cash={cash()} photos={[]} busy={false} lang="en" onChange={noop} onSave={noop} />);
    expect(screen.getByText(/To count/)).toBeTruthy();
    expect(screen.getByText(/Cash photo missing/)).toBeTruthy();
  });

  it('shows a balanced count in green', () => {
    const { container } = render(
      <CashPanel expected={114.98} cash={cash({ counted_cash: '114.98' })} photos={[photo]} busy={false} lang="en" onChange={noop} onSave={noop} />);
    expect(screen.getByText(/Balanced/)).toBeTruthy();
    expect(container.querySelector('.tile.good')).toBeTruthy();
  });

  it('shows a shortfall in red with the signed difference', () => {
    const { container } = render(
      <CashPanel expected={114.98} cash={cash({ counted_cash: '110' })} photos={[photo]} busy={false} lang="en" onChange={noop} onSave={noop} />);
    expect(screen.getByText(/Short/)).toBeTruthy();
    expect(container.querySelector('.tile.bad .v')?.textContent).toBe('-$4.98');
  });

  it('shows who received the cash and when', () => {
    render(<CashPanel expected={50} cash={cash({ counted_cash: '60', verified_at: '2026-10-28T22:00:00Z',
      receiver: { email: 'dispatch@example.com' }, envelope_id: 'ENV-7' })} photos={[photo]} busy={false} lang="en"
      onChange={noop} onSave={noop} />);
    expect(screen.getByText(/Over/)).toBeTruthy();
    expect(screen.getByText(/dispatch@example\.com/)).toBeTruthy();
    expect(screen.getByText(/ENV-7/)).toBeTruthy();
  });
});
