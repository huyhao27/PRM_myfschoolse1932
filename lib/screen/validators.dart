// Returns null when the input is valid, otherwise the error message.
String? validateEmailOrPhone(String? value) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return 'Vui lòng nhập tài khoản';
  }

  // Phone: 9-11 digits, optional leading +
  final isPhone = RegExp(r'^\+?\d{9,11}$').hasMatch(text);

  // Email: name@domain.tld
  final isEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(text);

  if (!isPhone && !isEmail) {
    return 'Tài khoản phải là email hoặc số điện thoại hợp lệ';
  }
  return null;
}
