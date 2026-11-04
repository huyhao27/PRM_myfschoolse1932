import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'fpt_logo.dart';
import 'validators.dart';
import 'widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  String? _error;
  late final AuthService _auth = widget.authService ?? AuthService();

  @override
  void dispose() {
    _idController.dispose();
    _passController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msg = await _auth.resetPassword(
        _idController.text.trim(),
        _passController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: PageBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FptLogo(height: 32)),
                  const SizedBox(height: Space.xl),
                  TextFormField(
                    controller: _idController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      helperText: 'Số điện thoại đã đăng ký',
                    ),
                    validator: validatePhone,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: _passController,
                    obscureText: _hide,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      helperText: 'At least 6 characters',
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(
                            _hide
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.muted),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _hide,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      helperText: 'Type the same password again',
                    ),
                    validator: (v) => v != _passController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    InlineError(_error!, textKey: const Key('resetError')),
                  ],
                  const SizedBox(height: Space.lg),
                  SizedBox(
                    height: Space.minTap,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Reset password'),
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
