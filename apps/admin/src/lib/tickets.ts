import { supabase } from './supabase';

/** Bug reports, change requests and questions for the client (table `ticket`). */
export const TICKET_TYPES = ['bug', 'suggestion', 'question'] as const;
export type TicketType = (typeof TICKET_TYPES)[number];
export const TICKET_STATUSES = ['new', 'in_progress', 'waiting', 'done', 'wont_do'] as const;
export type TicketStatus = (typeof TICKET_STATUSES)[number];
export const OPEN_STATUSES: TicketStatus[] = ['new', 'in_progress', 'waiting'];
export const TICKET_PRIORITIES = ['blocker', 'high', 'normal', 'low'] as const;
export type TicketPriority = (typeof TICKET_PRIORITIES)[number];
export const FREQUENCIES = ['always', 'sometimes', 'once'] as const;
export type Frequency = (typeof FREQUENCIES)[number];
/** Parts of the product a ticket is about: the admin pages, then the crew app and the topics. */
export const TICKET_AREAS = [
  'board', 'route_review', 'crew_app', 'profit_share', 'jobs', 'disposal', 'cash', 'payments',
  'integrations', 'team', 'config', 'audit', 'guides', 'login', 'other',
] as const;

/** A file in the private `ticket-files` bucket. */
export type Attachment = { path: string; name: string; type: string };

export type Ticket = {
  ticket_id: string;
  number: number;
  type: TicketType;
  status: TicketStatus;
  priority: TicketPriority;
  area: string;
  title: string;
  page_url: string;
  description: string;
  steps: string;
  expected: string;
  frequency: Frequency | null;
  reason: string;
  attachments: Attachment[];
  context: TicketContext;
  spec_ref: string | null;
  reporter_email: string;
  reporter_name: string;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
};

export type TicketComment = {
  comment_id: string;
  kind: 'comment' | 'event';
  body: string;
  event_field: string | null;
  event_from: string | null;
  event_to: string | null;
  attachments: Attachment[];
  author_email: string;
  author_name: string;
  created_at: string;
};

export type TicketContext = {
  url?: string;
  userAgent?: string;
  platform?: string;
  language?: string;
  appLanguage?: string;
  timezone?: string;
  viewport?: { width: number; height: number };
  screen?: { width: number; height: number; pixelRatio: number };
  touch?: boolean;
  online?: boolean;
  signedInAs?: string;
  recentPages?: { path: string; at: string }[];
  consoleErrors?: { message: string; at: string }[];
};

/** Best guess of the part of the app from where the report was opened. */
export function areaFromPath(path: string): string {
  if (path === '/' || path === '') return 'board';
  if (path.startsWith('/shift/')) return 'route_review';
  for (const a of ['config', 'team', 'audit', 'payments', 'guides'] as const) if (path.startsWith(`/${a}`)) return a;
  return 'other';
}

/** Opens the report form from anywhere (the ticket list uses it for "New ticket"). */
export const openReport = (type: TicketType = 'bug') =>
  window.dispatchEvent(new CustomEvent('tto:report', { detail: type }));

/** Tells the open-ticket counter in the menu to refresh. */
export const ticketsChanged = () => window.dispatchEvent(new Event('tto:tickets'));

const BUCKET = 'ticket-files';
export const MAX_FILE_BYTES = 50 * 1024 * 1024;

export async function uploadAttachment(file: File): Promise<Attachment> {
  if (file.size > MAX_FILE_BYTES) throw new Error('file_too_big');
  const safe = file.name.normalize('NFKD').replace(/[^\w.-]+/g, '-').replace(/^-+|-+$/g, '').slice(-80) || 'file';
  const path = `${crypto.randomUUID()}/${safe}`;
  const { error } = await supabase.storage.from(BUCKET).upload(path, file, { contentType: file.type || undefined });
  if (error) throw new Error(error.message);
  return { path, name: file.name, type: file.type };
}

/** Short-lived links to show or download private files. */
export async function signedUrls(paths: string[]): Promise<Record<string, string>> {
  if (!paths.length) return {};
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrls(paths, 3600);
  if (error) throw new Error(error.message);
  return Object.fromEntries((data ?? []).flatMap((d) => (d.signedUrl && d.path ? [[d.path, d.signedUrl]] : [])));
}
