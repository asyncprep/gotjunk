import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../business_time.dart';
import '../l10n/app_localizations.dart';

String money(BuildContext context, num? value) {
  final locale = Localizations.localeOf(context).languageCode == 'en' ? 'en_CA' : 'fr_CA';
  return NumberFormat.simpleCurrency(locale: locale, name: 'CAD').format(value ?? 0);
}

/// Time of day in Montréal, whatever the phone's own time zone.
String clock(BuildContext context, String? iso) {
  if (iso == null) return '—';
  final parsed = DateTime.tryParse(iso);
  final t = parsed == null ? null : inBusinessZone(parsed);
  return t == null ? '—' : DateFormat.Hm(Localizations.localeOf(context).languageCode).format(t);
}

/// "Label: value" with French typography ("Libellé : valeur").
String labelled(BuildContext context, String label, String value) =>
    Localizations.localeOf(context).languageCode == 'fr' ? '$label : $value' : '$label: $value';

double? parseAmount(String text) {
  final cleaned = text.trim().replaceAll(' ', '').replaceAll(r'$', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String statusLabel(L10n t, String? status) => switch (status) {
      'open' => t.statusOpen,
      'in_progress' => t.statusInProgress,
      'submitted' => t.statusSubmitted,
      'returned' => t.statusReturned,
      'locked' => t.statusLocked,
      'reopened' => t.statusReopened,
      'reconciled' => t.statusReconciled,
      _ => status ?? '',
    };

String hoursLabel(L10n t, String? hours) => switch (hours) {
      'regular_junk' => t.hoursRegular,
      'warehouse' => t.hoursWarehouse,
      'non_junk' => t.hoursNonJunk,
      _ => '—',
    };

String outcomeLabel(L10n t, String? outcome) => switch (outcome) {
      'completed' => t.completed,
      'cancelled_pending' => t.cancelledPending,
      'cancelled_confirmed' => t.cancelledConfirmed,
      _ => t.draft,
    };

/// Turns a server refusal like "shift_not_ready: finish_time_missing, job_incomplete" into crew language.
/// [sqlState] is the database error code, for refusals that carry no message of ours (constraints).
String explainRejection(L10n t, String message, {String? sqlState}) {
  switch (sqlState) {
    case '23505':
      if (message.contains('disposal_visit_ticket')) return t.duplicateTicket;
      if (message.contains('opportunity')) return t.duplicateOpportunity;
      return t.err_duplicate;
    case '23514' || '22007' || '22P02' || '22003':
      return t.err_invalid_value;
    case '23503':
      return t.err_missing_parent;
    case '42501':
      return t.err_not_allowed;
  }
  final match = RegExp(r'^(\w+)(?::\s*(.*))?$', dotAll: true).firstMatch(message);
  if (match == null) return message;
  final code = match.group(1)!;
  final rest = match.group(2) ?? '';
  if (code == 'shift_not_ready') {
    return rest.split(',').map((c) => _problem(t, c.trim())).join(' · ');
  }
  return switch (code) {
    'shift_not_editable' => t.err_shift_not_editable,
    'shift_locked' => t.err_shift_locked,
    'not_allowed' => t.err_not_allowed,
    'hours_type_missing' => t.err_hours_type_missing,
    'no_rate' => t.err_no_rate,
    'crew_double_booked' => t.err_crew_double_booked,
    'photo_entity_missing' => t.err_photo_entity_missing,
    'photo_shift_mismatch' => t.err_photo_shift_mismatch,
    'invalid_transition' => t.err_invalid_transition,
    'reason_required' => t.err_reason_required,
    'not_found' => t.err_not_found,
    'not_lead' => t.err_not_lead,
    'lead_not_crew' => t.err_lead_not_crew,
    _ => message,
  };
}

String _problem(L10n t, String code) => switch (code) {
      'crew_size' => t.problem_crew_size,
      'hours_type_missing' => t.problem_hours_type_missing,
      'start_time_missing' => t.problem_start_time_missing,
      'finish_time_missing' => t.problem_finish_time_missing,
      'job_incomplete' => t.problem_job_incomplete,
      'ticket_number_missing' => t.problem_ticket_number_missing,
      'ticket_photo_missing' => t.problem_ticket_photo_missing,
      'visit_no_materials' => t.problem_visit_no_materials,
      'cash_photo_missing' => t.problem_cash_photo_missing,
      'tip_unassigned' => t.problem_tip_unassigned,
      'photo_not_uploaded' => t.problem_photo_not_uploaded,
      'opportunity_repeated' => t.problem_opportunity_repeated,
      'hours_type_unconfirmed' => t.problem_hours_type_unconfirmed,
      'cancellation_pending' => t.problem_cancellation_pending,
      'tax_check' => t.problem_tax_check,
      _ => code,
    };
