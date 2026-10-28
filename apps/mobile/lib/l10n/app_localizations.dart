import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'1-800-GOT-JUNK? Équipe'**
  String get appTitle;

  /// No description provided for @brandRegion.
  ///
  /// In fr, this message translates to:
  /// **'Montréal'**
  String get brandRegion;

  /// No description provided for @brandProduct.
  ///
  /// In fr, this message translates to:
  /// **'Équipe'**
  String get brandProduct;

  /// No description provided for @signInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get signInTitle;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Courriel'**
  String get email;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOut;

  /// No description provided for @notCrew.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n’est pas lié à un membre d’équipe. Contactez la répartition.'**
  String get notCrew;

  /// No description provided for @todayShift.
  ///
  /// In fr, this message translates to:
  /// **'Quart du jour'**
  String get todayShift;

  /// No description provided for @noShift.
  ///
  /// In fr, this message translates to:
  /// **'Aucun quart assigné aujourd’hui. Contactez la répartition.'**
  String get noShift;

  /// No description provided for @truck.
  ///
  /// In fr, this message translates to:
  /// **'Camion'**
  String get truck;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @crew.
  ///
  /// In fr, this message translates to:
  /// **'Équipe'**
  String get crew;

  /// No description provided for @hoursType.
  ///
  /// In fr, this message translates to:
  /// **'Type d’heures'**
  String get hoursType;

  /// No description provided for @hoursRegular.
  ///
  /// In fr, this message translates to:
  /// **'Heures junk régulières'**
  String get hoursRegular;

  /// No description provided for @hoursWarehouse.
  ///
  /// In fr, this message translates to:
  /// **'Heures entrepôt'**
  String get hoursWarehouse;

  /// No description provided for @hoursNonJunk.
  ///
  /// In fr, this message translates to:
  /// **'Heures non-junk'**
  String get hoursNonJunk;

  /// No description provided for @startShift.
  ///
  /// In fr, this message translates to:
  /// **'Commencer le quart'**
  String get startShift;

  /// No description provided for @statusOpen.
  ///
  /// In fr, this message translates to:
  /// **'Pas commencé'**
  String get statusOpen;

  /// No description provided for @statusInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get statusInProgress;

  /// No description provided for @statusSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Soumis — en révision'**
  String get statusSubmitted;

  /// No description provided for @statusReturned.
  ///
  /// In fr, this message translates to:
  /// **'Retourné pour correction'**
  String get statusReturned;

  /// No description provided for @statusLocked.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get statusLocked;

  /// No description provided for @statusReopened.
  ///
  /// In fr, this message translates to:
  /// **'Rouvert'**
  String get statusReopened;

  /// No description provided for @statusReconciled.
  ///
  /// In fr, this message translates to:
  /// **'Rapproché'**
  String get statusReconciled;

  /// No description provided for @returnedBecause.
  ///
  /// In fr, this message translates to:
  /// **'Retourné : {reason}'**
  String returnedBecause(String reason);

  /// No description provided for @scoreboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get scoreboard;

  /// No description provided for @revenue.
  ///
  /// In fr, this message translates to:
  /// **'Revenus avant taxes'**
  String get revenue;

  /// No description provided for @jobsDone.
  ///
  /// In fr, this message translates to:
  /// **'Travaux'**
  String get jobsDone;

  /// No description provided for @tips.
  ///
  /// In fr, this message translates to:
  /// **'Pourboires'**
  String get tips;

  /// No description provided for @myTips.
  ///
  /// In fr, this message translates to:
  /// **'Ma part'**
  String get myTips;

  /// No description provided for @perHour.
  ///
  /// In fr, this message translates to:
  /// **'Par heure'**
  String get perHour;

  /// No description provided for @jobs.
  ///
  /// In fr, this message translates to:
  /// **'Travaux'**
  String get jobs;

  /// No description provided for @addJob.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un travail'**
  String get addJob;

  /// No description provided for @noJobs.
  ///
  /// In fr, this message translates to:
  /// **'Aucun travail pour l’instant.'**
  String get noJobs;

  /// No description provided for @opportunityId.
  ///
  /// In fr, this message translates to:
  /// **'No d’opportunité'**
  String get opportunityId;

  /// No description provided for @outcome.
  ///
  /// In fr, this message translates to:
  /// **'Résultat'**
  String get outcome;

  /// No description provided for @completed.
  ///
  /// In fr, this message translates to:
  /// **'Complété'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé / pas de vente'**
  String get cancelled;

  /// No description provided for @cancelledPending.
  ///
  /// In fr, this message translates to:
  /// **'Annulé — en attente de la répartition'**
  String get cancelledPending;

  /// No description provided for @cancelledConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get cancelledConfirmed;

  /// No description provided for @draft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get draft;

  /// No description provided for @paymentMethod.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get paymentMethod;

  /// No description provided for @preTax.
  ///
  /// In fr, this message translates to:
  /// **'Montant avant taxes'**
  String get preTax;

  /// No description provided for @totalWithTax.
  ///
  /// In fr, this message translates to:
  /// **'Total taxes incluses'**
  String get totalWithTax;

  /// No description provided for @addTax.
  ///
  /// In fr, this message translates to:
  /// **'Calculer les taxes'**
  String get addTax;

  /// No description provided for @tip.
  ///
  /// In fr, this message translates to:
  /// **'Pourboire'**
  String get tip;

  /// No description provided for @discount.
  ///
  /// In fr, this message translates to:
  /// **'Rabais'**
  String get discount;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @required.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire'**
  String get required;

  /// No description provided for @invalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide'**
  String get invalidAmount;

  /// No description provided for @totalBelowPreTax.
  ///
  /// In fr, this message translates to:
  /// **'Le total ne peut pas être inférieur au montant avant taxes'**
  String get totalBelowPreTax;

  /// No description provided for @callDispatchFirst.
  ///
  /// In fr, this message translates to:
  /// **'Appelez la répartition avant de quitter un travail non converti.'**
  String get callDispatchFirst;

  /// No description provided for @finishShift.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le quart'**
  String get finishShift;

  /// No description provided for @submitShift.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre le quart'**
  String get submitShift;

  /// No description provided for @submitConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre le quart? Vous ne pourrez plus le modifier sauf si la répartition le retourne.'**
  String get submitConfirm;

  /// No description provided for @finishTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure de fin'**
  String get finishTime;

  /// No description provided for @startTime.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get startTime;

  /// No description provided for @offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — vos données sont enregistrées et seront envoyées'**
  String get offline;

  /// No description provided for @syncing.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation…'**
  String get syncing;

  /// No description provided for @synced.
  ///
  /// In fr, this message translates to:
  /// **'À jour'**
  String get synced;

  /// No description provided for @pendingUploads.
  ///
  /// In fr, this message translates to:
  /// **'{count} modification(s) en attente'**
  String pendingUploads(int count);

  /// No description provided for @rejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusé par le serveur'**
  String get rejected;

  /// No description provided for @dismiss.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get dismiss;

  /// No description provided for @problem_crew_size.
  ///
  /// In fr, this message translates to:
  /// **'Taille d’équipe invalide'**
  String get problem_crew_size;

  /// No description provided for @problem_hours_type_missing.
  ///
  /// In fr, this message translates to:
  /// **'Type d’heures manquant'**
  String get problem_hours_type_missing;

  /// No description provided for @problem_start_time_missing.
  ///
  /// In fr, this message translates to:
  /// **'Heure de début manquante'**
  String get problem_start_time_missing;

  /// No description provided for @problem_finish_time_missing.
  ///
  /// In fr, this message translates to:
  /// **'Heure de fin manquante'**
  String get problem_finish_time_missing;

  /// No description provided for @problem_job_incomplete.
  ///
  /// In fr, this message translates to:
  /// **'Un travail est incomplet'**
  String get problem_job_incomplete;

  /// No description provided for @problem_ticket_number_missing.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de billet de dépotoir manquant'**
  String get problem_ticket_number_missing;

  /// No description provided for @problem_ticket_photo_missing.
  ///
  /// In fr, this message translates to:
  /// **'Photo du billet de dépotoir manquante'**
  String get problem_ticket_photo_missing;

  /// No description provided for @problem_visit_no_materials.
  ///
  /// In fr, this message translates to:
  /// **'Visite au dépotoir sans matière'**
  String get problem_visit_no_materials;

  /// No description provided for @problem_cash_photo_missing.
  ///
  /// In fr, this message translates to:
  /// **'Photo du comptant manquante'**
  String get problem_cash_photo_missing;

  /// No description provided for @err_shift_not_editable.
  ///
  /// In fr, this message translates to:
  /// **'Le quart est en révision par la répartition'**
  String get err_shift_not_editable;

  /// No description provided for @err_shift_locked.
  ///
  /// In fr, this message translates to:
  /// **'Le quart est verrouillé'**
  String get err_shift_locked;

  /// No description provided for @err_not_allowed.
  ///
  /// In fr, this message translates to:
  /// **'Action non permise'**
  String get err_not_allowed;

  /// No description provided for @err_hours_type_missing.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le type d’heures'**
  String get err_hours_type_missing;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @disposal.
  ///
  /// In fr, this message translates to:
  /// **'Dépotoir'**
  String get disposal;

  /// No description provided for @addVisit.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une visite'**
  String get addVisit;

  /// No description provided for @visitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Visite au dépotoir'**
  String get visitTitle;

  /// No description provided for @site.
  ///
  /// In fr, this message translates to:
  /// **'Site'**
  String get site;

  /// No description provided for @ticketNumber.
  ///
  /// In fr, this message translates to:
  /// **'No de billet'**
  String get ticketNumber;

  /// No description provided for @ticketPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo du billet'**
  String get ticketPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takePhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get retakePhoto;

  /// No description provided for @photosCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} photo(s)'**
  String photosCount(int count);

  /// No description provided for @material.
  ///
  /// In fr, this message translates to:
  /// **'Matière'**
  String get material;

  /// No description provided for @weightKg.
  ///
  /// In fr, this message translates to:
  /// **'Poids (kg)'**
  String get weightKg;

  /// No description provided for @addMaterial.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la pesée'**
  String get addMaterial;

  /// No description provided for @noVisits.
  ///
  /// In fr, this message translates to:
  /// **'Aucune visite au dépotoir.'**
  String get noVisits;

  /// No description provided for @noLines.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pesée.'**
  String get noLines;

  /// No description provided for @estimate.
  ///
  /// In fr, this message translates to:
  /// **'estimé'**
  String get estimate;

  /// No description provided for @netDisposal.
  ///
  /// In fr, this message translates to:
  /// **'Dépotoir net'**
  String get netDisposal;

  /// No description provided for @noRate.
  ///
  /// In fr, this message translates to:
  /// **'Aucun tarif pour cette matière à ce site'**
  String get noRate;

  /// No description provided for @deleteVisit.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la visite'**
  String get deleteVisit;

  /// No description provided for @cash.
  ///
  /// In fr, this message translates to:
  /// **'Comptant'**
  String get cash;

  /// No description provided for @expectedCash.
  ///
  /// In fr, this message translates to:
  /// **'Comptant à remettre'**
  String get expectedCash;

  /// No description provided for @cashPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo du comptant'**
  String get cashPhoto;

  /// No description provided for @cashPhotoHint.
  ///
  /// In fr, this message translates to:
  /// **'Étalez le comptant et prenez-le en photo.'**
  String get cashPhotoHint;

  /// No description provided for @cashPhotoDone.
  ///
  /// In fr, this message translates to:
  /// **'Photo du comptant prise'**
  String get cashPhotoDone;

  /// No description provided for @noCash.
  ///
  /// In fr, this message translates to:
  /// **'Aucun travail payé comptant.'**
  String get noCash;

  /// No description provided for @fixFirst.
  ///
  /// In fr, this message translates to:
  /// **'À régler avant de soumettre :'**
  String get fixFirst;

  /// No description provided for @photosWaiting.
  ///
  /// In fr, this message translates to:
  /// **'{count} photo(s) en attente d’envoi'**
  String photosWaiting(int count);

  /// No description provided for @reasonIs.
  ///
  /// In fr, this message translates to:
  /// **'Raison : {reason}'**
  String reasonIs(String reason);

  /// No description provided for @cameraError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’ouvrir la caméra'**
  String get cameraError;

  /// No description provided for @invalidWeight.
  ///
  /// In fr, this message translates to:
  /// **'Poids invalide'**
  String get invalidWeight;

  /// No description provided for @done.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get done;

  /// No description provided for @signOutUnsent.
  ///
  /// In fr, this message translates to:
  /// **'{count} élément(s) pas encore envoyé(s) au serveur. Si vous vous déconnectez maintenant, ils seront perdus.'**
  String signOutUnsent(int count);

  /// No description provided for @signOutAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter quand même'**
  String get signOutAnyway;

  /// No description provided for @staySignedIn.
  ///
  /// In fr, this message translates to:
  /// **'Rester connecté'**
  String get staySignedIn;

  /// No description provided for @quickTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion rapide'**
  String get quickTitle;

  /// No description provided for @quickHint.
  ///
  /// In fr, this message translates to:
  /// **'Version de développement seulement : absent des versions installées par l’équipe.'**
  String get quickHint;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'fr':
      return L10nFr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
