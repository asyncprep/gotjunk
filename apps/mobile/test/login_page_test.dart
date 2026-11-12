import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truck_team_os/l10n/app_localizations.dart';
import 'package:truck_team_os/providers.dart';
import 'package:truck_team_os/ui/login_page.dart';

/// Records what would be saved on the account, instead of calling the server.
class FakeLanguageServer extends LanguageServer {
  FakeLanguageServer([this.saved]);
  String? saved;
  @override
  Future<String?> load(String userId) async => saved;
  @override
  Future<void> save(String code) async => saved = code;
}

/// The app as main() builds it: the language comes from localeProvider.
class _App extends ConsumerWidget {
  const _App();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        locale: ref.watch(localeProvider),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // As in main(): the chosen language, else French unless the phone is in English.
        localeResolutionCallback: (device, supported) => device?.languageCode == 'en' ? const Locale('en') : const Locale('fr'),
        home: const LoginPage(),
      );
}

Future<(SharedPreferences, ProviderContainer, FakeLanguageServer)> _setUp(Map<String, Object> saved, [String? onAccount]) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final server = FakeLanguageServer(onAccount);
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(prefs),
    languageServerProvider.overrideWithValue(server),
  ]);
  return (prefs, container, server);
}

Widget _wrap(ProviderContainer c) => UncontrolledProviderScope(container: c, child: const _App());

/// A phone set to French, like the crews'.
void _frenchPhone(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const [Locale('fr', 'CA')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

void main() {
  testWidgets('sign-in screen in French by default', (tester) async {
    _frenchPhone(tester);
    final (_, c, _) = await _setUp({});
    await tester.pumpWidget(_wrap(c));
    expect(find.text('Courriel'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
  });

  testWidgets('choosing English on the sign-in screen switches it and remembers it', (tester) async {
    _frenchPhone(tester);
    final (prefs, c, _) = await _setUp({});
    await tester.pumpWidget(_wrap(c));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(prefs.getString('language'), 'en');
  });

  testWidgets('opens in the language chosen last time', (tester) async {
    _frenchPhone(tester);
    final (_, c, _) = await _setUp({'language': 'en'});
    await tester.pumpWidget(_wrap(c));
    expect(find.text('Email'), findsOneWidget);
  });

  test('after sign-in, the account language applies', () async {
    final (prefs, c, _) = await _setUp({'language': 'fr'}, 'en');
    await c.read(localeProvider.notifier).syncSignedIn('u1');
    expect(c.read(localeProvider), const Locale('en'));
    expect(prefs.getString('language'), 'en');
  });

  test('a choice made on the sign-in screen is saved on the account of whoever signs in', () async {
    final (_, c, server) = await _setUp({}, 'fr');
    await c.read(localeProvider.notifier).choose(const Locale('en'));
    expect(server.saved, 'fr', reason: 'nobody signed in yet');
    await c.read(localeProvider.notifier).syncSignedIn('u1');
    expect(server.saved, 'en');
    expect(c.read(localeProvider), const Locale('en'));
  });

  test("a choice not sent (offline) isn't given to the next person on a shared phone", () async {
    final (prefs, c, _) = await _setUp({'language': 'en', 'language_unsent_for': 'u1'}, 'fr');
    await c.read(localeProvider.notifier).syncSignedIn('u2');
    expect(c.read(localeProvider), const Locale('fr'), reason: "u2's own language");
    expect(prefs.getString('language_unsent_for'), 'u1');
  });

  test('both languages load and differ', () {
    final fr = lookupL10n(const Locale('fr'));
    final en = lookupL10n(const Locale('en'));
    expect(fr.appTitle, startsWith('1-800-GOT-JUNK?'));
    expect(en.appTitle, startsWith('1-800-GOT-JUNK?'));
    expect(fr.signIn, isNot(en.signIn));
  });
}
