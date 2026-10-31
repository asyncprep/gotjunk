import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:truck_team_os/data/connector.dart';
import 'package:truck_team_os/l10n/app_localizations_en.dart';
import 'package:truck_team_os/l10n/app_localizations_fr.dart';
import 'package:truck_team_os/ui/format.dart';

void main() {
  group('parseAmount', () {
    test('accepts French and English decimals', () {
      expect(parseAmount('114,98'), 114.98);
      expect(parseAmount('114.98'), 114.98);
      expect(parseAmount(r'$ 1 200,50'), 1200.50);
    });
    test('empty and junk', () {
      expect(parseAmount('  '), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });

  group('explainRejection', () {
    test('lists missing items in crew language', () {
      expect(
        explainRejection(L10nEn(), 'shift_not_ready: finish_time_missing, job_incomplete'),
        'Finish time missing · A job is incomplete',
      );
      expect(
        explainRejection(L10nFr(), 'shift_not_ready: cash_photo_missing'),
        'Photo du comptant manquante',
      );
    });
    test('known single codes and passthrough', () {
      expect(explainRejection(L10nEn(), 'shift_locked: reopen the shift before editing'), 'The shift is locked');
      expect(explainRejection(L10nEn(), 'something unexpected'), 'something unexpected');
      expect(explainRejection(L10nEn(), 'not_allowed: crew cannot change locked_by'), 'Not allowed');
      expect(explainRejection(L10nFr(), 'no_rate: no active rate for this site and material on 2026-10-30'),
          startsWith('Aucun tarif actif'));
      expect(explainRejection(L10nEn(), 'not_found: job 123'), startsWith('Change not applied'));
      expect(explainRejection(L10nEn(), 'shift_not_ready: tip_unassigned, photo_not_uploaded'),
          'A tip has nobody to go to (crew arrival or departure times) · A photo hasn\'t been sent yet');
    });
    test('constraint refusals by database code', () {
      expect(
        explainRejection(L10nEn(), 'duplicate key value violates unique constraint "disposal_visit_ticket_uq"',
            sqlState: '23505'),
        'This ticket number is already used at this site',
      );
      expect(explainRejection(L10nFr(), 'new row violates check constraint "shift_times_ck"', sqlState: '23514'),
          startsWith('Valeur refusée'));
      expect(explainRejection(L10nEn(), 'insert violates foreign key', sqlState: '23503'),
          'Refused because the item it belongs to was refused');
    });
  });

  group('isRejection', () {
    PostgrestException err(String code) => PostgrestException(message: 'x', code: code);
    test('business and data errors are not retried', () {
      for (final code in ['P0001', '23505', '23514', '22P02', '42501']) {
        expect(isRejection(err(code)), isTrue, reason: code);
      }
    });
    test('transient errors are retried', () {
      for (final code in ['57014', '08006', 'PGRST301']) {
        expect(isRejection(err(code)), isFalse, reason: code);
      }
    });
  });
}
