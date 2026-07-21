/// Small defensive helpers for parsing loosely-typed JSON from the backend.
library;

String? asStringOrNull(dynamic v) => v?.toString();

String asString(dynamic v, {String fallback = ''}) => v?.toString() ?? fallback;

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

int asInt(dynamic v, {int fallback = 0}) => asIntOrNull(v) ?? fallback;

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

DateTime? asDateTimeOrNull(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString())?.toLocal();
}

List<T> asList<T>(dynamic v, T Function(dynamic) mapper) {
  if (v is! List) return const [];
  return v.map(mapper).toList();
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return const {};
}
