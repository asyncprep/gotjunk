// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Truck Team OS';

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
  String get language => 'Langue';
}
