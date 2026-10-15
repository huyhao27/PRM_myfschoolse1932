import 'package:flutter/material.dart';

import 'app_colors.dart';
import '../models/user.dart';
import 'home_screen.dart';
import 'validators.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  String _gender = 'Female';

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _birthdayController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      _birthdayController.text = '$day / $month / ${picked.year}';
    }
  }

  void _signUp() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(user: User(id: 0, name: _emailController.text.trim(), email: _emailController.text.trim(), phone: "", role: "HS")),
        ),
        (route) => false,
      );
    }
  }

  // Shared style for the text fields.
  InputDecoration _inputStyle(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textGray),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  // One selectable gender option.
  Widget _genderBox(String text) {
    final selected = _gender == text;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = text),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.blue : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: selected ? AppColors.blue : AppColors.textDark,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "It's quick and easy.",
                  style: TextStyle(fontSize: 14, color: AppColors.textGray),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.divider),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: _inputStyle('First name'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _surnameController,
                        decoration: _inputStyle('Surname'),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _birthdayController,
                  readOnly: true,
                  onTap: _pickBirthday,
                  decoration: _inputStyle(
                    'Birthday',
                    suffix: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                      color: AppColors.textGray,
                    ),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),

                const Text(
                  'Gender',
                  style: TextStyle(fontSize: 13, color: AppColors.textGray),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _genderBox('Female'),
                    const SizedBox(width: 10),
                    _genderBox('Male'),
                    const SizedBox(width: 10),
                    _genderBox('Custom'),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputStyle('Mobile number or email address'),
                  validator: validateEmailOrPhone,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  decoration: _inputStyle(
                    'New password',
                    suffix: TextButton(
                      onPressed: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                      child: Text(
                        _hidePassword ? 'Show' : 'Hide',
                        style: const TextStyle(color: AppColors.textGray),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'By tapping Sign Up, you agree to our Terms, Privacy '
                  'Policy and Cookies Policy.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Sign Up',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'I already have an account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
