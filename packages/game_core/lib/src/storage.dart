import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Key-value persistence. Reads are synchronous (values are cached in memory
/// after [SharedPrefsStore.open]); writes are async.
abstract class KeyValueStore {
  int? getInt(String key);
  bool? getBool(String key);
  String? getString(String key);
  Future<void> setInt(String key, int value);
  Future<void> setBool(String key, bool value);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  bool containsKey(String key);

  /// JSON helpers on top of string storage. Corrupt JSON reads as `null`.
  Map<String, dynamic>? getJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  int getIntOr(String key, int fallback) => getInt(key) ?? fallback;
  bool getBoolOr(String key, bool fallback) => getBool(key) ?? fallback;
}

class SharedPrefsStore extends KeyValueStore {
  SharedPrefsStore._(this._prefs);

  static Future<SharedPrefsStore> open() async =>
      SharedPrefsStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  int? getInt(String key) => _prefs.getInt(key);
  @override
  bool? getBool(String key) => _prefs.getBool(key);
  @override
  String? getString(String key) => _prefs.getString(key);
  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
  @override
  bool containsKey(String key) => _prefs.containsKey(key);
}

/// In-memory fake for tests.
class InMemoryStore extends KeyValueStore {
  InMemoryStore([Map<String, Object>? initial]) : values = {...?initial};

  final Map<String, Object> values;

  @override
  int? getInt(String key) => values[key] as int?;
  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  String? getString(String key) => values[key] as String?;
  @override
  Future<void> setInt(String key, int value) async => values[key] = value;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  bool containsKey(String key) => values.containsKey(key);
}
