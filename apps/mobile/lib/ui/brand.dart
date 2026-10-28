import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 1-800-GOT-JUNK? palette, the same as the admin app (apps/admin/src/styles.css).
abstract final class BrandColors {
  static const blue = Color(0xFF00539F);
  static const blueDark = Color(0xFF003867);
  static const blueLight = Color(0xFFE4F2FE);
  static const green = Color(0xFF72A230);
  static const greenDark = Color(0xFF567B24);
  static const greenLight = Color(0xFFEDF7E2);
  static const red = Color(0xFFB91C1C);
  static const redLight = Color(0xFFFBE9E9);
  static const amber = Color(0xFF8A6400);
  static const amberLight = Color(0xFFFBF4D9);
  static const accentDark = Color(0xFF58B3FF);

  static const bg = Color(0xFFF4F6F9);
  static const ink = Color(0xFF222B36);
  static const muted = Color(0xFF5D6B7A);
  static const line = Color(0xFFDDE3EA);
  static const bgDark = Color(0xFF0F141B);
  static const surfaceDark = Color(0xFF171E27);
  static const inkDark = Color(0xFFE6EBF1);
  static const mutedDark = Color(0xFF9AA8B8);
  static const lineDark = Color(0xFF2A3441);
}

ThemeData brandTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: BrandColors.blue, brightness: brightness).copyWith(
    primary: dark ? BrandColors.accentDark : BrandColors.blue,
    onPrimary: dark ? BrandColors.bgDark : Colors.white,
    secondary: BrandColors.green,
    onSecondary: Colors.white,
    error: dark ? const Color(0xFFF87171) : BrandColors.red,
    surface: dark ? BrandColors.surfaceDark : Colors.white,
    onSurface: dark ? BrandColors.inkDark : BrandColors.ink,
    onSurfaceVariant: dark ? BrandColors.mutedDark : BrandColors.muted,
    outlineVariant: dark ? BrandColors.lineDark : BrandColors.line,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? BrandColors.bgDark : BrandColors.bg,
    // Blue header in both themes, like the admin app.
    appBarTheme: const AppBarTheme(
      backgroundColor: BrandColors.blue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dark ? BrandColors.lineDark : BrandColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: shape)),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// The main action on a screen (start, submit, save), green like the admin's "Accept".
ButtonStyle goButtonStyle() => FilledButton.styleFrom(
      backgroundColor: BrandColors.green,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
    );

/// Shift status chip colours, matching the admin board's badges.
({Color background, Color foreground}) statusColors(BuildContext context, String? status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  Color tone(Color light, Color darkColor) => dark ? darkColor : light;
  return switch (status) {
    'submitted' => (background: tone(BrandColors.amberLight, const Color(0xFF352B0C)), foreground: tone(BrandColors.amber, const Color(0xFFF2C94C))),
    'locked' || 'reconciled' => (background: tone(BrandColors.greenLight, const Color(0xFF1F2D12)), foreground: tone(BrandColors.greenDark, const Color(0xFFA3D16A))),
    'returned' => (background: tone(BrandColors.redLight, const Color(0xFF3A1515)), foreground: tone(BrandColors.red, const Color(0xFFF87171))),
    'in_progress' || 'reopened' => (background: tone(BrandColors.blueLight, const Color(0xFF0F2A44)), foreground: tone(BrandColors.blue, BrandColors.accentDark)),
    _ => (background: tone(const Color(0xFFEEF2F6), const Color(0xFF222B36)), foreground: tone(BrandColors.muted, BrandColors.mutedDark)),
  };
}

/// The official logo if one has been added as assets/brand/logo.png (from the franchise brand kit;
/// don't recreate it), otherwise the typed wordmark. Then "MONTRÉAL · subtitle".
class Brand extends StatelessWidget {
  const Brand({super.key, this.subtitle, this.large = false});

  final String? subtitle;

  /// Large: sign-in and start-up screens. Otherwise sized for the blue header.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = large ? (dark ? Colors.white : BrandColors.blue) : Colors.white;
    final sub = large ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.white.withValues(alpha: 0.85);
    final wordmark = Text.rich(
      TextSpan(children: [
        const TextSpan(text: '1-800-GOT-JUNK'),
        const TextSpan(text: '?', style: TextStyle(color: BrandColors.green)),
      ]),
      style: TextStyle(fontWeight: FontWeight.w900, fontSize: large ? 30 : 19, color: ink, height: 1.1),
      semanticsLabel: '1-800-GOT-JUNK?',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/brand/logo.png', height: large ? 44 : 28, errorBuilder: (_, _, _) => wordmark),
        SizedBox(height: large ? 4 : 1),
        Text(
          '${t.brandRegion} · ${subtitle ?? t.brandProduct}'.toUpperCase(),
          style: TextStyle(fontSize: large ? 12 : 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: sub),
        ),
      ],
    );
  }
}
