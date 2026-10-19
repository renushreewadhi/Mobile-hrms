import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

/// Pass the `token` query parameter from the password-reset email link.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _message(String value) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final result = await _authService.resetPassword(
        token: widget.token,
        newPassword: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      _message(
        result['message']?.toString() ??
            'Password reset successful. Please sign in.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) => Scaffold(
        backgroundColor: dark ? AppColors.graphite : AppColors.cream,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                dark
                    ? 'assets/hrms_building.png'
                    : 'assets/hrms_building_day.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: dark
                      ? const Color(0xFF171A1A)
                      : const Color(0xFFF1E5D6),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? const [Color(0x5500080C), Color(0x900C0D0C)]
                        : const [Color(0x12FFF8EE), Color(0x55F8F1E7)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xCC17191A)
                                : Colors.white.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.glassBorder(dark),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reset password',
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose a new password for your HRMS account.',
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _hidePassword,
                                  style: TextStyle(color: AppColors.text(dark)),
                                  decoration: _decoration(
                                    dark,
                                    'New password',
                                    Icons.lock_outline,
                                    IconButton(
                                      onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword,
                                      ),
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Enter a new password';
                                    if (v.length < 6)
                                      return 'Use at least 6 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                TextFormField(
                                  controller: _confirmController,
                                  obscureText: _hideConfirm,
                                  style: TextStyle(color: AppColors.text(dark)),
                                  decoration: _decoration(
                                    dark,
                                    'Confirm new password',
                                    Icons.lock_reset,
                                    IconButton(
                                      onPressed: () => setState(
                                        () => _hideConfirm = !_hideConfirm,
                                      ),
                                      icon: Icon(
                                        _hideConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Confirm your new password';
                                    if (v != _passwordController.text)
                                      return 'Passwords do not match';
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _reset(),
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _reset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.copper,
                                      foregroundColor: const Color(0xFF18130F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Update password',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text(
                                      'Back',
                                      style: TextStyle(
                                        color: AppColors.accentText(dark),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(
    bool dark,
    String hint,
    IconData icon,
    Widget suffix,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.accentText(dark)),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.fieldFill(dark),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.fieldBorder(dark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.copper, width: 1.4),
      ),
    );
  }
}
