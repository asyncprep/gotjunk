// Invites a dispatcher, admin or crew member by email and links the login to its role.
// Only signed-in admins / senior ops may call it. The service key never leaves this function.
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const ROLES = ['ttm', 'dispatcher', 'admin', 'senior_ops'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });

  const { data: callerRole } = await caller.rpc('current_app_role');
  if (callerRole !== 'admin' && callerRole !== 'senior_ops') {
    return json({ error: 'not_allowed: only administration can invite users' }, 403);
  }

  const { email, role, employee_id, can_edit_config, redirect_to } = await req.json().catch(() => ({}));
  if (typeof email !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: 'invalid_email' }, 400);
  if (!ROLES.includes(role)) return json({ error: 'invalid_role' }, 400);
  if (role === 'ttm' && !employee_id) return json({ error: 'employee_required: crew logins must be linked to an employee' }, 400);
  if (role === 'senior_ops' && callerRole !== 'senior_ops') return json({ error: 'not_allowed: only senior ops can invite senior ops' }, 403);

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: typeof redirect_to === 'string' ? redirect_to : undefined,
  });
  if (inviteError) return json({ error: inviteError.message }, 400);

  // Insert as the caller so row-level security applies and the audit log records who invited whom.
  const { error: linkError } = await caller.from('app_user').insert({
    user_id: invited.user.id,
    email: email.toLowerCase(),
    role,
    employee_id: employee_id ?? null,
    can_edit_config: Boolean(can_edit_config),
  });
  if (linkError) {
    await admin.auth.admin.deleteUser(invited.user.id);
    return json({ error: linkError.message }, 400);
  }

  return json({ user_id: invited.user.id });
});
