import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/background.dart';
import '../data/field_repo.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'format.dart';

/// Opens the camera and stores the picture against a record. Returns true if a photo was saved.
Future<bool> capturePhoto(
  BuildContext context,
  WidgetRef ref, {
  required String shiftId,
  required String kind,
  required String entityType,
  required String entityId,
}) async {
  final t = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final errorPrefix = labelled(context, t.cameraError, ''); // built before the camera opens
  try {
    // Reduced size keeps uploads quick on weak signal while staying readable.
    final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (shot == null) return false;
    await ref.read(repoProvider).addPhoto(
          shiftId: shiftId,
          kind: kind,
          entityType: entityType,
          entityId: entityId,
          picture: File(shot.path),
          photoDir: ref.read(photoDirProvider),
        );
    ref.read(photoUploaderProvider).runOnce();
    schedulePhotoUpload().catchError((_) {}); // finishes even if the app is closed first
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$errorPrefix$e')));
    return false;
  }
}
