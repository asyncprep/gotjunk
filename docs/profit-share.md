# Profit share: how the client calculates it today

Source: the client's paper sheet "Profit Share", August 2024 version (received Nov 2, 2026). It
answers open items R1, A1–A5, A8 and A9 on the Projet page. A6, A7 and the follow-ups A10–A13
are still open. Nothing here is built yet; the profit-share engine is V1b.

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
| Swing truck fee | $60 per truck |
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

## Compared with the app today

- The app already records most inputs: crew hours (start and finish, who joined or left),
  revenue per job, cancellations, and disposal costs and credits from tickets.
- Each person's rank is kept with its history, and the app freezes the rank in force on the
  route's date.
- Paperwork is covered by the route's acceptance checks.
- Not recorded yet: split day / 2 trucks (fuel %), swing truck, training day (3 hours), and
  damages. These wait for answers A11 and A13.
- The dev seed ranks (Recruit, Wingman, Sales Professional, Trainer) don't match the sheet
  (Wingman, Professional, Expert, JR Coach; Trainer is a role, not a rank). Production ranks are
  entered on the Configuration page; see A12.
