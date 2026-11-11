import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import i18n from '../i18n';
import ReportWidget from '../components/ReportWidget';
import { TicketList, TicketPage } from './Tickets';

const { from, inserted, updated, auth } = vi.hoisted(() => ({
  from: vi.fn(), inserted: vi.fn(), updated: vi.fn(),
  auth: { role: 'dispatcher', session: { user: { id: 'me', email: 'me@test.ca' } } },
}));
vi.mock('../lib/supabase', async (original) => ({
  ...(await original<typeof import('../lib/supabase')>()),
  supabase: { from, storage: { from: () => ({ createSignedUrls: async () => ({ data: [], error: null }) }) } },
}));
vi.mock('../lib/auth', () => ({ useAuth: () => auth }));

const ticket = (over: Record<string, unknown>) => ({
  ticket_id: 't1', number: 1, type: 'bug', status: 'new', priority: 'normal', area: 'board', title: 'Board is blank',
  page_url: '', description: 'Nothing shows', steps: '', expected: '', frequency: null, reason: '', attachments: [],
  context: {}, spec_ref: null, reporter_email: 'd@test.ca', reporter_name: 'Dee', resolved_at: null,
  created_at: '2026-11-10T12:00:00Z', updated_at: '2026-11-10T12:00:00Z', ...over,
});
const tickets = [
  ticket({}),
  ticket({ ticket_id: 't2', number: 2, type: 'question', title: 'F8 · Which card reader per truck?', status: 'done', spec_ref: 'F8' }),
  ticket({ ticket_id: 't3', number: 3, type: 'suggestion', title: 'Show tips on the board', status: 'waiting' }),
];
const comments = [
  { comment_id: 'c1', ticket_id: 't1', kind: 'event', body: '', event_field: 'status', event_from: 'new', event_to: 'in_progress',
    attachments: [], author_email: 'a@test.ca', author_name: 'Ann', created_at: '2026-11-10T13:00:00Z' },
  { comment_id: 'c2', ticket_id: 't1', kind: 'comment', body: 'Looking at it', event_field: null, event_from: null, event_to: null,
    attachments: [], author_email: 'a@test.ca', author_name: 'Ann', created_at: '2026-11-10T13:05:00Z' },
];

// A query that can be chained, and awaited at any point.
const query = (data: unknown, single = false) => {
  const q: any = {
    select: () => q, order: () => q, in: () => q, limit: () => q,
    // Filters like the database does, so counts in the page are real.
    eq: (col: string, val: unknown) => query(Array.isArray(data) ? data.filter((r) => String(r[col]) === String(val)) : data, single),
    maybeSingle: () => query(Array.isArray(data) ? data[0] ?? null : data, true),
    single: () => query(Array.isArray(data) ? data[0] : data, true),
    then: (done: (r: unknown) => void) => done({ data: single ? data : data, error: null }),
  };
  return q;
};

beforeAll(async () => {
  await i18n.changeLanguage('en');
});
beforeEach(() => {
  localStorage.clear();
  inserted.mockReset();
  updated.mockReset();
  from.mockReset();
  from.mockImplementation((table: string) => {
    if (table === 'ticket') {
      return {
        ...query(tickets),
        insert: (row: unknown) => { inserted(row); return query([{ number: 4, title: (row as { title: string }).title }]); },
        update: (row: unknown) => { updated(row); return query([]); },
      };
    }
    if (table === 'ticket_comment') return { ...query(comments), insert: (row: unknown) => { inserted(row); return query([]); } };
    return query([]);
  });
});
afterEach(cleanup);

describe('Ticket list', () => {
  it('shows open tickets first, closed ones in their own tab', async () => {
    render(<MemoryRouter><TicketList /></MemoryRouter>);
    await screen.findByText('Board is blank');
    expect(screen.getByText('Show tips on the board')).toBeTruthy();
    expect(screen.queryByText('F8 · Which card reader per truck?')).toBeNull();
    expect(screen.getByText('1 comment')).toBeTruthy();
    fireEvent.click(screen.getByRole('tab', { name: /Closed/ }));
    expect(screen.getByText('F8 · Which card reader per truck?')).toBeTruthy();
  });
});

describe('One ticket', () => {
  it('shows the description, the trail and comments; changing the status saves it', async () => {
    render(
      <MemoryRouter initialEntries={['/tickets/1']}>
        <Routes><Route path="/tickets/:number" element={<TicketPage />} /></Routes>
      </MemoryRouter>,
    );
    await screen.findByRole('heading', { name: 'Board is blank' });
    expect(screen.getByText('Nothing shows')).toBeTruthy();
    expect(screen.getByText(/Status : New → In progress/)).toBeTruthy();
    expect(screen.getByText('Looking at it')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'done' } });
    await waitFor(() => expect(updated).toHaveBeenCalledWith({ status: 'done' }));
  });
});

describe('Report button', () => {
  it('files a bug from the page it was opened on, with the technical details', async () => {
    render(<MemoryRouter initialEntries={['/config']}><ReportWidget /></MemoryRouter>);
    fireEvent.click(screen.getByRole('button', { name: /Report a bug/ }));
    const form = screen.getByRole('dialog');
    fireEvent.click(within(form).getByRole('button', { name: 'Send ticket' }));
    expect(within(form).getByText('Give it a short title.')).toBeTruthy();
    expect(inserted).not.toHaveBeenCalled();

    fireEvent.change(within(form).getByLabelText(/Short title/), { target: { value: 'Fuel % does not save' } });
    fireEvent.change(within(form).getByLabelText(/What went wrong/), { target: { value: 'Saving shows an error' } });
    expect((within(form).getByLabelText(/Part of the app/) as HTMLSelectElement).value).toBe('config');
    fireEvent.click(within(form).getByRole('radio', { name: /High/ }));
    fireEvent.click(within(form).getByRole('button', { name: 'Send ticket' }));
    await within(form).findByText('Ticket #4 sent');
    const row = inserted.mock.calls[0][0];
    expect(row).toMatchObject({ type: 'bug', title: 'Fuel % does not save', area: 'config', priority: 'high' });
    expect(row.context.userAgent).toBeTruthy();
    expect(row.context.recentPages[0].path).toBe('/config');
  });

  it('asks a question for the client without the bug-only fields', async () => {
    render(<MemoryRouter><ReportWidget /></MemoryRouter>);
    fireEvent.click(screen.getByRole('button', { name: /Report a bug/ }));
    const form = screen.getByRole('dialog');
    fireEvent.click(within(form).getByRole('radio', { name: /Question for the client/ }));
    expect(within(form).queryByLabelText(/Steps to make it happen again/)).toBeNull();
    fireEvent.change(within(form).getByLabelText(/Short title/), { target: { value: 'Does onboarding count in team hours?' } });
    fireEvent.change(within(form).getByLabelText(/What is the question/), { target: { value: 'And does it get a share?' } });
    fireEvent.click(within(form).getByRole('button', { name: 'Send ticket' }));
    await waitFor(() => expect(inserted).toHaveBeenCalled());
    expect(inserted.mock.calls[0][0]).toMatchObject({ type: 'question', steps: '', frequency: null });
  });
});
