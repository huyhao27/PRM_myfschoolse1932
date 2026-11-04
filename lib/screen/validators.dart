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

// Phone-only variant used by the app's login and reset-password screens.
// Returns null when valid: optional leading +, then 9-11 digits.
String? validatePhone(String? value) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return 'Vui lòng nhập số điện thoại';
  }
  if (!RegExp(r'^\+?\d{9,11}$').hasMatch(text)) {
    return 'Số điện thoại không hợp lệ';
  }
  return null;
}
