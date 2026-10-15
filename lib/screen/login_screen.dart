import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_colors.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';
import 'validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  /// Injectable for tests; defaults to a real AuthService.
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _remember = true;
  bool _loading = false;
  String? _error;
  late final AuthService _auth = widget.authService ?? AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Validates, calls the backend, and goes home on success.
  Future<void> _logIn() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _vietnamese(e.message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  // Backend messages are English; show the known ones in Vietnamese.
  String _vietnamese(String message) {
    const known = {
      'Invalid credentials': 'Sai tài khoản hoặc mật khẩu',
    };
    return known[message] ?? message;
  }

  void _openResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(authService: widget.authService),
      ),
    );
  }

  // Shared style for the text fields (orange outline, rounded).
  InputDecoration _inputStyle({Widget? suffix}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.orange, 1.5),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red, 1.5),
    );
  }

  Widget _label(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.peach, Colors.white],
            stops: [0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),
                            const Text(
                              'MyFSchool',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.orange,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Chào mừng quý phụ huynh',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _label('Tài khoản'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputStyle(),
                              validator: validateEmailOrPhone,
                            ),
                            const SizedBox(height: 16),

                            _label(
                              'Mật khẩu',
                              trailing: GestureDetector(
                                onTap: _loading ? null : _openResetPassword,
                                child: const Text(
                                  'Quên mật khẩu ?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ),
                            ),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _logIn(),
                              decoration: _inputStyle(
                                suffix: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textGray,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _hidePassword = !_hidePassword),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return 'Mật khẩu tối thiểu 6 ký tự';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            InkWell(
                              onTap: () =>
                                  setState(() => _remember = !_remember),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Checkbox(
                                      value: _remember,
                                      activeColor: AppColors.orange,
                                      onChanged: (v) => setState(
                                          () => _remember = v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Lưu thông tin đăng nhập',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  _error!,
                                  key: const Key('loginError'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 14),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _logIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      AppColors.orange.withValues(alpha: 0.7),
                                  disabledForegroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'Đăng nhập',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: const [
                                Expanded(
                                    child: Divider(color: AppColors.divider)),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Hoặc đăng nhập bằng',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textGray),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: AppColors.divider)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Đăng nhập bằng FEID chưa được hỗ trợ'),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: AppColors.orangeSoft,
                                  foregroundColor: AppColors.orange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'FEID',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Phiên bản 1.0.0\nCopyright MyFSchool',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
