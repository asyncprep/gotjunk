# Truck Team OS – Dispatcher guide

Montréal · November 3, 2026

## Your day at a glance

You create the day's routes in the morning, follow them on the Board during the day, and check and accept each route once the crew submits it. Everything happens at https://gotjunk.innodigital.ca.

1. **Morning:** paste the day's routes from your tracker (or create them by hand).
2. **During the day:** watch revenue, jobs and problems per route on **Tableau (Board)**.
3. **End of day:** paste the tracker again to add end times.
4. **Each submitted route:** count the cash, finalize cancellations, check the crew's hours and tips, tick the checklist, then accept it, or return it to the crew with a reason.

A route moves through these statuses: **Ouvert** (Open) → **En cours** (In progress, the crew started) → **Soumis** (Submitted) → **Accepté** (Accepted and locked). A route you return goes to **Retourné** (Returned) until the crew submits again; an accepted route you reopen goes to **Rouvert** (Reopened).

## Creating the day's routes

**From your tracker (recommended).** You keep your spreadsheet as it is and never share it.

1. On **Tableau (Board)**, pick the date with the arrows or the calendar.
2. Click **Coller depuis le tableau (Paste from tracker)**.
3. In your spreadsheet, select the route rows from ROUTE to END TIME, with or without the header row, and copy (Ctrl+C).
4. Paste into the box (Ctrl+V). A preview lists each route with its truck, phone, crew, positions and times, and what will happen: **Nouvelle route** (new) or **Mise à jour** (update).
5. Anything shown in red needs a fix first: pick the unknown truck, phone or person from its list, or a missing position.
6. Click **Appliquer (Apply)**.

What the paste takes from each block:

| Tracker column | In the app |
| --- | --- |
| ROUTE (C1, E1…) | The route's name, shown before the truck on the Board |
| PHONE | The truck phone the crew signs in on |
| TRUCK | The truck; a second truck under it marks the route as "2 trucks" for fuel |
| POSITION and NAME | Each crew member as Driver, Navigator or Onboarding; the driver becomes crew lead |
| START TIME | The route's start and each person's own start |
| END TIME | The finish, and an early leave for anyone who stopped before the rest |

Empty blocks at the bottom of the tracker are skipped. Routes are created for the date shown on the Board, so check it before applying.

**By hand.** Click **+ Nouvelle route (New route)**, pick the route name, the truck and the phone, tick 2 or 3 crew members, give each a position (exactly one driver), choose the crew lead, then **Créer la route (Create route)**. A truck and phone can run two routes the same day; a person can't be on two routes at once.

## Following routes on the Board

The Board lists the day's routes, one row each: route name and truck, phone, crew with positions (★ = crew lead), status, jobs, revenue before tax, and **À régler (To fix)**, the number of problems still blocking acceptance (✓ when none).

It refreshes by itself every minute and when you come back to the tab; **Actualiser (Refresh)** updates it now. Filter with the chips at the top:

- **À réviser (To review):** submitted routes waiting for you. It turns orange when there are some.
- **En cours (In progress):** open, started, returned or reopened routes.
- **Acceptés (Done):** accepted routes.

Click a row to open the route. Crew members' jobs, dumps and cash appear as the phone syncs, so you can follow a route live without calling the crew.

## Reviewing a submitted route

Open the route from **À réviser**. Work down the page; **Vérifications avant acceptation (Checks before acceptance)** at the top lists what still blocks it, and shows **Prêt à accepter (Ready to accept)** when nothing does.

1. **Hours type.** Check the route's hours type (regular junk, warehouse or non-junk) and click **Confirmer le type d'heures (Confirm hours type)**.
2. **Jobs.** Each job shows its Opportunity ID, payment method, revenue before and including tax, and tip. A job the crew cancelled waits for you: pick the cancellation reason and click **Finaliser (Finalize)**.
3. **Dump visits.** Each visit shows the site, ticket number, ticket photo and materials with weight, billable weight, rate and amount (costs and credits). The amounts come from the rates in Configuration.
4. **Cash.** The page shows the expected cash and the crew's cash photo. Count the envelope, enter the amount and click **Enregistrer le compte (Record count)**. The envelope label fills in by itself (date · crew lead · amount). A difference from the expected amount is a warning, not a blocker; add a note if you know why.
5. **Crew and tips.** Check each person's position and start/end times (**Corriger les heures** to fix them), mark someone who left early, or add a member. Tips are split equally by default; click **Répartir à la main (Split by hand)** to set each person's share, which must add up to the total.
   - **Formateur (Trainer):** tick the trainer when a Recruit is on the route. The Recruit's profit share is calculated at Wingman's % and paid to the trainer. With a Recruit and no trainer ticked, the page warns you and that share is paid to nobody.
   - **Dommages (Damage):** tick the person who caused damage. Their profit share is still calculated, then held back to pay for the repair; the rest of the crew is paid as usual. The crew sees it on the phone at the next sync.
6. **End-of-day checklist.** Tick each item (hours checked, cash matches, job info complete, tickets present, cancellations done, keys, phone and tools returned), or **Tout cocher (Check all)**.

The scoreboard at the top (revenue before tax, jobs, tips, net disposal, expected cash, revenue per hour) updates as you go.

## Accept, return, reopen or cancel

| Button | When | What happens |
| --- | --- | --- |
| **Accepter et verrouiller** (Accept & lock) | All checks pass | The route is locked: nobody can change it, and each person's rank is frozen for the profit share |
| **Retourner pour correction** (Return for correction) | The crew must fix something (missing ticket photo, wrong amount…) | The route goes back to the phone with your reason; the crew fixes it and submits again |
| **Rouvrir** (Reopen) | An accepted route needs a correction | The route can be edited again; the reason is kept in the audit log |
| **Marquer rapproché** (Mark reconciled) | The accepted route has been checked against payments | Final status |
| **Annuler la route** (Cancel route) | A route that won't run (truck broken down…) | The route is archived with your reason; the truck, phone and crew are free again |

Return, reopen and cancel each ask for a reason, and every action is recorded with who did it and when.

## End of day and common problems

**Second paste.** When the tracker has the end times, paste the same rows again on the same date. The routes already exist, so the preview says **Mise à jour** (update): it fills in the finish time, each person's start, and an early leave for anyone who stopped before the others. Nothing is created twice. Accepted routes are left alone; reopen one first if it needs new times.

| Problem | What to do |
| --- | --- |
| "Route inconnue", "Camion inconnu", "Téléphone inconnu" or "Personne inconnue" in the preview | Pick the right one from the list next to it, or ask the admin to add it with the tracker's spelling |
| "Choisissez un poste… un seul chauffeur" | Each crew member needs Driver, Navigator or Onboarding, and the route exactly one driver |
| A person is already on another route that day | Take them off the other route first (mark them as left), or check the tracker |
| The crew can't see their route on the phone | They must sign in with their own login, and be on that route's crew |
| "Photo pas encore reçue du téléphone" | The phone hasn't uploaded the photo yet; ask the crew to open the app with signal |
| Écart de comptant (cash variance) | Count again; if it stands, write why in the note and accept |
| You accepted too early | **Rouvrir** with a reason, fix, and accept again |
