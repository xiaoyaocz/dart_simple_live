class HttpLogSanitizer {
  const HttpLogSanitizer._();

  static final RegExp _sensitiveTextPattern = RegExp(
    r'(password|secret|token|session|csrf|signature|a[_-]?bogus|ttwid|sid[_-]?guard)\s*[:=]\s*([^;,\s&]+)',
    caseSensitive: false,
  );

  static final RegExp _credentialLinePattern = RegExp(
    r'(cookie|authorization)\s*[:=]\s*[^\r\n]+',
    caseSensitive: false,
  );

  static bool isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    return normalized.contains('cookie') ||
        normalized.contains('authorization') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('session') ||
        normalized.contains('csrf') ||
        normalized.contains('signature') ||
        normalized == 'ttwid' ||
        normalized == 'abogus' ||
        normalized == 'sidguard';
  }

  static dynamic redact(dynamic value, {String? key}) {
    if (key != null && isSensitiveKey(key)) {
      return '<redacted>';
    }
    if (value is Map) {
      return value.map(
        (mapKey, mapValue) =>
            MapEntry(mapKey, redact(mapValue, key: mapKey.toString())),
      );
    }
    if (value is Iterable) {
      return value.map((item) => redact(item)).toList(growable: false);
    }
    if (value is String) {
      return redactText(value);
    }
    return value;
  }

  static String redactUri(Uri uri) {
    final query = <String, dynamic>{...uri.queryParameters};
    for (final key in query.keys.toList()) {
      if (isSensitiveKey(key)) {
        query[key] = '<redacted>';
      }
    }
    return uri.replace(queryParameters: query).toString();
  }

  static String redactText(String? value, {Uri? requestUri}) {
    var result = value ?? '';
    if (requestUri != null) {
      result = result.replaceAll(requestUri.toString(), redactUri(requestUri));
    }
    result = result.replaceAllMapped(
      _credentialLinePattern,
      (match) => '${match.group(1)}=<redacted>',
    );
    return result.replaceAllMapped(
      _sensitiveTextPattern,
      (match) => '${match.group(1)}=<redacted>',
    );
  }
}
