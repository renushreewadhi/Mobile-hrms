import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isRegistering = false;
  bool _acceptedTerms = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _message(String value) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (_isRegistering || !_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      _message('Please accept the Terms & Conditions to continue.');
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    setState(() => _isRegistering = true);
    try {
      await _authService.register(
        firstName: firstName,
        lastName: lastName,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        // Registration is employee self-signup. These values are defaults
        // for the current API contract; confirm them with the backend team.
        role: 'EMPLOYEE',
        ppt: '',
        department: 'Unassigned',
        designation: 'Employee',
      );
      if (!mounted) return;
      _message(
        'Registration successful. Please sign in with your new account.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _isRegistering = false);
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
                              Color(0x5500080C),
                              Color(0x25060A0A),
                              Color(0x900C0D0C),
                            ]
                          : const [
                              Color(0x12FFF8EE),
                              Color(0x18FFF9F1),
                              Color(0x55F8F1E7),
                            ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 15, 22, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(dark),
                          const SizedBox(height: 24),
                          Text(
                            'Create your account',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Register for access to your workplace.',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _formCard(dark),
                          const SizedBox(height: 14),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Already have an account? Sign in',
                                style: TextStyle(
                                  color: AppColors.accentText(dark),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(bool dark) {
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
        IconButton(
          tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => AppColors.isDarkMode.value = !dark,
          icon: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: AppColors.accentText(dark),
          ),
        ),
      ],
    );
  }

  Widget _formCard(bool dark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(19),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder(dark)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('FIRST NAME', dark),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: AppColors.text(dark)),
                            decoration: _decoration(
                              dark,
                              'First name',
                              Icons.person_outline_rounded,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter first name'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('LAST NAME', dark),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: TextStyle(color: AppColors.text(dark)),
                            decoration: _decoration(
                              dark,
                              'Last name',
                              Icons.person_outline_rounded,
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter last name'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _label('EMAIL ADDRESS', dark),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: AppColors.text(dark)),
                  decoration: _decoration(
                    dark,
                    'you@company.com',
                    Icons.mail_outline_rounded,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Enter your email address';
                    }

                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );

                    if (!emailRegex.hasMatch(email)) {
                      return 'Enter a valid email address';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 15),
                _label('PASSWORD', dark),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: AppColors.text(dark)),
                  decoration: _decoration(
                    dark,
                    'Create a password',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.accentText(dark),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Create a password';
                    if (value.length < 6) return 'Use at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                _label('CONFIRM PASSWORD', dark),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  style: TextStyle(color: AppColors.text(dark)),
                  decoration: _decoration(
                    dark,
                    'Re-enter your password',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () => setState(
                        () => _hideConfirmPassword = !_hideConfirmPassword,
                      ),
                      icon: Icon(
                        _hideConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.accentText(dark),
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Confirm your password';
                    if (value != _passwordController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        onChanged: _isRegistering
                            ? null
                            : (value) => setState(
                                () => _acceptedTerms = value ?? false,
                              ),
                        activeColor: AppColors.copper,
                        side: BorderSide(color: AppColors.fieldBorder(dark)),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isRegistering
                            ? null
                            : () => setState(
                                () => _acceptedTerms = !_acceptedTerms,
                              ),
                        child: Text(
                          'I accept Terms & Conditions',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD9AB), Color(0xFFD99459)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF18130F),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF18130F),
                              ),
                            )
                          : const Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
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

  Widget _label(String text, bool dark) => Text(
    text,
    style: TextStyle(
      color: AppColors.accentText(dark),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );

  InputDecoration _decoration(
    bool dark,
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.accentText(dark), size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.fieldFill(dark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.fieldBorder(dark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.copper, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }
}
