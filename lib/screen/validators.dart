// Các hàm kiểm tra dữ liệu nhập, dùng chung cho Login và Sign Up.
// Trả về null nếu hợp lệ, ngược lại trả về câu báo lỗi.

String? validateEmailOrPhone(String? value) {
  final text = value?.trim() ?? '';

  if (text.isEmpty) {
    return 'Enter your mobile number or email';
  }

  // Số điện thoại: chỉ gồm 9-11 chữ số (có thể bắt đầu bằng +)
  final isPhone = RegExp(r'^\+?\d{9,11}$').hasMatch(text);

  // Email: có dạng ten@ten-mien.duoi
  final isEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(text);

  if (!isPhone && !isEmail) {
    return 'Enter a valid email address or mobile number';
  }
  return null;
}
