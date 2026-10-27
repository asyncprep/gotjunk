-- Truck Team OS: development seed data
-- Reference values come from the product spec v0.3. Items marked TO CONFIRM depend on open items
-- and must be checked before production (production values are entered through the admin app).

insert into public.rank (code, name_fr, name_en, sort_order) values
  ('recruit',   'Recrue',                'Recruit',            10),
  ('wingman',   'Coéquipier',            'Wingman',            20),
  ('sales_pro', 'Professionnel de vente', 'Sales Professional', 30),
  ('trainer',   'Formateur',             'Trainer',            40);  -- TO CONFIRM: rank or role (open item A)

insert into public.site (code, name, site_type, issues_tickets, requires_ticket_photo) values
  ('eco_junk',     'Eco-Junk',             'eco_junk',     true, true),
  ('outside_dump', 'Outside dump (other)', 'outside_dump', true, true);

insert into public.material_type (code, name_fr, name_en) values
  ('donation',          'Dons acceptés (Éco-Dépôt)', 'Accepted donations (Eco-Dépôt)'),
  ('metal_electronics', 'Métal et électronique',     'Metal and electronics'),
  ('mattress_clean',    'Matelas propres',           'Clean mattresses'),
  ('garbage',           'Déchets',                   'Garbage'),
  ('wood',              'Bois',                      'Wood'),
  ('bedload',           'Benne (bedload)',           'Bedload'),
  ('mixed',             'Mixte',                     'Mixed load');

-- Eco-Junk minimums are unknown (open item R3), so 0 until confirmed. Credits never use a minimum.
insert into public.site_rate_config (site_id, material_type_id, rate_per_ton, direction, min_billable_kg, min_applies_to, effective_from)
select s.site_id, m.material_type_id, v.rate, v.direction::public.disposal_direction, v.min_kg,
       v.min_applies::public.min_applies_to, date '2026-01-01'
from (values
  ('eco_junk',     'donation',           75, 'credit',      0, 'never'),
  ('eco_junk',     'metal_electronics',  50, 'cost',        0, 'transaction'),
  ('eco_junk',     'mattress_clean',      0, 'no_charge',   0, 'never'),
  ('eco_junk',     'garbage',           150, 'cost',        0, 'transaction'),
  ('eco_junk',     'wood',              100, 'cost',        0, 'transaction'),
  ('eco_junk',     'bedload',            50, 'cost',        0, 'transaction'),
  ('outside_dump', 'mixed',             160, 'cost',      500, 'transaction')
) as v(site, material, rate, direction, min_kg, min_applies)
join public.site s on s.code = v.site
join public.material_type m on m.code = v.material;

insert into public.payment_method (code, name_fr, name_en, is_cash, stripe_method_type) values
  ('cash', 'Comptant', 'Cash',          true,  null),
  ('card', 'Carte',    'Card (Stripe)', false, 'card');   -- TO CONFIRM: full list (open item F)

-- TO CONFIRM: placeholder reasons; dispatch owns the real list.
insert into public.cancellation_reason (code, name_fr, name_en, sort_order) values
  ('price_declined',  'Prix refusé',              'Customer declined price', 10),
  ('customer_absent', 'Client absent',            'Customer not present',    20),
  ('scope_mismatch',  'Articles non conformes',   'Items not as described',  30),
  ('other',           'Autre',                    'Other',                   90);

-- From spec WF-006; full checklist is open item D.
insert into public.checklist_item (code, label_fr, label_en, sort_order) values
  ('hours_correct',          'Heures vérifiées',                 'Hours look correct',               10),
  ('cash_matches',           'Comptant conforme',                'Cash matches expected',            20),
  ('job_info_complete',      'Informations des travaux complètes', 'Job information complete',      30),
  ('disposal_photos',        'Billets de dépotoir présents',     'Disposal tickets and photos present', 40),
  ('cancellations_handled',  'Annulations traitées',             'Cancellations handled or queued',  50),
  ('keys_returned',          'Clés du camion rendues',           'Truck keys returned',              60),
  ('phone_returned',         'Téléphone rendu',                  'Assigned phone returned',          70),
  ('tools_returned',         'Outils et équipement rendus',      'Tools and equipment returned',     80);

-- Demo fleet
insert into public.truck (unit_number) values ('T-01'), ('T-02'), ('T-03');
insert into public.phone (label) values ('P-01'), ('P-02'), ('P-03');
