import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple key-value cache backed by SharedPreferences.
/// Supports optional TTL (time-to-live). If no TTL is specified, data never
/// expires and must be manually invalidated.
class CacheService {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Save [data] under [key]. Optionally set [ttl] after which the cache is
  /// considered stale. Saves the current timestamp alongside the data so TTL
  /// can be evaluated on load.
  static Future<void> save(
    String key,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    try {
      final prefs = await _instance;
      final payload = json.encode({
        'data': data,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'ttl_ms': ttl?.inMilliseconds,
      });
      await prefs.setString(_prefixedKey(key), payload);
    } catch (e) {
      debugPrint('[CacheService] Failed to save "$key": $e');
    }
  }

  /// Load cached data for [key]. Returns null if:
  /// - The key does not exist.
  /// - The cache has expired (TTL exceeded).
  ///
  /// If [ignoreTtl] is true, always returns the entry regardless of TTL.
  static Future<Map<String, dynamic>?> load(
    String key, {
    bool ignoreTtl = false,
  }) async {
    try {
      final prefs = await _instance;
      final raw = prefs.getString(_prefixedKey(key));
      if (raw == null) return null;

      final payload = json.decode(raw) as Map<String, dynamic>;
      final savedAt = payload['saved_at'] as int?;
      final ttlMs = payload['ttl_ms'] as int?;

      if (!ignoreTtl && savedAt != null && ttlMs != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - savedAt;
        if (elapsed > ttlMs) {
          // Expired — clean up and return null
          await prefs.remove(_prefixedKey(key));
          return null;
        }
      }

      return payload['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[CacheService] Failed to load "$key": $e');
      return null;
    }
  }

  /// Check whether a key has unexpired cached data without loading it.
  static Future<bool> has(String key) async {
    final data = await load(key);
    return data != null;
  }

  /// Remove a specific cache entry.
  static Future<void> invalidate(String key) async {
    try {
      final prefs = await _instance;
      await prefs.remove(_prefixedKey(key));
    } catch (e) {
      debugPrint('[CacheService] Failed to invalidate "$key": $e');
    }
  }

  /// Remove all cache entries for a given user prefix (used on logout).
  static Future<void> clearForUser(int userId) async {
    try {
      final prefs = await _instance;
      final keys = prefs.getKeys().where(
        (k) => k.startsWith('${_prefix}_${userId}_'),
      );
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('[CacheService] Failed to clear user cache for $userId: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static const String _prefix = 'ojt_cache';

  static String _prefixedKey(String key) => '${_prefix}_$key';
}

