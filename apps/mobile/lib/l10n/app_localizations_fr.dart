// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => '1-800-GOT-JUNK? Équipe';

  @override
  String get brandRegion => 'Montréal';

  @override
  String get brandProduct => 'Équipe';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get email => 'Courriel';

  @override
  String get password => 'Mot de passe';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get notCrew =>
      'Ce compte n’est pas lié à un membre d’équipe. Contactez la répartition.';

  @override
  String get todayShift => 'Quart du jour';

  @override
  String get noShift =>
      'Aucun quart assigné aujourd’hui. Contactez la répartition.';

  @override
  String get truck => 'Camion';

  @override
  String get phone => 'Téléphone';

  @override
  String get crew => 'Équipe';

  @override
  String get hoursType => 'Type d’heures';

  @override
  String get hoursRegular => 'Heures junk régulières';

  @override
  String get hoursWarehouse => 'Heures entrepôt';

  @override
  String get hoursNonJunk => 'Heures non-junk';

  @override
  String get startShift => 'Commencer le quart';

  @override
  String get statusOpen => 'Pas commencé';

  @override
  String get statusInProgress => 'En cours';

  @override
  String get statusSubmitted => 'Soumis — en révision';

  @override
  String get statusReturned => 'Retourné pour correction';

  @override
  String get statusLocked => 'Accepté';

  @override
  String get statusReopened => 'Rouvert';

  @override
  String get statusReconciled => 'Rapproché';

  @override
  String returnedBecause(String reason) {
    return 'Retourné : $reason';
  }

  @override
  String get scoreboard => 'Tableau de bord';

  @override
  String get revenue => 'Revenus avant taxes';

  @override
  String get jobsDone => 'Travaux';

  @override
  String get tips => 'Pourboires';

  @override
  String get myTips => 'Ma part';

  @override
  String get perHour => 'Par heure';

  @override
  String get jobs => 'Travaux';

  @override
  String get addJob => 'Ajouter un travail';

  @override
  String get noJobs => 'Aucun travail pour l’instant.';

  @override
  String get opportunityId => 'No d’opportunité';

  @override
  String get outcome => 'Résultat';

  @override
  String get completed => 'Complété';

  @override
  String get cancelled => 'Annulé / pas de vente';

  @override
  String get cancelledPending => 'Annulé — en attente de la répartition';

  @override
  String get cancelledConfirmed => 'Annulé';

  @override
  String get draft => 'Brouillon';

  @override
  String get paymentMethod => 'Paiement';

  @override
  String get preTax => 'Montant avant taxes';

  @override
  String get totalWithTax => 'Total taxes incluses';

  @override
  String get addTax => 'Calculer les taxes';

  @override
  String get tip => 'Pourboire';

  @override
  String get discount => 'Rabais';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get required => 'Obligatoire';

  @override
  String get invalidAmount => 'Montant invalide';

  @override
  String get totalBelowPreTax =>
      'Le total ne peut pas être inférieur au montant avant taxes';

  @override
  String get callDispatchFirst =>
      'Appelez la répartition avant de quitter un travail non converti.';

  @override
  String get finishShift => 'Terminer le quart';

  @override
  String get submitShift => 'Soumettre le quart';

  @override
  String get submitConfirm =>
      'Soumettre le quart? Vous ne pourrez plus le modifier sauf si la répartition le retourne.';

  @override
  String get finishTime => 'Heure de fin';

  @override
  String get startTime => 'Début';

  @override
  String get offline =>
      'Hors ligne — vos données sont enregistrées et seront envoyées';

  @override
  String get syncing => 'Synchronisation…';

  @override
  String get synced => 'À jour';

  @override
  String pendingUploads(int count) {
    return '$count modification(s) en attente';
  }

  @override
  String get rejected => 'Refusé par le serveur';

  @override
  String get dismiss => 'OK';

  @override
  String get problem_crew_size => 'Taille d’équipe invalide';

  @override
  String get problem_hours_type_missing => 'Type d’heures manquant';

  @override
  String get problem_start_time_missing => 'Heure de début manquante';

  @override
  String get problem_finish_time_missing => 'Heure de fin manquante';

  @override
  String get problem_job_incomplete => 'Un travail est incomplet';

  @override
  String get problem_ticket_number_missing =>
      'Numéro de billet de dépotoir manquant';

  @override
  String get problem_ticket_photo_missing =>
      'Photo du billet de dépotoir manquante';

  @override
  String get problem_visit_no_materials => 'Visite au dépotoir sans matière';

  @override
  String get problem_cash_photo_missing => 'Photo du comptant manquante';

  @override
  String get err_shift_not_editable =>
      'Le quart est en révision par la répartition';

  @override
  String get err_shift_locked => 'Le quart est verrouillé';

  @override
  String get err_not_allowed => 'Action non permise';

  @override
  String get err_hours_type_missing => 'Choisissez le type d’heures';

  @override
  String get err_no_rate =>
      'Aucun tarif actif pour cette matière à ce site : avisez la répartition';

  @override
  String get err_crew_double_booked =>
      'Un membre de l’équipe est déjà sur un autre quart actif ce jour-là';

  @override
  String get err_photo_entity_missing =>
      'La photo n’a pas été envoyée : sa visite ou son comptant a été refusé';

  @override
  String get err_photo_shift_mismatch =>
      'La photo ne correspond pas à ce quart';

  @override
  String get err_invalid_transition => 'Ce changement d’état n’est pas permis';

  @override
  String get err_reason_required => 'Une raison est requise';

  @override
  String get err_not_found =>
      'Changement non appliqué : l’élément n’existe plus ou n’est plus modifiable';

  @override
  String get err_duplicate => 'Déjà saisi : ce numéro existe déjà';

  @override
  String get err_invalid_value =>
      'Valeur refusée (par exemple, une heure de fin avant l’heure de début)';

  @override
  String get err_missing_parent =>
      'Refusé parce que l’élément auquel il est rattaché a été refusé';

  @override
  String get duplicateTicket =>
      'Ce numéro de billet est déjà utilisé à ce site';

  @override
  String get duplicateOpportunity =>
      'Ce numéro d’opportunité est déjà dans ce quart';

  @override
  String get problem_tip_unassigned =>
      'Un pourboire n’a personne à qui aller (heures d’arrivée ou de départ de l’équipe)';

  @override
  String get problem_photo_not_uploaded => 'Une photo n’est pas encore envoyée';

  @override
  String get problem_opportunity_repeated =>
      'Le même numéro d’opportunité apparaît deux fois';

  @override
  String get problem_hours_type_unconfirmed => 'Type d’heures non confirmé';

  @override
  String get problem_cancellation_pending =>
      'Une annulation attend la répartition';

  @override
  String get problem_tax_check =>
      'Le total avec taxes ne correspond pas au montant avant taxes';

  @override
  String get language => 'Langue';

  @override
  String get disposal => 'Dépotoir';

  @override
  String get addVisit => 'Ajouter une visite';

  @override
  String get visitTitle => 'Visite au dépotoir';

  @override
  String get site => 'Site';

  @override
  String get ticketNumber => 'No de billet';

  @override
  String get ticketPhoto => 'Photo du billet';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get retakePhoto => 'Ajouter une photo';

  @override
  String photosCount(int count) {
    return '$count photo(s)';
  }

  @override
  String get material => 'Matière';

  @override
  String get weightKg => 'Poids (kg)';

  @override
  String get addMaterial => 'Ajouter la pesée';

  @override
  String get noVisits => 'Aucune visite au dépotoir.';

  @override
  String get noLines => 'Aucune pesée.';

  @override
  String get estimate => 'estimé';

  @override
  String get netDisposal => 'Dépotoir net';

  @override
  String get noRate => 'Aucun tarif pour cette matière à ce site';

  @override
  String get deleteVisit => 'Supprimer la visite';

  @override
  String get cash => 'Comptant';

  @override
  String get expectedCash => 'Comptant à remettre';

  @override
  String get cashPhoto => 'Photo du comptant';

  @override
  String get cashPhotoHint => 'Étalez le comptant et prenez-le en photo.';

  @override
  String get cashPhotoDone => 'Photo du comptant prise';

  @override
  String get noCash => 'Aucun travail payé comptant.';

  @override
  String get fixFirst => 'À régler avant de soumettre :';

  @override
  String photosWaiting(int count) {
    return '$count photo(s) en attente d’envoi';
  }

  @override
  String reasonIs(String reason) {
    return 'Raison : $reason';
  }

  @override
  String get cameraError => 'Impossible d’ouvrir la caméra';

  @override
  String get invalidWeight => 'Poids invalide';

  @override
  String get done => 'Terminé';

  @override
  String signOutUnsent(int count) {
    return '$count élément(s) pas encore envoyé(s) au serveur. Si vous vous déconnectez maintenant, ils seront perdus.';
  }

  @override
  String get signOutAnyway => 'Se déconnecter quand même';

  @override
  String get staySignedIn => 'Rester connecté';

  @override
  String get quickTitle => 'Connexion rapide';

  @override
  String get quickHint =>
      'Version de développement seulement : absent des versions installées par l’équipe.';
}
