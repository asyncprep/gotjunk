import i18n from './i18n';

// Strings for the Stripe payments page (to fold into i18n.ts).
const fr = {
  nav: { payments: 'Paiements' },
  stripe: {
    title: 'Paiements Stripe',
    intro: 'Lecture seule : les paiements Stripe du jour, à côté de la job qui a le même numéro d’opportunité dans l’application. Avant taxes = (montant − pourboire) ÷ 1,14975.',
    error: 'Lecture de Stripe impossible :',
    byLogin: 'Par connexion HQ', login: 'Connexion HQ', payments: 'Paiements', none: 'Aucun paiement réussi ce jour-là.',
    list_one: '{{count}} paiement', list_other: '{{count}} paiements',
    time: 'Heure', opportunity: 'No d’opportunité', amount: 'Montant', tip: 'Pourboire', preTax: 'Avant taxes',
    status: 'Statut', method: 'Carte', reader: 'Terminal', typed: 'Saisie manuelle', refunded: 'remboursé',
    inApp: 'Dans l’application', notInApp: 'Pas encore saisie', differs: 'l’application dit {{amount}}',
    st_succeeded: 'Réussi', st_failed: 'Échoué', st_pending: 'En attente',
  },
};
const en: typeof fr = {
  nav: { payments: 'Payments' },
  stripe: {
    title: 'Stripe payments',
    intro: 'Read-only: the day’s Stripe payments, next to the job with the same Opportunity ID in the app. Pre-tax = (amount − tip) ÷ 1.14975.',
    error: 'Couldn’t read Stripe:',
    byLogin: 'By HQ login', login: 'HQ login', payments: 'Payments', none: 'No successful payments that day.',
    list_one: '{{count}} payment', list_other: '{{count}} payments',
    time: 'Time', opportunity: 'Opportunity ID', amount: 'Amount', tip: 'Tip', preTax: 'Pre-tax',
    status: 'Status', method: 'Card', reader: 'Reader', typed: 'Typed in', refunded: 'refunded',
    inApp: 'In the app', notInApp: 'Not entered yet', differs: 'the app says {{amount}}',
    st_succeeded: 'Succeeded', st_failed: 'Failed', st_pending: 'Pending',
  },
};

i18n.addResourceBundle('fr', 'translation', fr, true, false);
i18n.addResourceBundle('en', 'translation', en, true, false);
