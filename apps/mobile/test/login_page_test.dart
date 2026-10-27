import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truck_team_os/l10n/app_localizations.dart';
import 'package:truck_team_os/ui/login_page.dart';

Widget _app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginPage(),
    );

void main() {
  testWidgets('sign-in screen in French', (tester) async {
    await tester.pumpWidget(_app(const Locale('fr')));
    expect(find.text('Courriel'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Se connecter'), findsOneWidget);
  });

  testWidgets('sign-in screen in English', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    expect(find.text('Email'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  test('both languages load and differ', () {
    final fr = lookupL10n(const Locale('fr'));
    final en = lookupL10n(const Locale('en'));
    expect(fr.appTitle, en.appTitle);
    expect(fr.signIn, isNot(en.signIn));
  });
}
