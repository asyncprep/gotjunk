// Read-only ticket feed for Central (central.innodigital.ca), following Central's connector spec
// (docs/connector-spec.md in the Central repo): Central calls it every 15 minutes with the key.
//
// Sends the title, state, dates and the description only. Never the reporter, the browser
// context, attachments or comments: those can hold personal details and Central has no use for them.
//
// The key is the CENTRAL_FEED_KEY Edge Function secret. Unset means the feed is off (503); a wrong
// or missing key is 401. Rotating it is changing the secret, then the key in Central.
//
// Closed tickets are not aged out: Central marks a ticket that disappears from the feed as
// cancelled, which would rewrite a finished ticket's outcome.
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

const STATUS: Record<string, string> = { new: 'open', in_progress: 'in_progress', waiting: 'waiting', done: 'done', wont_do: 'cancelled' };
const PRIORITY: Record<string, string> = { blocker: 'urgent', high: 'high', normal: 'medium', low: 'low' };
const KIND: Record<string, string> = { bug: 'Bug', suggestion: 'Suggestion', question: 'Question' };
const ADMIN_URL = Deno.env.get('ADMIN_URL') ?? 'https://gotjunk.innodigital.ca';
// A ceiling, so the response cannot grow without limit.
const MAX = 500;

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

Deno.serve(async (req) => {
  if (req.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);

  const expected = Deno.env.get('CENTRAL_FEED_KEY');
  if (!expected) return json({ error: 'feed_off', message: 'The Central feed is not switched on.' }, 503);

  // X-Central-Key first: some hosts drop Authorization before the code sees it.
  const given = (req.headers.get('x-central-key')?.trim() || req.headers.get('authorization')?.match(/^\s*Bearer\s+(\S+)/i)?.[1] || '').trim();
  if (!given) return json({ error: 'no_key', message: 'No API key was sent.' }, 401);
  if (!(await sameKey(given, expected))) return json({ error: 'bad_key', message: 'That API key is not valid.' }, 401);

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
  const { data: rows, error } = await db
    .from('ticket')
    .select('ticket_id, number, type, status, priority, title, description, created_at, updated_at, resolved_at')
    .order('updated_at', { ascending: false })
    .limit(MAX);
  if (error) return json({ error: 'read_failed', message: error.message }, 500);

  const payload = {
    version: 1,
    // Comments and status changes both bump updated_at, so it is the activity clock.
    lastActivityAt: rows.length ? iso(rows[0].updated_at) : null,
    tickets: rows.map((r) => ({
      id: r.ticket_id,
      title: `[${KIND[r.type] ?? r.type}] #${r.number} ${r.title}`,
      status: STATUS[r.status] ?? 'open',
      priority: PRIORITY[r.priority] ?? 'medium',
      body: r.description?.trim() || null,
      assignee: null,
      dueDate: null,
      url: `${ADMIN_URL}/tickets/${r.number}`,
      createdAt: iso(r.created_at),
      updatedAt: iso(r.updated_at),
      closedAt: iso(r.resolved_at),
    })),
  };

  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(payload)));
  const etag = `"${[...new Uint8Array(digest)].slice(0, 16).map((b) => b.toString(16).padStart(2, '0')).join('')}"`;
  if (req.headers.get('if-none-match')?.replace(/^W\//, '').trim() === etag) return json(null, 304, { ETag: etag });
  return json(payload, 200, { ETag: etag });
});
