/// Short-lived in-memory cache so drawer sections can paint last-known data
/// immediately while a background refresh runs.
class SectionDataCache {
  SectionDataCache._();

  static final Map<String, _Entry> _entries = {};

  static const Duration defaultTtl = Duration(minutes: 2);

  static void put(String key, Object data, {Duration ttl = defaultTtl}) {
    _entries[key] = _Entry(data, DateTime.now().add(ttl));
  }

  static T? get<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    final value = entry.data;
    if (value is! T) return null;
    return value as T;
  }

  static void invalidate(String key) => _entries.remove(key);

  static void clear() => _entries.clear();
}

class _Entry {
  final Object data;
  final DateTime expiresAt;
  _Entry(this.data, this.expiresAt);
}
