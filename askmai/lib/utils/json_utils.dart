import 'dart:convert';

Map<String, dynamic>? safeParseJsonResult(dynamic rawResult) {
  if (rawResult is Map) {
    return rawResult.map((k, v) => MapEntry(k.toString(), v));
  }
  if (rawResult is String && rawResult.isNotEmpty) {
    try {
      dynamic parsed = jsonDecode(rawResult);
      if (parsed is String) {
        parsed = jsonDecode(parsed);
      }
      if (parsed is Map) {
        return (parsed).map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
  }
  return null;
}
