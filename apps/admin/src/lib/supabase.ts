import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined;
if (!url || !key) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY (see .env.example)');
}

export const supabase = createClient(url, key);

export type Role = 'ttm' | 'dispatcher' | 'admin' | 'senior_ops';
export type ShiftStatus =
  | 'open' | 'in_progress' | 'submitted' | 'returned' | 'locked' | 'reopened' | 'reconciled' | 'archived';

// Supabase returns { data, error }; turn errors into exceptions. Callers of maybeSingle() still
// get null at runtime when no row matches, and must handle it.
export async function must<T>(query: PromiseLike<{ data: T; error: { message: string } | null }>): Promise<NonNullable<T>> {
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return data as NonNullable<T>;
}

// Business dates are Montréal dates, whatever the browser's time zone.
export function businessToday(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Toronto' }).format(new Date());
}

export function money(value: unknown, lang: string): string {
  if (value === null || value === undefined || value === '') return '—';
  return new Intl.NumberFormat(lang === 'en' ? 'en-CA' : 'fr-CA', { style: 'currency', currency: 'CAD' })
    .format(Number(value));
}

export function time(value: string | null | undefined, lang: string): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat(lang === 'en' ? 'en-CA' : 'fr-CA', {
    timeZone: 'America/Toronto', hour: '2-digit', minute: '2-digit',
  }).format(new Date(value));
}

export function dateTime(value: string | null | undefined, lang: string): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat(lang === 'en' ? 'en-CA' : 'fr-CA', {
    timeZone: 'America/Toronto', dateStyle: 'short', timeStyle: 'short',
  }).format(new Date(value));
}

export const isAdminRole = (r: Role | null) => r === 'admin' || r === 'senior_ops';
