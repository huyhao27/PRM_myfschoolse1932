import 'package:flutter_test/flutter_test.dart';
import 'package:myfschoolse1932/screen/validators.dart';

void main() {
  group('validateEmailOrPhone', () {
    test('empty / null / whitespace-only', () {
      expect(validateEmailOrPhone(''), isNotNull);
      expect(validateEmailOrPhone(null), isNotNull);
      expect(validateEmailOrPhone('   '), isNotNull);
    });
    test('bad email', () {
      expect(validateEmailOrPhone('abc@'), isNotNull);
      expect(validateEmailOrPhone('abc@x'), isNotNull);
    });
    test('bad phone', () {
      expect(validateEmailOrPhone('12345'), isNotNull);
      expect(validateEmailOrPhone('1234567890123'), isNotNull);
    });
    test('valid email', () => expect(validateEmailOrPhone('a.b@x.com'), isNull));
    test('valid phone',
        () => expect(validateEmailOrPhone('0123456789'), isNull));
    test('valid phone with +',
        () => expect(validateEmailOrPhone('+84123456789'), isNull));
    test('surrounding whitespace trimmed', () {
      expect(validateEmailOrPhone('  a@b.com  '), isNull);
      expect(validateEmailOrPhone(' 0123456789 '), isNull);
    });
  });
}
