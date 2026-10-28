import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/photo_uploader.dart';
import 'data/repo.dart';

/// Provided in main() once the on-phone database is open.
final repoProvider = Provider<Repo>((ref) => throw UnimplementedError('repoProvider not overridden'));

/// Where photos wait on the phone until they are uploaded.
final photoDirProvider = Provider<Directory>((ref) => throw UnimplementedError('photoDirProvider not overridden'));

final photoUploaderProvider =
    Provider<PhotoUploader>((ref) => throw UnimplementedError('photoUploaderProvider not overridden'));

/// null = follow the phone's language (French by default).
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void set(Locale? locale) => state = locale;
}
