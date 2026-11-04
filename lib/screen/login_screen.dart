import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'fpt_logo.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';
import 'validators.dart';
import 'widgets.dart';

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

  Widget _label(String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm - 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(text, style: context.text.labelLarge)),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.peach, AppColors.surface],
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: Space.xl),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: Space.xl),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // White chip keeps the logo legible on the peach wash.
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Space.lg,
                                        vertical: Space.md),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(Radii.sheet),
                                      border:
                                          Border.all(color: AppColors.line),
                                    ),
                                    child: const FptLogo(height: 44),
                                  ),
                                  const SizedBox(height: Space.md),
                                  Text('MyFSchool',
                                      style: context.text.headlineSmall
                                          ?.copyWith(
                                              color: AppColors.brandStrong,
                                              fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            const SizedBox(height: Space.xl),
                            Semantics(
                              header: true,
                              child: Text('Chào mừng quý phụ huynh',
                                  style: context.text.titleLarge),
                            ),
                            const SizedBox(height: Space.xl),
                            _label('Số điện thoại'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                hintText: '09xxxxxxxx',
                                helperText:
                                    'Số điện thoại đã đăng ký với nhà trường',
                                prefixIcon: ExcludeSemantics(
                                    child:
                                        Icon(Icons.phone_outlined, size: 20)),
                              ),
                              validator: validatePhone,
                            ),
                            const SizedBox(height: Space.md),
                            _label(
                              'Mật khẩu',
                              trailing: TextButton(
                                onPressed:
                                    _loading ? null : _openResetPassword,
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Space.sm)),
                                child: const Text('Quên mật khẩu ?'),
                              ),
                            ),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _logIn(),
                              decoration: InputDecoration(
                                helperText: 'Tối thiểu 6 ký tự',
                                prefixIcon: const ExcludeSemantics(
                                    child:
                                        Icon(Icons.lock_outline, size: 20)),
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.muted,
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
                            const SizedBox(height: Space.sm),
                            CheckboxListTile(
                              value: _remember,
                              onChanged: (v) =>
                                  setState(() => _remember = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              title: Text('Lưu thông tin đăng nhập',
                                  style: context.text.bodyMedium),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: Space.sm),
                              InlineError(_error!,
                                  textKey: const Key('loginError')),
                            ],
                            const SizedBox(height: Space.lg),
                            SizedBox(
                              width: double.infinity,
                              height: Space.minTap,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _logIn,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white),
                                      )
                                    : const Text('Đăng nhập'),
                              ),
                            ),
                            const SizedBox(height: Space.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: Text(
                      'Phiên bản 1.0.0\nCopyright MyFSchool',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
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
