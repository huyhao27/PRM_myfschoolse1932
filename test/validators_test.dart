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

  group('validatePhone', () {
    test('empty / null / whitespace-only', () {
      expect(validatePhone(''), 'Vui lòng nhập số điện thoại');
      expect(validatePhone(null), 'Vui lòng nhập số điện thoại');
      expect(validatePhone('   '), 'Vui lòng nhập số điện thoại');
    });
    test('rejects email, letters, too short/long', () {
      for (final v in ['a@b.com', '12345', '1234567890123', '09012abc45']) {
        expect(validatePhone(v), 'Số điện thoại không hợp lệ');
      }
    });
    test('valid phones', () {
      expect(validatePhone('0901000001'), isNull);
      expect(validatePhone('+84901000001'), isNull);
      expect(validatePhone(' 0901234567 '), isNull);
    });
  });
}
