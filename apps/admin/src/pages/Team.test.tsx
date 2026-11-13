import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import i18n from '../i18n';
import Team from './Team';

const { from, update, auth } = vi.hoisted(() => ({
  from: vi.fn(), update: vi.fn(),
  auth: { role: 'admin', session: { user: { id: 'me' } } },
}));
vi.mock('../lib/supabase', async (original) => ({
  ...(await original<typeof import('../lib/supabase')>()),
  supabase: { from },
}));
vi.mock('../lib/auth', () => ({ useAuth: () => auth }));

const users = [
  { user_id: 'me', email: 'me@test.ca', role: 'admin', employee_id: null, employee: null, active: true },
  { user_id: 'd', email: 'd@test.ca', role: 'dispatcher', employee_id: null, employee: null, active: true },
  { user_id: 'c', email: 'c@test.ca', role: 'ttm', employee_id: 'e1', employee: { full_name: 'Crew One' }, active: true },
  { user_id: 's', email: 's@test.ca', role: 'senior_ops', employee_id: null, employee: null, active: true },
];
const employees = [
  { employee_id: 'e1', full_name: 'Crew One' }, { employee_id: 'e2', full_name: 'Crew Two' },
];

// A query that can be chained, and awaited at any point.
const query = (data: unknown) => {
  const q: any = {
    select: () => q, order: () => q, eq: () => q,
    then: (done: (r: unknown) => void) => done({ data, error: null }),
  };
  return q;
};

beforeAll(async () => {
  await i18n.changeLanguage('en');
});
beforeEach(() => {
  update.mockReset();
  from.mockReset();
  from.mockImplementation((table: string) => {
    if (table === 'app_user') return { ...query(users), update: (row: unknown) => { update(row); return query([]); } };
    return query(table === 'employee' ? employees : []);
  });
});
afterEach(cleanup);

async function openUsers() {
  render(<Team />);
  fireEvent.click(screen.getByRole('button', { name: 'Users' }));
  await screen.findByText('me@test.ca');
}
const picker = (email: string) => screen.queryByRole('combobox', { name: `Employee ${email}` }) as HTMLSelectElement | null;
const names = (s: HTMLSelectElement) => within(s).getAllByRole('option').map((o) => o.textContent);

describe('Linking a login to an employee', () => {
  it('saves the employee chosen on an existing login', async () => {
    await openUsers();
    fireEvent.change(picker('d@test.ca')!, { target: { value: 'e2' } });
    await waitFor(() => expect(update).toHaveBeenCalledWith({ employee_id: 'e2' }));
  });

  it('offers only employees without a login, and keeps a crew login linked', async () => {
    await openUsers();
    expect(names(picker('d@test.ca')!)).toEqual(['—', 'Crew Two']);
    expect(names(picker('c@test.ca')!)).toEqual(['Crew One', 'Crew Two']);
  });

  it('gives no list on your own login or on a senior ops login', async () => {
    await openUsers();
    expect(picker('me@test.ca')).toBeNull();
    expect(picker('s@test.ca')).toBeNull();
  });
});

const rolePicker = (email: string) => screen.queryByRole('combobox', { name: `Role ${email}` }) as HTMLSelectElement | null;

describe('Changing the role of a login', () => {
  it('saves the role chosen on another login', async () => {
    await openUsers();
    fireEvent.change(rolePicker('d@test.ca')!, { target: { value: 'admin' } });
    await waitFor(() => expect(update).toHaveBeenCalledWith({ role: 'admin' }));
  });

  it('offers crew only to a login linked to an employee, and never senior ops to an admin', async () => {
    await openUsers();
    const opts = (email: string) => Object.fromEntries(within(rolePicker(email)!).getAllByRole('option')
      .map((o) => [(o as HTMLOptionElement).value, (o as HTMLOptionElement).disabled]));
    expect(opts('d@test.ca')).toEqual({ dispatcher: false, admin: false, ttm: true });
    expect(opts('c@test.ca')).toEqual({ dispatcher: false, admin: false, ttm: false });
  });

  it('gives no role list on your own login or on a senior ops login', async () => {
    await openUsers();
    expect(rolePicker('me@test.ca')).toBeNull();
    expect(rolePicker('s@test.ca')).toBeNull();
  });

  it('lets senior ops give senior ops', async () => {
    auth.role = 'senior_ops';
    try {
      await openUsers();
      expect(within(rolePicker('d@test.ca')!).getAllByRole('option').map((o) => (o as HTMLOptionElement).value))
        .toContain('senior_ops');
      expect(rolePicker('s@test.ca')).not.toBeNull();
    } finally {
      auth.role = 'admin';
    }
  });
});
