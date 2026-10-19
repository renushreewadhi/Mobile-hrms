import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _message(String message) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();
    if (_isSending || !_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    try {
      final response = await _authService.forgotPassword(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _message(
        response['message']?.toString() ??
            'If the email exists, a password reset link has been sent.',
      );
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  dark
                      ? 'assets/hrms_building.png'
                      : 'assets/hrms_building_day.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
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
                          ? const [
                              Color(0x4500080C),
                              Color(0x20060A0A),
                              Color(0x550C0D0C),
                            ]
                          : const [
                              Color(0x08FFF8EE),
                              Color(0x10FFF9F1),
                              Color(0x35F8F1E7),
                            ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 650;
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          22,
                          compact ? 10 : 20,
                          22,
                          20,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(dark),
                                SizedBox(height: compact ? 28 : 44),
                                Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontSize: 29,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Enter your work email to get back into your account.',
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 13,
                                    height: 1.65,
                                  ),
                                ),
                                SizedBox(height: compact ? 22 : 30),
                                _buildCard(dark, compact),
                                const SizedBox(height: 20),
                                Center(
                                  child: Text(
                                    'PEOPLE  •  PROCESS  •  PROGRESS',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 9,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool dark) {
    return Row(
      children: [
        SizedBox(
          width: 43,
          height: 43,
          child: Image.asset(
            'assets/etaprise_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.business_rounded,
              color: AppColors.accentText(dark),
              size: 29,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HRMS',
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'PEOPLE OPERATIONS',
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 8,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        _glassIcon(
          dark,
          dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          () => AppColors.isDarkMode.value = !dark,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(dark ? 0.07 : 0.48),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.glassBorder(dark)),
          ),
          child: Icon(
            Icons.shield_outlined,
            color: AppColors.accentText(dark),
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _glassIcon(bool dark, IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(dark ? 0.075 : 0.38),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.glassBorder(dark)),
              ),
              child: Icon(icon, color: AppColors.accentText(dark), size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(bool dark, bool compact) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 18 : 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      Colors.white.withOpacity(0.13),
                      const Color(0x4017191A),
                      const Color(0x2217191A),
                    ]
                  : [
                      Colors.white.withOpacity(0.72),
                      Colors.white.withOpacity(0.49),
                      const Color(0x55FFF7EB),
                    ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.glassBorder(dark), width: 1.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.22 : 0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: AppColors.copper.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: AppColors.copper.withOpacity(0.42),
                        ),
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.accentText(dark),
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reset your password',
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                Text(
                  'WORK EMAIL',
                  style: TextStyle(
                    color: AppColors.accentText(dark),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 9),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _sendResetLink(),
                  style: TextStyle(color: AppColors.text(dark), fontSize: 14),
                  cursorColor: AppColors.copper,
                  decoration: InputDecoration(
                    hintText: 'name@company.com',
                    hintStyle: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.accentText(dark),
                      size: 21,
                    ),
                    filled: true,
                    fillColor: AppColors.fieldFill(dark),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: AppColors.fieldBorder(dark),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: AppColors.copper,
                        width: 1.4,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.4,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Please enter your work email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
                      return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Use the email associated with your employee account.',
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 23),
                _primaryButton(
                  dark,
                  _isSending ? 'Sending...' : 'Send reset link',
                  _isSending ? null : _sendResetLink,
                ),
                const SizedBox(height: 15),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.accentText(dark),
                      size: 17,
                    ),
                    label: Text(
                      'Back to Sign in',
                      style: TextStyle(
                        color: AppColors.accentText(dark),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(bool dark, String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD9AB), Color(0xFFD99459)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF18130F),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
