import 'package:flutter/foundation.dart';

/// Development diagnostics may include account or book data.
/// Keep them out of release logs.
void debugLog(String? message) {
  if (kDebugMode) debugPrint(message);
}
