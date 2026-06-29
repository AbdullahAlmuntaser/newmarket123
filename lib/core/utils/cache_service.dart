import 'dart:async';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _cache = {};
  static const Duration defaultTtl = Duration(minutes: 5);

  Future<T?> get<T>(String key) async {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  void clearByPrefix(String prefix) {
    final keysToRemove =
        _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }

  T? getSync<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T?;
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiry;

  _CacheEntry({required this.value, required this.expiry});
}
