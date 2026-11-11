import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only JSON preferences. No SQL, remote API, or database is involved.
class LocalStore {
  final SharedPreferences preferences;
  LocalStore(this.preferences);
  dynamic read(String key, dynamic fallback) {
    try {
      final raw = preferences.getString(key);
      return raw == null ? fallback : jsonDecode(raw);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> write(String key, dynamic value) async {
    if (!await preferences.setString(key, jsonEncode(value))) {
      throw StateError(
        'Could not save local data. Check available device storage.',
      );
    }
  }
}
