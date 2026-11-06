# Profit share: how the client calculates it today

Source: the client's paper sheet "Profit Share", August 2024 version (received Nov 2, 2026). It
answers open items R1, A1–A5, A8 and A9 on the Projet page. A6, A7 and the follow-ups A10–A13
are still open. The crew app calculates it live during the day (Nov 3, migration 1700); see
"In the app" below.

## Per route

| Value | Formula |
| --- | --- |
| R, revenue | Route revenue (sales). Whether it is before tax and after discount is open item I-16 on the Projet page |
| H, team hours | Sum of every crew member's hours worked (start to finish) |
| RPH, revenue per hour | R ÷ H |
| AJS, average job size | R ÷ number of jobs |
| Cancel rate | Cancels ÷ jobs |

## COGS

| Cost | Formula |
| --- | --- |
| Wages | H × $26 |
| Dumps | Dump costs − credits (accepted donations at Éco-Dépôt: $75 credit per 1,000 kg) |
| Franchise fees | R × 16% |
| Fuel | R × 4%; 5.5% on a split day; 7% for 2 trucks |
| Swing truck fee | $60 × the number of swing trucks the crew lead enters |
| **Total COGS** | Sum of the above |
| **COGS %** | Total COGS ÷ R |

## Who qualifies

All of these must hold for the route:

1. R ≥ $2,000 and RPH ≥ $135. If the team works less than 18 hours in total (team of 2 or
   more), the minimum revenue is $1,500 instead.
2. COGS % ≤ 50.00%.
3. Paperwork completely filled out, and no damages.
4. Company policies respected; donations never dumped in the garbage.

Training day: the trainer can remove up to 3 hours from the calculation. The route then needs
R ≥ $1,500 and RPH ≥ $125.

## How much each crew member gets

Each crew member gets a percentage of the route's revenue (R), set by their rank and the
route's COGS % band:

| Rank | COGS 47.01–50.00% | COGS 43.01–47.00% | COGS under 43.00% |
| --- | --- | --- | --- |
| Wingman | 1% | 2% | 3% |
| Professional | 2% | 3% | 4% |
| Expert & JR Coach | 3% | 4% | 5% |

Above 50% COGS, nobody gets a profit share. Tips are separate and are not part of COGS.

## In the app (Nov 3, 2026)

The crew app shows a **Profit share** card under the scoreboard, recalculated as jobs, dump
visits and hours come in, so nobody fills in the bottom of the sheet at the end of the day:
- each crew member's % and amount, or why the route doesn't qualify yet (revenue or revenue per
  hour under the minimum, COGS over 50%, damages, hours other than Regular Junk);
- revenue per hour, COGS %, team hours, average job size, and the full COGS breakdown;
- while the route is going, hours count up to now (recalculated every minute).

Where the numbers come from:
- Plan: `app_setting` `profit_share_plan` (JSON with every amount and threshold on the sheet,
  editable on Configuration → Profit share, one field per value). `training_hours_off_revenue_per_hour` is false, as on the
  sheets (A13).
- % per rank: `rank.share_pct_low_cogs` / `mid` / `high`, on the same tab. No % (Recruit, A12 default) = no share.
- Rank: `shift_crew_member.rank_id_snapshot`, now kept current from the rank history until the
  route is accepted, then frozen as before.
- Route inputs on `shift`: `fuel_mode` (one truck / split day / 2 trucks), `swing_truck`,
  `training_day` and `training_hours_removed` (up to 3), set by the crew lead on the card;
  `damages`, set by dispatch only.
- Hours per person: from the route start (or when they joined) to the finish (or when they left).
- The calculation is `apps/mobile/lib/data/profit_share.dart`; its tests reproduce the three
  routes below to the cent.

Not done yet: the same figures on the admin route review, and "paperwork complete" as a
condition (the route's acceptance checks cover it).

## Worked examples: three routes of Oct 25, 2026

From the client's filled route sheets. Crew names are left out. These are the expected results
for the profit-share engine's tests.

| | Route 1 | Route 2 | Route 3 |
| --- | --- | --- | --- |
| Trucks | 1 | 2 | 2 |
| Crew hours | 10.75 + 10.75 = 21.5 | 10.25 + 10.5 = 20.75 | 8.75 + 8.75 = 17.5 |
| Jobs | 9 | 5 | 7 (one paid cash) |
| R, revenue before tax | 3,522.00 | 4,196.00 | 2,935.40 |
| RPH | 163.81 | 202.22 | 167.74 |
| AJS | 391.33 | 839.20 | 419.34 |
| Wages | 481.00 (18.5 h: 3 h removed, training) | 539.50 | 455.00 |
| Dumps D − C | 222.00 − 3.10 = 218.90 | 346.70 − 80.00 = 266.70 | 189.00 − 12.00 = 177.00 |
| Franchise 16% | 563.52 | 671.36 | 469.66 |
| Fuel | 4% = 140.88 | 7% = 293.72 | 7% = 205.48 |
| Total COGS | 1,404.30 | 1,771.28 | 1,307.14 |
| COGS % | 39.9% (under 43%) | 42.2% (under 43%) | 44.5% (43.01–47%) |
| Profit share | Crew A 5% = 176.10; crew B none | Crew A 3% = 125.88; crew B 4% = 167.84 | Crew A 2% = 58.71; crew B 3% = 88.06 |
| Ranks implied | A: Expert or JR Coach | A: Wingman; B: Professional | A: Wingman; B: Professional |
| Tips (equal split) | 357.50 → 178.75 each | 155.80 → 77.90 each | 137.75 → 68.88 / 68.87 |

What the examples confirm:
- R is the sum of "revenue before taxes" (after discount). Every person's share uses the
  whole route's R, whatever their own hours.
- Disposal: garbage $150, wood $100 and bedload $50 per 1,000 kg are costs; metal and
  electronics is a $50 per 1,000 kg credit (the app had it as a cost; fixed in migration 1600).
- "2 trucks" means the route used two trucks during the day: fuel 7%, no swing truck fee.
- Cash tips aren't counted. Route 3's cash job only counts its own payment.

Things on the sheets that don't add up (asked on the Projet page):
- Route 1: the two donation credits are $1.20 for 120 kg and $1.40 for 190 kg, about $10 per
  1,000 kg instead of $75 (A14).
- Route 1: wages drop 3 hours for the training day, but RPH still uses all 21.5 hours, and the
  second crew member gets no share (A13).
- Route 2: one garbage ticket of 520 kg is charged $83.20, which is $160 per 1,000 kg, the
  outside-dump rate.
- Route 3: the credits total is written as 17, but the lines add up to 12 (the dumps line
  correctly uses 12). The tip per person is written 63.88; half of 137.75 is 68.88.
