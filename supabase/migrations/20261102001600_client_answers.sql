-- Truck Team OS: apply the client's answers on the Projet page (Nov 2, 2026) and the paper
-- profit-share sheet / filled route sheets of Oct 25, 2026.

-- J2: payment methods. The existing "card" becomes the credit card.
update public.payment_method set name_fr = 'Carte de crédit', name_en = 'Credit card' where code = 'card';
insert into public.payment_method (code, name_fr, name_en, is_cash, stripe_method_type) values
  ('debit_card', 'Carte de débit',   'Debit card', false, null),
  ('invoice',    'Facture',          'Invoice',    false, null),
  ('etransfer',  'Virement Interac', 'E-transfer', false, null)
on conflict (code) do nothing;

-- B4: cash tips are pocketed by the crew, so they are not part of the cash envelope.
update public.app_setting
   set value = 'false', description = 'Whether cash tips are part of expected cash (client answer B4: no, the crew keeps them)'
 where key = 'cash_includes_tips';

-- A5: ranks from the profit-share sheet. Trainer is a role, not a rank (kept, switched off).
update public.rank set name_fr = 'Professionnel', name_en = 'Professional', sort_order = 30 where code = 'sales_pro';
update public.rank set active = false where code = 'trainer';
insert into public.rank (code, name_fr, name_en, sort_order) values
  ('expert',   'Expert',       'Expert',   40),
  ('jr_coach', 'Coach junior', 'JR Coach', 50)
on conflict (code) do nothing;

-- Sheet: metal & electronics recycled at Eco-Junk earn a credit of $50 per 1,000 kg (it was set
-- up as a cost). Credits never use a minimum.
update public.site_rate_config c
   set direction = 'credit', min_billable_kg = 0, min_applies_to = 'never'
  from public.site s, public.material_type m
 where c.site_id = s.site_id and s.code = 'eco_junk'
   and c.material_type_id = m.material_type_id and m.code = 'metal_electronics'
   and c.direction = 'cost';

-- R3b/R3d: outside dumps are a list dispatch keeps in the admin: name, address, $ per ton, minimum.
alter table public.site add column address text;

insert into public.site (code, name, site_type, issues_tickets, requires_ticket_photo) values
  ('waste_management',  'Waste Management',  'outside_dump', true, true),
  ('ebi',               'EBI',               'outside_dump', true, true),
  ('depot_du_nord',     'Dépôt du Nord',     'outside_dump', true, true),
  ('waste_connections', 'Waste Connections', 'outside_dump', true, true)
on conflict (code) do nothing;

-- Sheet: all outside dumps $160 per 1,000 kg, minimum 1,000 kg (dispatch can change each one).
insert into public.site_rate_config (site_id, material_type_id, rate_per_ton, direction, min_billable_kg, min_applies_to, effective_from)
select s.site_id, m.material_type_id, 160, 'cost', 1000, 'transaction', date '2026-01-01'
  from public.site s, public.material_type m
 where s.code in ('waste_management', 'ebi', 'depot_du_nord', 'waste_connections') and m.code = 'mixed'
   and not exists (select 1 from public.site_rate_config c where c.site_id = s.site_id);

-- B2: dispatch can set the tip split by hand. Once any member of a route has an amount, the
-- route uses dispatch's amounts (blank = 0) instead of the equal split.
alter table public.shift_crew_member add column tip_override numeric(12,2) check (tip_override >= 0);

create function public.tips_overridden(p_shift_id uuid) returns boolean
language sql stable as $$
  select exists (select 1 from public.shift_crew_member where shift_id = p_shift_id and tip_override is not null)
$$;

create or replace view public.v_shift_tips_by_employee with (security_invoker = true) as
select m.shift_id, m.employee_id,
       (case when public.tips_overridden(m.shift_id) then coalesce(m.tip_override, 0)
             else coalesce(c.tips, 0) end)::numeric(12,2) as tips
from public.shift_crew_member m
left join (select shift_id, employee_id, sum(tip_share) as tips from public.v_tip_split group by shift_id, employee_id) c
  on c.shift_id = m.shift_id and c.employee_id = m.employee_id;

-- C3: a cash difference is shown but doesn't block acceptance, and needs no note.
-- B2: a hand-set tip split must add up to the route's tips.
create or replace function public.shift_problems(p_shift_id uuid, p_stage text default 'submit')
returns table (severity text, code text, entity_type text, entity_id uuid, detail text)
language plpgsql stable security definer set search_path = public as $$
declare
  s public.shift%rowtype;
  v_totals public.v_shift_totals%rowtype;
  v_crew int;
  v_cash public.cash_submission%rowtype;
begin
  if p_stage not in ('submit', 'lock') then
    raise exception 'invalid_stage: %', p_stage;
  end if;

  select * into s from public.shift where shift_id = p_shift_id;
  if not found then
    raise exception 'shift_not_found';
  end if;

  -- Signed-in callers may only inspect shifts they can see. Anonymous callers can't execute
  -- this function at all (see grants below); no JWT here means a backend/system call.
  if auth.uid() is not null and not (public.is_staff() or public.is_crew_member(p_shift_id)) then
    raise exception 'not_allowed';
  end if;

  select * into v_totals from public.v_shift_totals where shift_id = p_shift_id;
  select * into v_cash from public.cash_submission where shift_id = p_shift_id;

  select count(*) into v_crew from public.shift_crew_member
  where shift_id = p_shift_id and left_at is null;

  if v_crew < public.setting_num('crew_min') or v_crew > public.setting_num('crew_max') then
    return query select 'error', 'crew_size', 'shift', p_shift_id, v_crew::text;
  end if;
  if s.hours_type is null then
    return query select 'error', 'hours_type_missing', 'shift', p_shift_id, null::text;
  end if;
  if s.start_time is null then
    return query select 'error', 'start_time_missing', 'shift', p_shift_id, null::text;
  end if;
  if s.finish_time is null then
    return query select 'error', 'finish_time_missing', 'shift', p_shift_id, null::text;
  end if;

  return query
    select 'error', 'job_incomplete', 'job', j.job_id, j.opportunity_id
    from public.job j where j.shift_id = p_shift_id and j.outcome is null;

  return query
    select 'warning', 'tax_check', 'job', j.job_id, j.opportunity_id
    from public.job j
    where j.shift_id = p_shift_id and j.outcome = 'completed'
      and abs(j.revenue_total_incl_tax - round(j.revenue_pre_tax * (1 + public.setting_num('sales_tax_rate')), 2))
          > public.setting_num('tax_tolerance');

  return query
    select distinct 'warning', 'opportunity_repeated', 'job', j.job_id, j.opportunity_id
    from public.job j
    join public.job o on o.opportunity_id = j.opportunity_id and o.shift_id <> j.shift_id
    join public.shift os on os.shift_id = o.shift_id and os.status <> 'archived'
    where j.shift_id = p_shift_id;

  -- A tip must go to someone: no crew member present when the job was completed means the
  -- crew times are wrong. Dispatch fixes joined/left times, or sets the split by hand; blocks acceptance.
  return query
    select case when p_stage = 'lock' then 'error' else 'warning' end, 'tip_unassigned', 'job', j.job_id, j.opportunity_id
    from public.job j
    where j.shift_id = p_shift_id and j.outcome = 'completed' and j.tip_amount > 0
      and not exists (
        select 1 from public.shift_crew_member m
        where m.shift_id = j.shift_id
          and m.joined_at <= coalesce(j.completed_at, j.created_at)
          and (m.left_at is null or m.left_at > coalesce(j.completed_at, j.created_at)))
      and not public.tips_overridden(p_shift_id);

  -- Dispatch's own split must hand out exactly the route's tips (client answer B2).
  if public.tips_overridden(p_shift_id) and (
       select coalesce(sum(tip_override), 0) from public.shift_crew_member where shift_id = p_shift_id
     ) <> v_totals.tips then
    return query select case when p_stage = 'lock' then 'error' else 'warning' end, 'tip_override_mismatch', 'shift', p_shift_id,
      ((select coalesce(sum(tip_override), 0) from public.shift_crew_member where shift_id = p_shift_id) - v_totals.tips)::text;
  end if;

  return query
    select 'error', 'ticket_number_missing', 'disposal_visit', v.disposal_visit_id, st.name
    from public.disposal_visit v join public.site st on st.site_id = v.site_id
    where v.shift_id = p_shift_id and st.issues_tickets
      and coalesce(trim(v.ticket_number), '') = '';

  return query
    select 'error', 'ticket_photo_missing', 'disposal_visit', v.disposal_visit_id, st.name
    from public.disposal_visit v join public.site st on st.site_id = v.site_id
    where v.shift_id = p_shift_id and st.requires_ticket_photo
      and not exists (select 1 from public.photo p
                      where p.entity_type = 'disposal_visit' and p.entity_id = v.disposal_visit_id);

  return query
    select 'error', 'visit_no_materials', 'disposal_visit', v.disposal_visit_id, null::text
    from public.disposal_visit v
    where v.shift_id = p_shift_id
      and not exists (select 1 from public.disposal_material_txn t where t.disposal_visit_id = v.disposal_visit_id);

  if v_totals.expected_cash > 0 and not exists (
      select 1 from public.photo p where p.shift_id = p_shift_id and p.photo_kind = 'cash_submission') then
    return query select 'error', 'cash_photo_missing', 'shift', p_shift_id, v_totals.expected_cash::text;
  end if;

  if p_stage = 'lock' then
    if s.hours_type_confirmed_at is null then
      return query select 'error', 'hours_type_unconfirmed', 'shift', p_shift_id, null::text;
    end if;

    return query
      select 'error', 'checklist_incomplete', 'checklist_item', ci.item_id, ci.code
      from public.checklist_item ci
      where ci.active and ci.required
        and not exists (select 1 from public.shift_checklist_check c
                        where c.shift_id = p_shift_id and c.item_id = ci.item_id and c.checked);

    if v_totals.expected_cash > 0 and (v_cash.cash_submission_id is null or v_cash.counted_cash is null) then
      return query select 'error', 'cash_not_counted', 'shift', p_shift_id, v_totals.expected_cash::text;
    end if;

    -- A difference is shown to dispatch but doesn't block acceptance (client answer C3).
    if v_cash.counted_cash is not null and v_cash.counted_cash <> v_totals.expected_cash then
      return query select 'warning', 'cash_variance', 'cash_submission', v_cash.cash_submission_id,
        (v_cash.counted_cash - v_totals.expected_cash)::text;
    end if;

    -- Photo rows whose file never reached storage (phone lost, still offline…).
    if to_regclass('storage.objects') is not null then
      return query execute
        'select ''error''::text, ''photo_not_uploaded''::text, ''photo''::text, p.photo_id, p.photo_kind::text
           from public.photo p
          where p.shift_id = $1
            and not exists (select 1 from storage.objects o where o.bucket_id = ''photos'' and o.name = p.storage_path)'
        using p_shift_id;
    end if;

    return query
      select 'warning', 'cancellation_pending', 'job', j.job_id, j.opportunity_id
      from public.job j where j.shift_id = p_shift_id and j.outcome = 'cancelled_pending';
  end if;
end $$;
-- Projet page: what the system now does for each answer.
update public.spec_item set build_default = v.applied
from (values
  ('J2', $s$Applied: cash, credit card, debit card, invoice, e-transfer$s$),
  ('B4', $s$Applied: cash tips are not part of expected cash$s$),
  ('B2', $s$Applied: dispatch can set each crew member's tip amount on the route page; the amounts must add up to the route's tips$s$),
  ('C3', $s$Applied: the difference is shown to dispatch; it doesn't block acceptance and needs no note$s$),
  ('C1', $s$Applied: the envelope label is prefilled with date, crew lead and amount; dispatch's count records who signed off and when$s$),
  ('C2', $s$Applied: dispatch records the count (sign-off with name and time)$s$),
  ('D1', $s$Applied: Configuration → Checklist, with a "Required" switch per item$s$),
  ('R3a', $s$Applied: rates are per 1,000 kg$s$),
  ('R3b', $s$Applied: no minimum at Eco-Junk; each outside dump has its own minimum$s$),
  ('R3c', $s$Applied: credits never use a minimum$s$),
  ('R3d', $s$Applied: Configuration → Sites (name, address) and Rates ($ per ton, minimum). Waste Management, EBI, Dépôt du Nord and Waste Connections added at $160 per 1,000 kg, minimum 1,000 kg$s$),
  ('A5', $s$Applied: ranks Recruit, Wingman, Professional, Expert, JR Coach; Trainer switched off (it's a role)$s$),
  ('J4', $s$Applied: revenue before tax is entered after the discount$s$),
  ('J5', $s$Applied: one sales tax rate for every job$s$),
  ('E', $s$Applied: dispatch creates each route by hand in the admin$s$),
  ('G', $s$Applied: no limit; the phone keeps working offline$s$)
) as v(ref, applied)
where spec_item.ref = v.ref;

-- Follow-ups from the three filled route sheets of Oct 25, 2026.
update public.spec_item
   set detail = coalesce(detail || ' ', '') || $s$Three filled route sheets (Oct 25, 2026) were received; their numbers are written out in docs/profit-share.md. The daily tracker Excel is still to come.$s$
 where ref = 'A7';

update public.spec_item
   set detail = coalesce(detail || ' ', '') || $s$On Oct 25, two routes that used two trucks ("Pink/Onyx", "Pearl and Titan") were charged 7% fuel and no swing truck fee.$s$
 where ref = 'A11';

update public.spec_item
   set detail = coalesce(detail || ' ', '') || $s$On Oct 25 (truck Blanc), wages used 18.5 of 21.5 hours (3 removed) but revenue per hour used all 21.5, and only one of the two crew members got a profit share. Is that the training rule, and is the trainee never paid a share?$s$
 where ref = 'A13';

update public.spec_item
   set build_default = $s$Invitations and password resets still come from Supabase's address; using a GOT-JUNK address needs that mailbox's sending (SMTP) settings$s$
 where ref = 'S9';

insert into public.spec_item (kind, ref, area, priority, title, detail, blocks, build_default, sort_order) values
('question', 'A14', 'Profit share', 'v1b',
 $s$How much is the donation credit at Éco-Dépôt?$s$,
 $s$The sheet says $75 per 1,000 kg, but on Oct 25 (truck Blanc) 120 kg was credited $1.20 and 190 kg $1.40, which is about $10 per 1,000 kg. Metal was credited $50 per 1,000 kg as listed.$s$,
 $s$Disposal credits, profit share$s$, $s$$75 per 1,000 kg, as on the sheet$s$, 295),
('question', 'F9', 'Integrations', 'v1b',
 $s$Are card payments taken with Helcim, Stripe, or both?$s$,
 $s$The route sheet has a "Helcim Invoice #" column next to the tip. If cards go through Helcim, matching payments to jobs (F8) needs Helcim's data too.$s$,
 $s$Payment matching$s$, null, 675),
('question', 'S12', 'Approvals', 'pilot',
 $s$Which GOT-JUNK address should send invitations and password resets, and can we get its sending (SMTP) settings?$s$,
 $s$Answer S9 says "all GOT-JUNK emails". To send from that domain, the app needs the mailbox's SMTP server, user and password (entered by you in Supabase, never sent to us).$s$,
 $s$Sender address of invitation emails$s$, $s$Supabase's own sender$s$, 95)
on conflict (ref) do nothing;
