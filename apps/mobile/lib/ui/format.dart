import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

String money(BuildContext context, num? value) {
  final locale = Localizations.localeOf(context).languageCode == 'en' ? 'en_CA' : 'fr_CA';
  return NumberFormat.simpleCurrency(locale: locale, name: 'CAD').format(value ?? 0);
}

String clock(BuildContext context, String? iso) {
  if (iso == null) return '—';
  final t = DateTime.tryParse(iso)?.toLocal();
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
String explainRejection(L10n t, String message) {
  final match = RegExp(r'^(\w+):\s*(.*)$').firstMatch(message);
  if (match == null) return message;
  final code = match.group(1)!;
  final rest = match.group(2)!;
  if (code == 'shift_not_ready') {
    return rest.split(',').map((c) => _problem(t, c.trim())).join(' · ');
  }
  return switch (code) {
    'shift_not_editable' => t.err_shift_not_editable,
    'shift_locked' => t.err_shift_locked,
    'not_allowed' => t.err_not_allowed,
    'hours_type_missing' => t.err_hours_type_missing,
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
      _ => code,
    };
