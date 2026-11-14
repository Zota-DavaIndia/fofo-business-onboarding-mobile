import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/auth/login_id.dart';

void main() {
  test('email addresses are sent as email, lowercased', () {
    final id = LoginId.parse('  Arjun@Example.com ')!;
    expect(id.field, 'email');
    expect(id.value, 'arjun@example.com');
  });

  test('mobile numbers in common formats become 10 digits', () {
    for (final input in ['9845012345', '98450 12345', '+91 98450-12345', '919845012345', '09845012345']) {
      final id = LoginId.parse(input);
      expect(id?.field, 'mobile', reason: input);
      expect(id?.value, '9845012345', reason: input);
    }
  });

  test('anything else is rejected', () {
    for (final input in ['', 'arjun', 'arjun@', '12345', '1845012345', '98450123456', 'a@b']) {
      expect(LoginId.parse(input), isNull, reason: input);
    }
  });
}
