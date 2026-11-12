import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';

/// Français / English, side by side. Shown on the sign-in screen and in Settings.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key, this.userId});

  /// Who is signed in, or null on the sign-in screen.
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = Localizations.localeOf(context).languageCode;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'fr', label: Text('Français')),
        ButtonSegment(value: 'en', label: Text('English')),
      ],
      selected: {current},
      onSelectionChanged: (s) => ref.read(localeProvider.notifier).choose(Locale(s.first), userId: userId),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.userId, this.email});
  final String userId;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t.language, style: text.titleSmall),
                const SizedBox(height: 12),
                LanguagePicker(userId: userId),
                const SizedBox(height: 8),
                Text(t.languageHint, style: text.bodySmall),
              ]),
            ),
          ),
          if (email != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(t.signedInAs),
                subtitle: Text(email!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
