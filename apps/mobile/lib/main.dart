import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'data/background.dart';
import 'data/database.dart';
import 'data/photo_uploader.dart';
import 'data/repo.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw immediately; open Supabase and the on-phone database behind a loading screen.
  runApp(const BootApp());
}

class _Services {
  _Services(this.repo, this.photoDir, this.uploader);
  final Repo repo;
  final Directory photoDir;
  final PhotoUploader uploader;
}

Future<_Services> _startServices() async {
  final clock = Stopwatch()..start();
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
  markSupabaseReady();
  final supabaseMs = clock.elapsedMilliseconds;
  final db = await openDatabase();
  final photoDir = await photoDirectory();
  final uploader = PhotoUploader(db)..start();
  debugPrint('Start-up: Supabase ${supabaseMs}ms, database ${clock.elapsedMilliseconds - supabaseMs}ms');
  // After the app is on screen: background setup never delays the crew.
  initBackgroundUploads().catchError((Object e) {
    debugPrint('Background uploads unavailable: $e'); // the in-app uploader still runs
  });
  return _Services(Repo(db), photoDir, uploader);
}

class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  late final Future<_Services> _services = _startServices();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Services>(
      future: _services,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            home: Scaffold(
              body: Center(
                child: snap.hasError
                    ? Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}', textAlign: TextAlign.center))
                    : const CircularProgressIndicator(),
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [
            repoProvider.overrideWithValue(s.repo),
            photoDirProvider.overrideWithValue(s.photoDir),
            photoUploaderProvider.overrideWithValue(s.uploader),
          ],
          child: const TruckTeamApp(),
        );
      },
    );
  }
}

ThemeData _theme(Brightness brightness) =>
    ThemeData(colorSchemeSeed: const Color(0xFF00539F), brightness: brightness, useMaterial3: true);

class TruckTeamApp extends ConsumerWidget {
  const TruckTeamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
