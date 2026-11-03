-- The routes on dispatch's daily tracker (client, Nov 3): a list in Configuration, offered when
-- dispatch creates a route and checked when the tracker is pasted. shift.route_code keeps the name.

create table public.route_name (
  route_name_id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(trim(name)) > 0),
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table public.route_name is 'Route names on dispatch''s daily tracker (C1, RN W1…)';

alter table public.route_name enable row level security;
grant select, insert, update, delete on public.route_name to authenticated;
create policy read_all on public.route_name for select to authenticated using (true);
create policy config_write on public.route_name for all to authenticated
  using (public.can_edit_config()) with check (public.can_edit_config());

create trigger route_name_row_audit before insert or update on public.route_name
  for each row execute function public.set_row_audit_columns();
create trigger route_name_z_audit after insert or update or delete on public.route_name
  for each row execute function public.write_audit_log('route_name_id');

insert into public.route_name (name, sort_order) values
  ('C1', 10),
  ('C2', 20),
  ('C3', 30),
  ('C4', 40),
  ('C5', 50),
  ('C6', 60),
  ('C7', 70),
  ('C8', 80),
  ('E1', 90),
  ('E2', 100),
  ('E3', 110),
  ('E4', 120),
  ('E5', 130),
  ('E6', 140),
  ('FLAN1', 150),
  ('FLAN2', 160),
  ('LAN1', 170),
  ('LAN2', 180),
  ('RN E1', 190),
  ('RN E2', 200),
  ('RN E3', 210),
  ('RN E4', 220),
  ('RN W1', 230),
  ('RN W2', 240),
  ('RN W3', 250),
  ('RN W4', 260),
  ('W1', 270),
  ('W2', 280),
  ('W3', 290),
  ('W4', 300),
  ('W5', 310),
  ('W6', 320),
  ('W7', 330),
  ('W8', 340),
  ('LAUR1', 350),
  ('LAUR2', 360),
  ('LAUR3', 370),
  ('LAUR4', 380),
  ('FLAUR1', 390),
  ('FLAUR2', 400),
  ('TR1', 410),
  ('TR2', 420)
on conflict (name) do nothing;
