// Used by the login and reset-password screens.
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
