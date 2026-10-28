import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

const fr = {
  app: { title: 'Truck Team OS', subtitle: 'Répartition et administration', region: 'Montréal', product: 'Répartition' },
  ui: {
    saved: 'Enregistré', dragHint: 'Glissez les lignes pour changer l’ordre', reordered: 'Ordre enregistré',
    dragHandle: 'Déplacer', updatedAt: 'Mis à jour à {{time}}', refresh: 'Actualiser', unsaved: 'Modifications non enregistrées',
    codeAuto: 'Généré automatiquement si vide',
  },
  nav: { board: 'Tableau', config: 'Configuration', team: 'Équipe', audit: 'Journal', project: 'Projet', signOut: 'Se déconnecter' },
  common: {
    save: 'Enregistrer', cancel: 'Annuler', add: 'Ajouter', loading: 'Chargement…', none: 'Aucun',
    active: 'Actif', inactive: 'Inactif', yes: 'Oui', no: 'Non', name: 'Nom', code: 'Code', back: 'Retour',
    confirm: 'Confirmer', edit: 'Modifier', close: 'Fermer', date: 'Date', all: 'Tous', export: 'Exporter (CSV)',
    nameFr: 'Nom (FR)', nameEn: 'Nom (EN)', order: 'Ordre', required: 'Obligatoire',
  },
  login: {
    title: 'Connexion', email: 'Courriel', password: 'Mot de passe', submit: 'Se connecter',
    forgot: 'Mot de passe oublié?', resetSent: 'Si ce courriel existe, un lien de réinitialisation a été envoyé.',
    setTitle: 'Choisir un mot de passe', setSubmit: 'Enregistrer le mot de passe', minLength: '12 caractères minimum',
    noAccess: 'Cette application est réservée à la répartition et à l’administration.',
    quickTitle: 'Connexion rapide', quickHint: 'Développement local seulement : absent du site en ligne.',
  },
  status: {
    open: 'Ouvert', in_progress: 'En cours', submitted: 'Soumis', returned: 'Retourné', locked: 'Accepté',
    reopened: 'Rouvert', reconciled: 'Rapproché', archived: 'Archivé',
  },
  hours: { regular_junk: 'Heures junk régulières', warehouse: 'Heures entrepôt', non_junk: 'Heures non-junk' },
  board: {
    title: 'Quarts du jour', newShift: 'Nouveau quart', truck: 'Camion', phone: 'Téléphone', crew: 'Équipe',
    status: 'Statut', revenue: 'Revenus', jobs: 'Travaux', issues: 'À régler', create: 'Créer le quart',
    pickCrew: 'Choisir 2 ou 3 membres', empty: 'Aucun quart pour cette date.', open: 'Ouvrir',
    toReview: 'À réviser', today: 'Aujourd’hui', inProgress: 'En cours', done: 'Acceptés', created: 'Quart créé',
    noMatch: 'Aucun quart dans ce filtre.',
  },
  shift: {
    confirmHours: 'Confirmer le type d’heures', return: 'Retourner pour correction', lock: 'Accepter et verrouiller',
    reopen: 'Rouvrir', reconcile: 'Marquer rapproché', reasonPrompt: 'Raison (obligatoire)',
    start: 'Début', finish: 'Fin', hoursType: 'Type d’heures', confirmed: 'confirmé',
    scoreboard: 'Tableau de bord', revenuePreTax: 'Revenus avant taxes', jobsCompleted: 'Travaux complétés',
    tips: 'Pourboires', netDisposal: 'Dépotoir net', expectedCash: 'Comptant attendu', rph: 'Revenus / heure',
    checks: 'Vérifications avant acceptation', ready: 'Prêt à accepter',
    jobs: 'Travaux', opportunity: 'Opportunité', outcome: 'Résultat', method: 'Paiement', preTax: 'Avant taxes',
    inclTax: 'Taxes incluses', tip: 'Pourboire', finalize: 'Finaliser', reason: 'Raison',
    disposal: 'Dépotoir', site: 'Site', ticket: 'Billet', photos: 'Photos', material: 'Matière', weight: 'Poids (kg)',
    billable: 'Facturable (kg)', rate: '$/t', amount: 'Montant',
    cash: 'Comptant', counted: 'Compté', envelope: 'Enveloppe', resolution: 'Explication de l’écart',
    recordCount: 'Enregistrer le compte', variance: 'Écart', noCash: 'Aucun comptant déclaré.',
    checklist: 'Liste de fin de journée', checkAll: 'Tout cocher',
    crew: 'Équipe et pourboires', rankToday: 'Rang', rankFrozen: 'Rang figé', tipShare: 'Part des pourboires',
    addMember: 'Ajouter un membre', markLeft: 'A quitté', left: 'Parti à',
    returnedFor: 'Retourné', reopenedFor: 'Rouvert',
    returnTitle: 'Retourner le quart à l’équipe', returnHelp: 'L’équipe verra cette raison sur son téléphone.',
    reopenTitle: 'Rouvrir un quart accepté', reopenHelp: 'La raison est conservée dans le journal d’audit.',
    locked: 'Quart accepté et verrouillé', returned: 'Quart retourné à l’équipe', reopened: 'Quart rouvert',
    finalized: 'Annulation finalisée', countSaved: 'Comptant enregistré', invalidAmount: 'Montant invalide (ex. 227,30)',
    photoNotUploaded: 'Pas encore reçue du camion', photoTaken: 'prise le', openFull: 'Ouvrir en grand',
    ticketPhoto: 'Photo du billet', cashPhoto: 'Photo du comptant', ticketPhotoMissing: 'Photo du billet manquante',
    cashNotSubmitted: 'L’équipe n’a pas encore déclaré le comptant ni pris la photo.',
    receivedBy: 'Reçu par', verifiedAt: 'Compté le', toCount: 'À compter', balanced: 'Équilibré',
    over: 'Excédent', short: 'Manque',
  },
  outcome: { completed: 'Complété', cancelled_pending: 'Annulé (à confirmer)', cancelled_confirmed: 'Annulé', draft: 'Brouillon' },
  problem: {
    crew_size: 'Taille d’équipe invalide', hours_type_missing: 'Type d’heures manquant',
    start_time_missing: 'Heure de début manquante', finish_time_missing: 'Heure de fin manquante',
    job_incomplete: 'Travail incomplet', tax_check: 'Taxes à vérifier', opportunity_repeated: 'Opportunité répétée',
    ticket_number_missing: 'Numéro de billet manquant', ticket_photo_missing: 'Photo du billet manquante',
    visit_no_materials: 'Visite sans matière', cash_photo_missing: 'Photo du comptant manquante',
    hours_type_unconfirmed: 'Type d’heures non confirmé', checklist_incomplete: 'Liste de fin de journée incomplète',
    cash_not_counted: 'Comptant non compté', cash_variance_unresolved: 'Écart de comptant non expliqué',
    cancellation_pending: 'Annulation à finaliser',
  },
  err: {
    shift_not_ready: 'Le quart n’est pas prêt', reason_required: 'Une raison est obligatoire',
    shift_locked: 'Quart verrouillé : rouvrez-le d’abord', invalid_transition: 'Changement de statut non permis',
    not_allowed: 'Action non permise', crew_double_booked: 'Employé déjà assigné ce jour-là',
    rate_overlap: 'Un autre tarif actif couvre ces dates', rank_overlap: 'Ce rang chevauche un autre',
  },
  config: {
    title: 'Configuration', rates: 'Tarifs de dépotoir', trucks: 'Camions', phones: 'Téléphones', sites: 'Sites',
    materials: 'Matières', payments: 'Modes de paiement', reasons: 'Raisons d’annulation', checklist: 'Liste de fin de journée',
    settings: 'Paramètres', ratePerTon: '$/tonne', direction: 'Type', minKg: 'Minimum (kg)', minApplies: 'Minimum appliqué',
    from: 'Du', to: 'Au', endRate: 'Terminer', newRate: 'Nouveau tarif', cost: 'Coût', credit: 'Crédit', no_charge: 'Gratuit',
    transaction: 'Par pesée', never: 'Jamais', readOnly: 'Lecture seule : droits de configuration requis.',
    unit: 'Numéro', label: 'Libellé', siteType: 'Type de site', issuesTickets: 'Émet des billets',
    needsPhoto: 'Photo obligatoire', isCash: 'Comptant', value: 'Valeur', description: 'Description',
    endRateTitle: 'Terminer ce tarif', endRateHelp: 'Dernier jour où ce tarif s’applique. Ajoutez ensuite le nouveau tarif.',
    rateAdded: 'Tarif ajouté', rateEnded: 'Tarif terminé', pastRates: 'Tarifs antérieurs', ranks: 'Rangs',
  },
  team: {
    title: 'Équipe', employees: 'Employés', users: 'Utilisateurs', newEmployee: 'Nouvel employé',
    ceridian: 'ID Ceridian', language: 'Langue', rank: 'Rang actuel', setRank: 'Changer le rang', since: 'Depuis',
    invite: 'Inviter un utilisateur', email: 'Courriel', role: 'Rôle', employee: 'Employé', sendInvite: 'Envoyer l’invitation',
    inviteSent: 'Invitation envoyée.', configRights: 'Droits de configuration', deactivate: 'Désactiver', activate: 'Activer',
  },
  role: { ttm: 'Membre d’équipe', dispatcher: 'Répartiteur', admin: 'Administration', senior_ops: 'Direction' },
  project: {
    title: 'Projet', print: 'Imprimer', search: 'Rechercher…', empty: 'Rien dans ce filtre.',
    tab_question: 'Questions pour le client', tab_inconsistency: 'Incohérences du cahier des charges',
    introQuestions: 'Questions à régler avec le client pour finaliser le produit. « En attendant » indique ce que l’application fait d’ici la réponse.',
    introIssues: 'Contradictions et oublis relevés dans le cahier des charges (fichier v0.1, contenu v0.3), avec leur impact et la façon dont le développement les traite.',
    questionsAnswered: 'Questions répondues', issuesResolved: 'Incohérences résolues', openBlockers: 'Points bloquants ouverts', waitingClient: 'En attente du client',
    priority: 'Priorité', statusLabel: 'Statut',
    prio_blocker: 'Bloquant', prio_pilot: 'Avant le pilote', prio_v1b: 'Avant V1b', prio_info: 'Information',
    status_todo: 'À traiter', status_all: 'Tous', status_open: 'Ouvert', status_asked: 'Posé au client',
    status_answered: 'Répondu', status_resolved: 'Résolu', status_deferred: 'Reporté',
    specRefs: 'Sections', blocks: 'Bloque', impact: 'Impact', meanwhile: 'En attendant', handling: 'Traitement',
    answer: 'Réponse du client', resolution: 'Résolution', addAnswer: 'Ajouter la réponse du client', addResolution: 'Ajouter la résolution',
    answerPlaceholder: 'Réponse du client…', resolutionPlaceholder: 'Comment c’est réglé…',
  },
  audit: { title: 'Journal d’audit', when: 'Quand', record: 'Enregistrement', action: 'Action', by: 'Par', reason: 'Raison', changes: 'Changements', exportTitle: 'Exporter les quarts', fromDate: 'Du', toDate: 'Au' },
};

type Dict = typeof fr;

const en: Dict = {
  app: { title: 'Truck Team OS', subtitle: 'Dispatch and administration', region: 'Montréal', product: 'Dispatch' },
  ui: {
    saved: 'Saved', dragHint: 'Drag rows to change the order', reordered: 'Order saved',
    dragHandle: 'Move', updatedAt: 'Updated at {{time}}', refresh: 'Refresh', unsaved: 'Unsaved changes',
    codeAuto: 'Generated automatically if empty',
  },
  nav: { board: 'Board', config: 'Configuration', team: 'Team', audit: 'Audit log', project: 'Project', signOut: 'Sign out' },
  common: {
    save: 'Save', cancel: 'Cancel', add: 'Add', loading: 'Loading…', none: 'None',
    active: 'Active', inactive: 'Inactive', yes: 'Yes', no: 'No', name: 'Name', code: 'Code', back: 'Back',
    confirm: 'Confirm', edit: 'Edit', close: 'Close', date: 'Date', all: 'All', export: 'Export (CSV)',
    nameFr: 'Name (FR)', nameEn: 'Name (EN)', order: 'Order', required: 'Required',
  },
  login: {
    title: 'Sign in', email: 'Email', password: 'Password', submit: 'Sign in',
    forgot: 'Forgot password?', resetSent: 'If this email exists, a reset link has been sent.',
    setTitle: 'Choose a password', setSubmit: 'Save password', minLength: 'At least 12 characters',
    noAccess: 'This app is for dispatch and administration only.',
    quickTitle: 'Quick sign-in', quickHint: 'Local development only: not on the live site.',
  },
  status: {
    open: 'Open', in_progress: 'In progress', submitted: 'Submitted', returned: 'Returned', locked: 'Accepted',
    reopened: 'Reopened', reconciled: 'Reconciled', archived: 'Archived',
  },
  hours: { regular_junk: 'Regular junk hours', warehouse: 'Warehouse hours', non_junk: 'Non-junk hours' },
  board: {
    title: 'Shifts', newShift: 'New shift', truck: 'Truck', phone: 'Phone', crew: 'Crew',
    status: 'Status', revenue: 'Revenue', jobs: 'Jobs', issues: 'To fix', create: 'Create shift',
    pickCrew: 'Pick 2 or 3 members', empty: 'No shifts for this date.', open: 'Open',
    toReview: 'To review', today: 'Today', inProgress: 'In progress', done: 'Accepted', created: 'Shift created',
    noMatch: 'No shifts match this filter.',
  },
  shift: {
    confirmHours: 'Confirm hours type', return: 'Return for correction', lock: 'Accept & lock',
    reopen: 'Reopen', reconcile: 'Mark reconciled', reasonPrompt: 'Reason (required)',
    start: 'Start', finish: 'Finish', hoursType: 'Hours type', confirmed: 'confirmed',
    scoreboard: 'Scoreboard', revenuePreTax: 'Revenue before tax', jobsCompleted: 'Jobs completed',
    tips: 'Tips', netDisposal: 'Net disposal', expectedCash: 'Expected cash', rph: 'Revenue / hour',
    checks: 'Checks before acceptance', ready: 'Ready to accept',
    jobs: 'Jobs', opportunity: 'Opportunity', outcome: 'Outcome', method: 'Payment', preTax: 'Pre-tax',
    inclTax: 'Incl. tax', tip: 'Tip', finalize: 'Finalize', reason: 'Reason',
    disposal: 'Disposal', site: 'Site', ticket: 'Ticket', photos: 'Photos', material: 'Material', weight: 'Weight (kg)',
    billable: 'Billable (kg)', rate: '$/t', amount: 'Amount',
    cash: 'Cash', counted: 'Counted', envelope: 'Envelope', resolution: 'Variance explanation',
    recordCount: 'Record count', variance: 'Variance', noCash: 'No cash reported.',
    checklist: 'End-of-day checklist', checkAll: 'Check all',
    crew: 'Crew and tips', rankToday: 'Rank', rankFrozen: 'Rank frozen', tipShare: 'Tip share',
    addMember: 'Add member', markLeft: 'Left', left: 'Left at',
    returnedFor: 'Returned', reopenedFor: 'Reopened',
    returnTitle: 'Return the shift to the crew', returnHelp: 'The crew will see this reason on their phone.',
    reopenTitle: 'Reopen an accepted shift', reopenHelp: 'The reason is kept in the audit log.',
    locked: 'Shift accepted and locked', returned: 'Shift returned to the crew', reopened: 'Shift reopened',
    finalized: 'Cancellation finalized', countSaved: 'Cash count saved', invalidAmount: 'Invalid amount (e.g. 227.30)',
    photoNotUploaded: 'Not received from the truck yet', photoTaken: 'taken', openFull: 'Open full size',
    ticketPhoto: 'Ticket photo', cashPhoto: 'Cash photo', ticketPhotoMissing: 'Ticket photo missing',
    cashNotSubmitted: 'The crew hasn’t declared the cash or taken the photo yet.',
    receivedBy: 'Received by', verifiedAt: 'Counted', toCount: 'To count', balanced: 'Balanced',
    over: 'Over', short: 'Short',
  },
  outcome: { completed: 'Completed', cancelled_pending: 'Cancelled (to confirm)', cancelled_confirmed: 'Cancelled', draft: 'Draft' },
  problem: {
    crew_size: 'Invalid crew size', hours_type_missing: 'Hours type missing',
    start_time_missing: 'Start time missing', finish_time_missing: 'Finish time missing',
    job_incomplete: 'Incomplete job', tax_check: 'Check tax', opportunity_repeated: 'Repeated opportunity',
    ticket_number_missing: 'Ticket number missing', ticket_photo_missing: 'Ticket photo missing',
    visit_no_materials: 'Visit with no material', cash_photo_missing: 'Cash photo missing',
    hours_type_unconfirmed: 'Hours type not confirmed', checklist_incomplete: 'End-of-day checklist incomplete',
    cash_not_counted: 'Cash not counted', cash_variance_unresolved: 'Cash variance not explained',
    cancellation_pending: 'Cancellation to finalize',
  },
  err: {
    shift_not_ready: 'Shift is not ready', reason_required: 'A reason is required',
    shift_locked: 'Shift is locked: reopen it first', invalid_transition: 'Status change not allowed',
    not_allowed: 'Not allowed', crew_double_booked: 'Employee already assigned that day',
    rate_overlap: 'Another active rate covers these dates', rank_overlap: 'This rank overlaps another',
  },
  config: {
    title: 'Configuration', rates: 'Disposal rates', trucks: 'Trucks', phones: 'Phones', sites: 'Sites',
    materials: 'Materials', payments: 'Payment methods', reasons: 'Cancellation reasons', checklist: 'End-of-day checklist',
    settings: 'Settings', ratePerTon: '$/tonne', direction: 'Type', minKg: 'Minimum (kg)', minApplies: 'Minimum applies',
    from: 'From', to: 'To', endRate: 'End', newRate: 'New rate', cost: 'Cost', credit: 'Credit', no_charge: 'Free',
    transaction: 'Per weigh-in', never: 'Never', readOnly: 'Read only: configuration rights required.',
    unit: 'Unit', label: 'Label', siteType: 'Site type', issuesTickets: 'Issues tickets',
    needsPhoto: 'Photo required', isCash: 'Cash', value: 'Value', description: 'Description',
    endRateTitle: 'End this rate', endRateHelp: 'Last day this rate applies. Then add the new rate.',
    rateAdded: 'Rate added', rateEnded: 'Rate ended', pastRates: 'Past rates', ranks: 'Ranks',
  },
  team: {
    title: 'Team', employees: 'Employees', users: 'Users', newEmployee: 'New employee',
    ceridian: 'Ceridian ID', language: 'Language', rank: 'Current rank', setRank: 'Change rank', since: 'Since',
    invite: 'Invite a user', email: 'Email', role: 'Role', employee: 'Employee', sendInvite: 'Send invitation',
    inviteSent: 'Invitation sent.', configRights: 'Configuration rights', deactivate: 'Deactivate', activate: 'Activate',
  },
  role: { ttm: 'Truck team member', dispatcher: 'Dispatcher', admin: 'Administration', senior_ops: 'Senior ops' },
  project: {
    title: 'Project', print: 'Print', search: 'Search…', empty: 'Nothing matches this filter.',
    tab_question: 'Client questions', tab_inconsistency: 'Spec inconsistencies',
    introQuestions: 'Questions to settle with the client to finalize the product. "Meanwhile" shows what the app does until there is an answer.',
    introIssues: 'Contradictions and gaps found in the product spec (file v0.1, content v0.3), with their impact and how development handles them.',
    questionsAnswered: 'Questions answered', issuesResolved: 'Inconsistencies resolved', openBlockers: 'Open blockers', waitingClient: 'Waiting on the client',
    priority: 'Priority', statusLabel: 'Status',
    prio_blocker: 'Blocker', prio_pilot: 'Before pilot', prio_v1b: 'Before V1b', prio_info: 'Info',
    status_todo: 'To do', status_all: 'All', status_open: 'Open', status_asked: 'Asked',
    status_answered: 'Answered', status_resolved: 'Resolved', status_deferred: 'Deferred',
    specRefs: 'Sections', blocks: 'Blocks', impact: 'Impact', meanwhile: 'Meanwhile', handling: 'Handling',
    answer: 'Client answer', resolution: 'Resolution', addAnswer: 'Add the client answer', addResolution: 'Add the resolution',
    answerPlaceholder: 'Client answer…', resolutionPlaceholder: 'How it was settled…',
  },
  audit: { title: 'Audit log', when: 'When', record: 'Record', action: 'Action', by: 'By', reason: 'Reason', changes: 'Changes', exportTitle: 'Export shifts', fromDate: 'From', toDate: 'To' },
};

function storedLanguage(): string {
  try {
    return localStorage.getItem('tto.lang') || 'fr';
  } catch {
    return 'fr';
  }
}

export function setLanguage(lang: 'fr' | 'en') {
  i18n.changeLanguage(lang);
  document.documentElement.lang = lang;
  try {
    localStorage.setItem('tto.lang', lang);
  } catch {
    // storage unavailable: language just won't persist
  }
}

i18n.use(initReactI18next).init({
  resources: { fr: { translation: fr }, en: { translation: en } },
  lng: storedLanguage(),
  fallbackLng: 'fr',
  interpolation: { escapeValue: false },
});

// Database errors look like "code: detail"; show the translated code when we know it.
export function explainError(message: string): string {
  const code = message.match(/^(\w+):/)?.[1];
  if (code && i18n.exists(`err.${code}`)) {
    const rest = message.slice(code.length + 1).trim();
    if (code === 'shift_not_ready') {
      const items = rest.split(',').map((c) => c.trim()).filter(Boolean)
        .map((c) => (i18n.exists(`problem.${c}`) ? i18n.t(`problem.${c}`) : c));
      return `${i18n.t('err.shift_not_ready')} : ${items.join(', ')}`;
    }
    return i18n.t(`err.${code}`);
  }
  return message;
}

export default i18n;
