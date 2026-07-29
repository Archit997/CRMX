class LogSanitizer {
  const LogSanitizer._();

  static final _bearerToken = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
  );
  static final _sensitiveValue = RegExp(
    r'''(access[_-]?token|refresh[_-]?token|auth[_-]?token|service[_-]?role[_-]?key|anon[_-]?key|api[_-]?key|password|passwd|secret|otp)(["']?\s*[:=]\s*["']?)([^,\s"'}]+)''',
    caseSensitive: false,
  );
  static final _databasePassword = RegExp(
    r'(postgres(?:ql)?(?:\+\w+)?://[^:\s/]+:)([^@\s/]+)(@)',
    caseSensitive: false,
  );
  static final _indianPhone = RegExp(
    r'(?:\+?91[-\s]?)?([6-9]\d{5})(\d{4})',
  );
  static final _metaToken = RegExp(r'\bEAA[A-Za-z0-9]{20,}\b');

  static String sanitize(Object? value) {
    var result = value?.toString() ?? '';
    result = result.replaceAllMapped(
      _bearerToken,
      (_) => 'Bearer [REDACTED]',
    );
    result = result.replaceAll(_jwt, '[REDACTED_JWT]');
    result = result.replaceAllMapped(
      _sensitiveValue,
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    result = result.replaceAllMapped(
      _databasePassword,
      (match) => '${match.group(1)}[REDACTED]${match.group(3)}',
    );
    result = result.replaceAllMapped(
      _indianPhone,
      (match) => '[PHONE:******${match.group(2)}]',
    );
    return result.replaceAll(_metaToken, '[REDACTED_TOKEN]');
  }
}
