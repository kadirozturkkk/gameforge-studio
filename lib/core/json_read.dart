import 'errors.dart';

/// Small helpers for reading untrusted JSON with clear errors.
extension JsonRead on Map<String, dynamic> {
  String reqString(String key) {
    final v = this[key];
    if (v is String) return v;
    throw DataFormatException('Field "$key" must be a string');
  }

  String optString(String key, String fallback) {
    final v = this[key];
    return v is String ? v : fallback;
  }

  String? nullableString(String key) {
    final v = this[key];
    return v is String ? v : null;
  }

  double optDouble(String key, double fallback) {
    final v = this[key];
    if (v is num && v.isFinite) return v.toDouble();
    return fallback;
  }

  int optInt(String key, int fallback) {
    final v = this[key];
    return v is num ? v.toInt() : fallback;
  }

  bool optBool(String key, bool fallback) {
    final v = this[key];
    return v is bool ? v : fallback;
  }

  Map<String, dynamic> optMap(String key) {
    final v = this[key];
    return v is Map<String, dynamic> ? v : <String, dynamic>{};
  }

  List<dynamic> optList(String key) {
    final v = this[key];
    return v is List ? v : const [];
  }
}
