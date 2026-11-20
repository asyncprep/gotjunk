// Ticket feed for Central (central.innodigital.ca), following Central's connector spec
// (docs/connector-spec.md in the Central repo).
//
// GET   /central-tickets      every ticket, with its comments and the people Central can wait on.
// PATCH /central-tickets/{id} Central changes a ticket: its status, a note in Central's name, or a
//                             reply written in Central under an admin's name.
//
// Sends titles, state, dates, descriptions and comments (author name and text). Never the
// reporter, the browser context, attachments or the change trail: those can hold personal details
// and Central has no use for them.
//
// GotJunk tickets have no owner: they are all Khalil's. Central may still send `assignee` when it
// hands a ticket over; it is accepted and ignored, and the ticket waits (status) instead.
//
// The key is the CENTRAL_FEED_KEY Edge Function secret. Unset means the feed is off (503); a wrong
// or missing key is 401. Rotating it is changing the secret, then the key in Central.
//
// Closed tickets are not aged out: Central marks a ticket that disappears from the feed as
// cancelled, which would rewrite a finished ticket's outcome.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0';

const STATUS: Record<string, string> = { new: 'open', in_progress: 'in_progress', waiting: 'waiting', done: 'done', wont_do: 'cancelled' };
const FROM_CENTRAL: Record<string, string> = Object.fromEntries(Object.entries(STATUS).map(([ours, theirs]) => [theirs, ours]));
const PRIORITY: Record<string, string> = { blocker: 'urgent', high: 'high', normal: 'medium', low: 'low' };
const KIND: Record<string, string> = { bug: 'Bug', suggestion: 'Suggestion', question: 'Question' };
const ADMIN_URL = Deno.env.get('ADMIN_URL') ?? 'https://gotjunk.innodigital.ca';
// Ceilings, so the response cannot grow without limit. Central keeps the latest 50 comments.
const MAX = 500;
const MAX_COMMENTS = 50;
const MAX_TEXT = 10_000;
// Who Central can wait on and reply as: the people who handle tickets, not the crew.
const PEOPLE_ROLES = ['admin', 'senior_ops'];
// Central's own notes are written under this name, with no author.
const CENTRAL = 'Central';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const headers = {
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
  'X-Robots-Tag': 'noindex, nofollow',
};
const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(body === null ? null : JSON.stringify(body), { status, headers: { ...headers, ...extra } });

const sha256 = async (s: string) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));

// Hash both sides so the comparison takes the same time whatever the lengths.
async function sameKey(given: string, expected: string) {
  const [a, b] = await Promise.all([sha256(given), sha256(expected)]);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

const iso = (v: string | null) => (v == null ? null : new Date(v).toISOString());

type Person = { id: string; name: string };

// The active admins and senior ops, by their employee name, else their email.
async function people(db: SupabaseClient): Promise<Person[]> {
  const { data: rows, error } = await db
    .from('app_user')
    .select('user_id, employee:employee_id(full_name)')
    .eq('active', true)
    .in('role', PEOPLE_ROLES);
  if (error) throw new Error(error.message);
  const { data: auth, error: authError } = await db.auth.admin.listUsers({ perPage: 1000 });
  if (authError) throw new Error(authError.message);
  const emails = new Map(auth.users.map((u) => [u.id, u.email ?? '']));
  return rows
    .map((r) => {
      const employee = r.employee as { full_name?: string } | null;
      return { id: r.user_id as string, name: (employee?.full_name || emails.get(r.user_id as string) || '').trim() };
    })
    .filter((p) => p.name)
    .sort((a, b) => a.name.localeCompare(b.name));
}

async function feed(req: Request, db: SupabaseClient) {
  const { data: rows, error } = await db
    .from('ticket')
    .select('ticket_id, number, type, status, priority, title, description, created_at, updated_at, resolved_at, ticket_comment(kind, body, author_id, author_name, created_at)')
    .eq('ticket_comment.kind', 'comment')
    .order('updated_at', { ascending: false })
    .order('created_at', { referencedTable: 'ticket_comment', ascending: false })
    .limit(MAX_COMMENTS, { referencedTable: 'ticket_comment' })
    .limit(MAX);
  if (error) return json({ error: 'read_failed', message: error.message }, 500);

  let team: Person[];
  try {
    team = await people(db);
  } catch (e) {
    return json({ error: 'read_failed', message: (e as Error).message }, 500);
  }

  const payload = {
    version: 1,
    // Comments and status changes both bump updated_at, so it is the activity clock.
    lastActivityAt: rows.length ? iso(rows[0].updated_at) : null,
    updateUrl: `${Deno.env.get('SUPABASE_URL')}/functions/v1/central-tickets/{id}`,
    people: team,
    tickets: rows.map((r) => ({
      id: r.ticket_id,
      title: `[${KIND[r.type] ?? r.type}] #${r.number} ${r.title}`,
      status: STATUS[r.status] ?? 'open',
      priority: PRIORITY[r.priority] ?? 'medium',
      body: r.description?.trim() || null,
      assignee: null,
      assigneeId: null,
      dueDate: null,
      url: `${ADMIN_URL}/tickets/${r.number}`,
      createdAt: iso(r.created_at),
      updatedAt: iso(r.updated_at),
      closedAt: iso(r.resolved_at),
      // Oldest first, as a conversation reads.
      comments: (r.ticket_comment ?? [])
        .slice()
        .reverse()
        .map((c) => ({
          author: c.author_name || CENTRAL,
          // A note with no author is Central's own.
          authorType: c.author_id == null && (!c.author_name || c.author_name === CENTRAL) ? 'agent' : 'human',
          body: c.body,
          createdAt: iso(c.created_at),
        })),
    })),
  };

  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(payload)));
  const etag = `"${[...new Uint8Array(digest)].slice(0, 16).map((b) => b.toString(16).padStart(2, '0')).join('')}"`;
  if (req.headers.get('if-none-match')?.replace(/^W\//, '').trim() === etag) return json(null, 304, { ETag: etag });
  return json(payload, 200, { ETag: etag });
}

const text = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);

// Everything is checked before anything is written, so a refused change leaves the ticket as it was.
async function update(req: Request, db: SupabaseClient, id: string) {
  if (!UUID.test(id)) return json({ error: 'not_found' }, 404);
  let body: Record<string, unknown>;
  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error();
    body = parsed as Record<string, unknown>;
  } catch {
    return json({ error: 'bad_request', message: 'The body must be a JSON object.' }, 400);
  }

  const status = body.status === undefined ? null : FROM_CENTRAL[body.status as string];
  if (body.status !== undefined && !status) return json({ error: 'bad_status', message: 'Unknown status.' }, 422);
  const note = text(body.note);
  const reply = text(body.reply);
  if ((note?.length ?? 0) > MAX_TEXT || (reply?.length ?? 0) > MAX_TEXT) return json({ error: 'too_long' }, 422);

  let replyAs: Person | null = null;
  if (reply) {
    try {
      replyAs = (await people(db)).find((p) => p.id === String(body.replyAs ?? '')) ?? null;
    } catch (e) {
      return json({ error: 'read_failed', message: (e as Error).message }, 500);
    }
    if (!replyAs) return json({ error: 'bad_reply_as', message: 'Unknown replyAs.' }, 422);
  }

  const { data: ticket, error } = await db.from('ticket').select('ticket_id').eq('ticket_id', id).maybeSingle();
  if (error) return json({ error: 'read_failed', message: error.message }, 500);
  if (!ticket) return json({ error: 'not_found' }, 404);

  if (status) {
    const { error: e } = await db.from('ticket').update({ status }).eq('ticket_id', id);
    if (e) return json({ error: 'write_failed', message: e.message }, 500);
  }
  // With a reply, Central sends no note; the reply is what the person reads.
  const comment = reply
    ? { ticket_id: id, kind: 'comment', body: reply, author_name: `${replyAs!.name} (via Central)` }
    : note
      ? { ticket_id: id, kind: 'comment', body: note, author_name: CENTRAL }
      : null;
  if (comment) {
    const { error: e } = await db.from('ticket_comment').insert(comment);
    if (e) return json({ error: 'write_failed', message: e.message }, 500);
  }
  return json({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method !== 'GET' && req.method !== 'PATCH') return json({ error: 'method_not_allowed' }, 405);

  const expected = Deno.env.get('CENTRAL_FEED_KEY');
  if (!expected) return json({ error: 'feed_off', message: 'The Central feed is not switched on.' }, 503);

  // X-Central-Key first: some hosts drop Authorization before the code sees it.
  const given = (req.headers.get('x-central-key')?.trim() || req.headers.get('authorization')?.match(/^\s*Bearer\s+(\S+)/i)?.[1] || '').trim();
  if (!given) return json({ error: 'no_key', message: 'No API key was sent.' }, 401);
  if (!(await sameKey(given, expected))) return json({ error: 'bad_key', message: 'That API key is not valid.' }, 401);

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });

  // The ticket id is whatever follows the function's name in the path.
  const parts = new URL(req.url).pathname.split('/').filter(Boolean);
  const at = parts.lastIndexOf('central-tickets');
  const id = at >= 0 ? parts[at + 1] : undefined;

  if (req.method === 'GET') return id ? json({ error: 'not_found' }, 404) : feed(req, db);
  return id ? update(req, db, decodeURIComponent(id)) : json({ error: 'method_not_allowed' }, 405);
});
