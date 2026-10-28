import 'package:flutter/foundation.dart';

/// One-click sign-in for debug builds only (emulator / developer phones).
/// Accounts come from a git-ignored file passed at run time:
///   flutter run --dart-define-from-file=quick_signin.json
/// with quick_signin.json = {"QUICK_SIGNIN": "Crew|crew@example.com|secret;Lead|lead@example.com"}
/// The password is optional: without it the button only fills in the email.
/// Release builds never include it: kDebugMode is false there and the list is empty.
class QuickAccount {
  const QuickAccount(this.label, this.email, [this.password]);
  final String label;
  final String email;
  final String? password;

  @override
  bool operator ==(Object other) =>
      other is QuickAccount && other.label == label && other.email == email && other.password == password;

  @override
  int get hashCode => Object.hash(label, email, password);

  @override
  String toString() => 'QuickAccount($label, $email, ${password == null ? 'no password' : 'password'})';
}

List<QuickAccount> parseQuickAccounts(String raw) => raw
    .split(';')
    .map((entry) => entry.split('|').map((part) => part.trim()).toList())
    .where((parts) => parts.length >= 2 && parts[0].isNotEmpty && parts[1].contains('@'))
    .map((parts) => QuickAccount(parts[0], parts[1], parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null))
    .toList();

const _raw = String.fromEnvironment('QUICK_SIGNIN');

final List<QuickAccount> quickAccounts = kDebugMode ? parseQuickAccounts(_raw) : const [];
