import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'data/database.dart';
import 'data/photo_uploader.dart';
import 'data/repo.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
  final db = await openDatabase();
  final photoDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'photos'));
  final uploader = PhotoUploader(db)..start();
  runApp(ProviderScope(
    overrides: [
      repoProvider.overrideWithValue(Repo(db)),
      photoDirProvider.overrideWithValue(photoDir),
      photoUploaderProvider.overrideWithValue(uploader),
    ],
    child: const TruckTeamApp(),
  ));
}

class TruckTeamApp extends ConsumerWidget {
  const TruckTeamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF00539F), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF00539F), brightness: Brightness.dark, useMaterial3: true),
      locale: ref.watch(localeProvider),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // French unless the phone is set to English.
      localeResolutionCallback: (device, supported) =>
          device?.languageCode == 'en' ? const Locale('en') : const Locale('fr'),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, _) {
          final session = Supabase.instance.client.auth.currentSession;
          return session == null ? const LoginPage() : HomePage(userId: session.user.id);
        },
      ),
    );
  }
}
