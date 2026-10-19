import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'hrms_app_shell.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _rememberMe = true;
  bool _isLoggingIn = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(
    bool dark, {
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.accentText(dark), size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.fieldFill(dark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: AppColors.fieldBorder(dark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.copper, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  Future<void> _submit(bool dark) async {
    FocusScope.of(context).unfocus();
    if (_isLoggingIn || !_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);

    try {
      // Send credentials to the live HRMS API and store the returned tokens.
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HrmsAppShell()),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      _message(message.isEmpty ? 'Login failed. Please try again.' : message);
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false, // Keep the background viewport stable when the keyboard opens.
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(dark),
              _buildOverlay(dark),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 700;
                    final keyboardInset = MediaQuery.of(context)
                        .viewInsets
                        .bottom;
                    return SingleChildScrollView(
                      // Keep the background fixed. Only this content scrolls;
                      // extra bottom space lets focused fields clear the keyboard.
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        21,
                        compact ? 10 : 17,
                        21,
                        16 + keyboardInset,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(dark),
                              SizedBox(height: compact ? 17 : 25),
                              Text(
                                'Welcome back.',
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 31,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Sign in to access your workplace.',
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: compact ? 17 : 23),
                              _buildLoginCard(dark, compact),
                              const SizedBox(height: 13),
                              Center(
                                child: Text(
                                  'PEOPLE  •  PROCESS  •  PROGRESS',
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 9,
                                    letterSpacing: 1.5,
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
            ],
          ),
        );
      },
    );
  }

  // This image is a fixed, full-screen background layer. It is deliberately
  // independent of the scrollable login form and never moves when the keyboard
  // opens or the form scrolls.
  Widget _buildBackground(bool dark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Image.asset(
          dark ? 'assets/hrms_building.png' : 'assets/hrms_building_day.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: dark ? const Color(0xFF171A1A) : const Color(0xFFF1E5D6),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(bool dark) {
    return Positioned.fill(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
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
            stops: const [0, 0.42, 1],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool dark) {
    return Row(
      children: [
        // Use the exact official Etaprise logo in both themes.
        // In dark mode only the dark wordmark is rendered white; the colorful
        // symbol stays unchanged and the PNG background remains transparent.
        SizedBox(
          width: 145,
          height: 48,
          child: Image.asset(
            dark ? 'assets/etaprise_logo_dark.png' : 'assets/etaprise_logo.png',
            width: 145,
            height: 48,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Failed to load Etaprise logo: $error');
              return const SizedBox(width: 145, height: 48);
            },
          ),
        ),
        const Spacer(),
        _headerGlass(
          dark,
          onTap: () => AppColors.isDarkMode.value = !dark,
          child: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: AppColors.accentText(dark),
            size: 20,
          ),
        ),
        const SizedBox(width: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(dark ? 0.075 : 0.34),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.glassBorder(dark)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.accentText(dark),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SECURE',
                    style: TextStyle(
                      color: AppColors.accentText(dark),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerGlass(
    bool dark, {
    required VoidCallback onTap,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(dark ? 0.075 : 0.34),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.glassBorder(dark)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(bool dark, bool compact) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 17 : 20),
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
                      Colors.white.withOpacity(0.68),
                      Colors.white.withOpacity(0.48),
                      const Color(0x55FFF7EB),
                    ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.glassBorder(dark), width: 1.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.22 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 13),
              ),
              BoxShadow(
                color: AppColors.copper.withOpacity(dark ? 0.10 : 0.04),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in',
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Don't have an account yet?",
                  style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterPage(),
                    ),
                  ),
                  child: Text(
                    'Register Now!',
                    style: TextStyle(
                      color: AppColors.accentText(dark),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 16 : 21),
                _label('WORK EMAIL', dark),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _emailController,
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  style: TextStyle(color: AppColors.text(dark), fontSize: 14),
                  cursorColor: AppColors.copper,
                  decoration: _decoration(
                    dark,
                    hint: 'name@company.com',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Please enter your work email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
                      return 'Enter a valid email address';
                    return null;
                  },
                ),
                SizedBox(height: compact ? 13 : 17),
                _label('PASSWORD', dark),
                const SizedBox(height: 7),
                TextFormField(
                  controller: _passwordController,
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(dark),
                  style: TextStyle(color: AppColors.text(dark), fontSize: 14),
                  cursorColor: AppColors.copper,
                  decoration: _decoration(
                    dark,
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.accentText(dark),
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter your password';
                    if (value.length < 6)
                      return 'Password must contain at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    SizedBox(
                      width: 25,
                      height: 36,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: AppColors.copper,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: AppColors.copper.withOpacity(0.72),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Remember me',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentText(dark),
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 14),
                _primaryButton(
                  dark,
                  label: _isLoggingIn ? 'Signing in...' : 'Sign in',
                  isLoading: _isLoggingIn,
                  onPressed: _isLoggingIn ? null : () => _submit(dark),
                ),
                SizedBox(height: compact ? 17 : 21),
                _dividerLabel(dark, 'OR CONTINUE WITH'),
                SizedBox(height: compact ? 13 : 17),
                Row(
                  children: [
                    Expanded(
                      child: _socialButton(
                        dark,
                        'Microsoft',
                        Icons.grid_view_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _socialButton(
                        dark,
                        'Google',
                        Icons.g_mobiledata_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool dark) => Padding(
    padding: const EdgeInsets.only(left: 1),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.accentText(dark),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    ),
  );

  Widget _primaryButton(
    bool dark, {
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? const [Color(0xFFD5B18C), Color(0xFFB98557)]
                : const [Color(0xFFFFD9AB), Color(0xFFD99459)],
          ),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: AppColors.copper.withOpacity(0.16),
              blurRadius: 17,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF18130F),
            disabledForegroundColor: const Color(0xFF18130F),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF18130F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 21),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _dividerLabel(bool dark, String label) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.muted(dark).withOpacity(0.35)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 9,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.muted(dark).withOpacity(0.35)),
        ),
      ],
    );
  }

  Widget _socialButton(bool dark, String label, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: OutlinedButton(
          onPressed: () =>
              _message('$label sign-in is a frontend placeholder.'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text(dark),
            backgroundColor: Colors.white.withOpacity(dark ? 0.045 : 0.30),
            side: BorderSide(color: AppColors.glassBorder(dark)),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.accentText(dark), size: 21),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
