import 'package:crmx_mobile/core/logging/log_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logging sanitizer masks credentials and phone numbers', () {
    const message = 'phone=+918607385222 otp=123456 '
        'Authorization: Bearer abc.def.ghi '
        'password=database-secret';

    final redacted = LogSanitizer.sanitize(message);

    expect(redacted, isNot(contains('123456')));
    expect(redacted, isNot(contains('database-secret')));
    expect(redacted, isNot(contains('abc.def.ghi')));
    expect(redacted, isNot(contains('8607385222')));
    expect(redacted, contains('[PHONE:******5222]'));
  });

  test('logging sanitizer preserves operational context', () {
    const message = 'api_response method=POST path=/api/auth/verify-otp '
        'status=200 request_id=flutter-123';

    expect(LogSanitizer.sanitize(message), message);
  });
}
