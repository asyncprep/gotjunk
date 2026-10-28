// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Truck Team OS';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get notCrew =>
      'This account isn\'t linked to a crew member. Contact dispatch.';

  @override
  String get todayShift => 'Today\'s shift';

  @override
  String get noShift => 'No shift assigned today. Contact dispatch.';

  @override
  String get truck => 'Truck';

  @override
  String get phone => 'Phone';

  @override
  String get crew => 'Crew';

  @override
  String get hoursType => 'Hours type';

  @override
  String get hoursRegular => 'Regular junk hours';

  @override
  String get hoursWarehouse => 'Warehouse hours';

  @override
  String get hoursNonJunk => 'Non-junk hours';

  @override
  String get startShift => 'Start shift';

  @override
  String get statusOpen => 'Not started';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusSubmitted => 'Submitted — under review';

  @override
  String get statusReturned => 'Returned for correction';

  @override
  String get statusLocked => 'Accepted';

  @override
  String get statusReopened => 'Reopened';

  @override
  String get statusReconciled => 'Reconciled';

  @override
  String returnedBecause(String reason) {
    return 'Returned: $reason';
  }

  @override
  String get scoreboard => 'Scoreboard';

  @override
  String get revenue => 'Revenue before tax';

  @override
  String get jobsDone => 'Jobs';

  @override
  String get tips => 'Tips';

  @override
  String get myTips => 'My share';

  @override
  String get perHour => 'Per hour';

  @override
  String get jobs => 'Jobs';

  @override
  String get addJob => 'Add a job';

  @override
  String get noJobs => 'No jobs yet.';

  @override
  String get opportunityId => 'Opportunity ID';

  @override
  String get outcome => 'Outcome';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled / no sale';

  @override
  String get cancelledPending => 'Cancelled — waiting for dispatch';

  @override
  String get cancelledConfirmed => 'Cancelled';

  @override
  String get draft => 'Draft';

  @override
  String get paymentMethod => 'Payment';

  @override
  String get preTax => 'Amount before tax';

  @override
  String get totalWithTax => 'Total including tax';

  @override
  String get addTax => 'Calculate tax';

  @override
  String get tip => 'Tip';

  @override
  String get discount => 'Discount';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get required => 'Required';

  @override
  String get invalidAmount => 'Invalid amount';

  @override
  String get totalBelowPreTax =>
      'Total can\'t be lower than the amount before tax';

  @override
  String get callDispatchFirst =>
      'Call dispatch before leaving a job that didn\'t convert.';

  @override
  String get finishShift => 'Finish shift';

  @override
  String get submitShift => 'Submit shift';

  @override
  String get submitConfirm =>
      'Submit the shift? You won\'t be able to change it unless dispatch returns it.';

  @override
  String get finishTime => 'Finish time';

  @override
  String get startTime => 'Start';

  @override
  String get offline => 'Offline — your data is saved and will be sent';

  @override
  String get syncing => 'Syncing…';

  @override
  String get synced => 'Up to date';

  @override
  String pendingUploads(int count) {
    return '$count change(s) waiting to send';
  }

  @override
  String get rejected => 'Refused by the server';

  @override
  String get dismiss => 'OK';

  @override
  String get problem_crew_size => 'Invalid crew size';

  @override
  String get problem_hours_type_missing => 'Hours type missing';

  @override
  String get problem_start_time_missing => 'Start time missing';

  @override
  String get problem_finish_time_missing => 'Finish time missing';

  @override
  String get problem_job_incomplete => 'A job is incomplete';

  @override
  String get problem_ticket_number_missing => 'Disposal ticket number missing';

  @override
  String get problem_ticket_photo_missing => 'Disposal ticket photo missing';

  @override
  String get problem_visit_no_materials => 'Disposal visit with no material';

  @override
  String get problem_cash_photo_missing => 'Cash photo missing';

  @override
  String get err_shift_not_editable =>
      'The shift is being reviewed by dispatch';

  @override
  String get err_shift_locked => 'The shift is locked';

  @override
  String get err_not_allowed => 'Not allowed';

  @override
  String get err_hours_type_missing => 'Choose the hours type';

  @override
  String get language => 'Language';

  @override
  String get disposal => 'Disposal';

  @override
  String get addVisit => 'Add a visit';

  @override
  String get visitTitle => 'Disposal visit';

  @override
  String get site => 'Site';

  @override
  String get ticketNumber => 'Ticket number';

  @override
  String get ticketPhoto => 'Ticket photo';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get retakePhoto => 'Add a photo';

  @override
  String photosCount(int count) {
    return '$count photo(s)';
  }

  @override
  String get material => 'Material';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get addMaterial => 'Add weigh-in';

  @override
  String get noVisits => 'No disposal visits.';

  @override
  String get noLines => 'No weigh-ins.';

  @override
  String get estimate => 'estimate';

  @override
  String get netDisposal => 'Net disposal';

  @override
  String get noRate => 'No rate for this material at this site';

  @override
  String get deleteVisit => 'Delete visit';

  @override
  String get cash => 'Cash';

  @override
  String get expectedCash => 'Cash to hand in';

  @override
  String get cashPhoto => 'Cash photo';

  @override
  String get cashPhotoHint => 'Lay the cash out and photograph it.';

  @override
  String get cashPhotoDone => 'Cash photo taken';

  @override
  String get noCash => 'No cash jobs.';

  @override
  String get fixFirst => 'Fix before submitting:';

  @override
  String photosWaiting(int count) {
    return '$count photo(s) waiting to upload';
  }

  @override
  String reasonIs(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get cameraError => 'Couldn\'t open the camera';

  @override
  String get invalidWeight => 'Invalid weight';

  @override
  String get done => 'Done';
}
