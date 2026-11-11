# Truck Team OS – Admin guide

Montréal · November 3, 2026

## What the system is

Truck Team OS replaces the paper route sheet. Crews fill in their route on the truck's iPhone, dispatch checks and accepts it in the web admin, and the admin keeps the lists and rates everything is calculated from.

| Part | Who uses it | Where |
| --- | --- | --- |
| Crew app | Truck team members (crew lead on the truck's phone) | iPhone app "GOT-Crew" (TestFlight during the pilot, then installed on the truck phones by Mosyle) |
| Web admin | Dispatchers, administration, senior ops | https://gotjunk.innodigital.ca |
| Database | Everyone, through the two apps | Supabase, Canada (Montréal region) |

As admin you set up who can sign in, the trucks, phones, dump sites and rates, payment methods, ranks and the profit-share values. Dispatchers use what you configure every day, so a wrong rate or a missing truck shows up on their screens first.

The admin opens in French; switch to English with the FR / EN selector at the top right. This guide gives each screen's French name, then the English one in parentheses.

## Signing in, roles and invitations

Every login has one role. The role decides what the person sees and changes; the database enforces it, whatever the screen shows.

| Role (French name) | Signs in to | Can do |
| --- | --- | --- |
| Membre d'équipe (Truck team member) | Crew app only | Enter their own route until it is submitted |
| Répartiteur (Dispatcher) | Web admin | Create routes, review, return, accept and reopen them, count cash; read configuration |
| Administration | Web admin | Everything a dispatcher does, plus invite users and manage the team; edit configuration only with configuration rights |
| Direction (Senior ops) | Web admin | Everything, including configuration and granting senior ops or configuration rights |

**Invite someone**

1. Go to **Équipe (Team)** → **Utilisateurs (Users)** → **Inviter un utilisateur (Invite a user)**.
2. Enter their email and pick the role.
3. For a crew member, pick their **Employé (Employee)**: a crew login must be linked to an employee, so their routes and profit share are theirs.
4. Tick **Droits de configuration (Configuration rights)** only for people who should change rates and lists. Only senior ops can grant it.
5. Click **Envoyer l'invitation (Send invitation)**. They receive an email, choose a password of at least 8 characters, and are in.

The invitation email currently comes from Supabase's own address (open question S12). A crew login that tries the web admin sees a message that it is for dispatch and administration only.

Forgot password: the person clicks **Mot de passe oublié?** on the sign-in page and gets a reset link by email.

## Configuration

The **Configuration** page holds every list and rate the apps calculate from. Without configuration rights it is read only. Changes reach the crew phones at their next sync, usually within seconds when they have signal.

| Tab (French) | English | What it holds | When to change it |
| --- | --- | --- | --- |
| Tarifs de dépotoir | Disposal rates | $ per tonne for each site and material, as a cost, a credit or free; minimum weight and when it applies; start and end dates | A dump changes its price |
| Partage des profits | Profit share | Wage per team hour, franchise fees, fuel % (one truck, split day, 2 trucks), swing truck fee, minimums, training-day rule, COGS bands, % per rank | The profit-share sheet changes |
| Raisons d'annulation | Cancellation reasons | Reasons dispatch picks when a job is cancelled | A new reason is needed |
| Liste de fin de journée | End-of-day checklist | What dispatch ticks before accepting a route; "required" items block acceptance | The closing routine changes |
| Rangs | Ranks | Wingman, Professional, Expert, JR Coach… | A rank is added or renamed |
| Routes | Routes | The route names on the daily tracker (C1, E1, RN W1, LAUR2…) | A route is added or renamed |
| Camions | Trucks | Each truck's name (Pink, Bleu, Titan…) | A truck is added or retired |
| Téléphones | Phones | Each truck phone's label (4026, 4027…) | A phone is added or replaced |
| Sites | Sites | Dumps and depots, their type, whether they issue tickets and need a ticket photo, address | A new dump is used |
| Matières | Materials | Garbage, wood, bedload, metal and electronics, donations… | Rarely |
| Modes de paiement | Payment methods | Credit card, debit, cash, invoice, e-transfer…, and which ones are cash | A payment method is added |
| Paramètres | Settings | Other values, for example whether cash includes tips | Rarely |

**Changing a rate.** Rates are dated, so past routes keep the price that applied on their day. To change one: click **Terminer (End)** on the current rate and give its last day, then add the **Nouveau tarif (New rate)** starting the next day. Old rates stay under **Tarifs antérieurs (Past rates)**.

**Turning something off.** Untick **Actif (Active)** instead of deleting. It disappears from new routes but stays on past ones.

**Names must match the tracker.** Dispatch pastes routes from the daily tracker, and trucks, phones and people are matched by name. Enter routes, trucks and phones exactly as they appear in the tracker (RN W1, Pink, 4029).

## Team: employees and ranks

The **Équipe (Team)** page has two lists: **Employés (Employees)**, the people who work on the trucks, and **Utilisateurs (Users)**, the logins. An employee can exist without a login; every crew login points to one employee.

**Add an employee.** Click **Nouvel employé (New employee)** and enter the full name as it is written in the daily tracker, plus the Ceridian ID and language if you have them. The tracker paste finds people by this name, so "Marie-Ève Gagnon-Roy" in the tracker should be the same here.

**Link a login to an employee.** In **Utilisateurs (Users)**, choose the person in the login's **Employé (Employee)** list; it saves right away. The list only offers employees without a login, because an employee has one login at most. A crew login always keeps an employee; a dispatcher or admin login can have none. You can't change your own login.

**Change a rank.** Use **Changer le rang (Change rank)** with the date it takes effect (**Depuis / Since**). Ranks keep their history. A route uses the rank in force on its date, and that rank is frozen when dispatch accepts the route, so a later promotion never changes a past profit share.

**Someone leaves.** Click **Désactiver (Deactivate)** on the employee, and deactivate their login in Users. They disappear from new routes but stay on past ones. Nothing is deleted.

## Payments, audit log and export

**Paiements (Payments)** shows one day's Stripe card payments, read only. Only administration and senior ops see it. Pick a date to see:

- totals per HQ login (the crew member who took the payments): number of payments, revenue before tax, tips, amount;
- each payment: time, Opportunity ID, amount, tip, revenue before tax, succeeded or failed, card reader or typed in, HQ login;
- the matching job in the app with a link to its route, flagged when the app's total plus tip differs from Stripe.

Revenue before tax is worked out as (amount − tip) ÷ 1.14975. The page updates by itself every minute while it is open. Failed attempts and payments refunded in full are shown greyed and don't count; a partial refund counts for what was kept. When a job is paid in two parts, the parts are added up before comparing with the app. Cash jobs never appear here. The page reads Stripe with a read-only key stored on the server; customer names, emails and card numbers are not shown.

**Journal (Audit log)** lists every change made to routes, jobs, disposal, cash, crew, rates, employees and logins: when, what, who (by role), the reason and the fields changed. Filter by record type. Nothing can be edited or removed there.

**Exporter les routes (Export routes)**, on the same page, downloads a CSV of every route between two dates with its hours, jobs, revenue, tips, expected cash, net disposal and revenue per hour, for a spreadsheet or the accountant.

## Tickets

**Signaler (Report)**, at the bottom right of every page, files a ticket from where you are. Pick **Quelque chose ne marche pas (Something is broken)**, **Proposer un changement (Suggest a change)** or **Question pour le client (Question for the client)**, give a short title and say what happened or what should change. The page and the part of the app are filled in for you. You can add screenshots: paste one (Ctrl+V), drop a file, or use **Prendre une capture (Take a screenshot)**. Browser details and recent errors are attached unless you untick them, and you can see exactly what is sent.

The **Tickets** page lists them, with the number of open tickets next to it in the menu. Filter by status, type, priority or part of the app, or search. On a ticket, anyone in the admin app changes the status, priority, type or part, and adds comments with files; every change is kept in its activity. **Copier pour un développeur (Copy for a developer)** copies the whole ticket as text.

The old **Projet** page's client questions and spec inconsistencies are now tickets of type Question, with their reference in the title (for example "F8 · …") and the client's answer as the first comment. Answered items are closed.

Tickets are never deleted: close them as **Terminé (Done)** or **Ne sera pas fait (Won't do)**. Central (central.innodigital.ca) reads them once the feed is connected.

## Rules the system enforces, and fixes

These rules hold for everyone, in both apps:

- A route has exactly one driver; every crew member is the driver, a navigator or onboarding.
- A person can't be on two active routes the same day.
- The crew edits a route only until they submit it. After that only dispatch changes it, and an accepted route must be reopened, with a reason, before anyone edits it.
- Returning, reopening or cancelling a route always needs a reason, and every change is in the audit log.
- Nothing is deleted: things are deactivated, cancelled or ended.

| Problem | Fix |
| --- | --- |
| A truck, phone or person is "unknown" when dispatch pastes the tracker | Add it in Configuration or Team with the tracker's exact name, or pick it from the list in the paste preview |
| "Lecture seule" on Configuration | The login has no configuration rights; senior ops grants them |
| A crew member doesn't see their route | Their login must be linked to the right employee, and they must be on that day's route |
| An invitation didn't arrive | Check spam; invite again from Users |
| Profit share looks wrong | Check the values in Configuration → Partage des profits and the person's rank on the route's date |
