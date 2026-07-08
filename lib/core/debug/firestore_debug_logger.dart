import 'package:flutter/foundation.dart';

/// Logs Firestore writes in debug builds to trace PERMISSION_DENIED issues.
class FirestoreDebugLogger {
  FirestoreDebugLogger._();

  static void logWrite({
    required String operation,
    required String path,
    required String? authUid,
    required List<String> participants,
    required Map<String, dynamic> payload,
    required bool documentExists,
    Map<String, dynamic>? existingData,
  }) {
    if (!kDebugMode) return;

    debugPrint('─── Firestore WRITE ───');
    debugPrint('operation     : $operation');
    debugPrint('path          : $path');
    debugPrint('authUid       : $authUid');
    debugPrint('participants  : $participants');
    debugPrint('authInList    : ${authUid != null && participants.contains(authUid)}');
    debugPrint('docExists     : $documentExists');
    debugPrint('existingData  : $existingData');
    debugPrint('payload       : $payload');
    debugPrint('────────────────────────');
  }

  static void logRead({
    required String path,
    required String? authUid,
    required bool documentExists,
    Map<String, dynamic>? data,
  }) {
    if (!kDebugMode) return;

    debugPrint('─── Firestore READ ───');
    debugPrint('path      : $path');
    debugPrint('authUid   : $authUid');
    debugPrint('exists    : $documentExists');
    debugPrint('data      : $data');
    debugPrint('─────────────────────');
  }
}
