import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/photo_uploader.dart';
import 'data/repo.dart';

/// Provided in main() once the on-phone database is open.
final repoProvider = Provider<Repo>((ref) => throw UnimplementedError('repoProvider not overridden'));

/// Where photos wait on the phone until they are uploaded.
final photoDirProvider = Provider<Directory>((ref) => throw UnimplementedError('photoDirProvider not overridden'));

final photoUploaderProvider =
    Provider<PhotoUploader>((ref) => throw UnimplementedError('photoUploaderProvider not overridden'));

/// The phone's small settings store, loaded in main() before the first screen.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider not overridden'));

/// The signed-in person's language on the server (app_user.language); replaced in tests.
class LanguageServer {
  const LanguageServer();

  Future<String?> load(String userId) async {
    final row = await Supabase.instance.client.from('app_user').select('language').eq('user_id', userId).maybeSingle();
    return row?['language'] as String?;
  }

  Future<void> save(String code) => Supabase.instance.client.rpc('set_my_language', params: {'p_language': code});
}

final languageServerProvider = Provider<LanguageServer>((ref) => const LanguageServer());

/// The app's language: French or English. null = not chosen yet (follow the phone, French by
/// default). Remembered on the phone for the sign-in screen, and on the person's account so it
/// follows them to any truck phone.
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  static const _key = 'language';
  // Whose choice hasn't reached the server yet: a user id, or '*' for a choice made on the
  // sign-in screen, which becomes the language of whoever signs in next.
  static const _unsentKey = 'language_unsent_for';

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  Locale? build() {
    final code = _prefs.getString(_key);
    return code == 'fr' || code == 'en' ? Locale(code!) : null;
  }

  /// [userId] is who is signed in, or null on the sign-in screen.
  Future<void> choose(Locale locale, {String? userId}) async {
    state = locale;
    await _prefs.setString(_key, locale.languageCode);
    await _prefs.setString(_unsentKey, userId ?? '*');
    if (userId != null) await _send();
  }

  Future<void> _send() async {
    final code = state?.languageCode;
    if (code == null) return;
    try {
      await ref.read(languageServerProvider).save(code);
      await _prefs.remove(_unsentKey);
    } catch (_) {
      // Offline: sent the next time this person opens the app signed in.
    }
  }

  /// After sign-in: a choice not sent yet wins; otherwise the person's saved language applies.
  Future<void> syncSignedIn(String userId) async {
    final unsent = _prefs.getString(_unsentKey);
    if (unsent == userId || unsent == '*') return _send();
    try {
      final code = await ref.read(languageServerProvider).load(userId);
      if (code == 'fr' || code == 'en') {
        state = Locale(code!);
        await _prefs.setString(_key, code);
      }
    } catch (_) {
      // Offline: keep the phone's last language.
    }
  }
}
