import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/user_settings_api_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class MySettingsPage extends StatefulWidget {
  const MySettingsPage({super.key});

  @override
  State<MySettingsPage> createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  final UserSettingsApiService _settingsApi = UserSettingsApiService();
  final AuthService _authService = AuthService();

  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _biometricLogin = true;
  bool _twoFactorAuth = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _settingsApi.getSummary();
      if (!mounted || summary.isEmpty) return;
      setState(() {
        if (summary.containsKey('pushNotifications')) {
          _pushNotifications = summary['pushNotifications'] == true;
        }
        if (summary.containsKey('emailAlerts')) {
          _emailAlerts = summary['emailAlerts'] == true;
        }
        if (summary.containsKey('twoFactorEnabled')) {
          _twoFactorAuth = summary['twoFactorEnabled'] == true;
        }
      });
    } catch (_) {}
  }

  void _openChangePasswordModal() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ValueListenableBuilder<bool>(
              valueListenable: AppColors.isDarkMode,
              builder: (context, dark, _) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.graphite : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.muted(dark)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Change Password',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: currentPassController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Current Password *',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: newPassController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'New Password *',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: confirmPassController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password *',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      final current = currentPassController.text
                                          .trim();
                                      final newPass = newPassController.text
                                          .trim();
                                      final confirm = confirmPassController.text
                                          .trim();

                                      if (current.isEmpty || newPass.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please fill all required fields',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (newPass != confirm) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'New passwords do not match',
                                                ),
                                              ),
                                            );
                                        return;
                                      }

                                      setModalState(() => submitting = true);

                                      try {
                                        await _settingsApi.changePassword(
                                          current,
                                          newPass,
                                        );
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Password updated successfully',
                                              ),
                                              backgroundColor: Color(
                                                0xFF2E7D32,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => submitting = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed: $e'),
                                                ),
                                              );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.copper,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final dark = AppColors.isDarkMode.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? AppColors.graphite : Colors.white,
        title: Text(
          'Confirm Logout',
          style: TextStyle(
            color: AppColors.text(dark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(
            color: AppColors.muted(dark),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authService.logout();
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Logged out locally.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(dark),
                const SizedBox(height: 16),
                _buildSectionHeader(dark, 'Account Security'),
                const SizedBox(height: 10),
                Container(
                  decoration: AppColors.cardDecoration(dark),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.copper,
                        ),
                        title: Text(
                          'Change Account Password',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _openChangePasswordModal,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _biometricLogin,
                        onChanged: (val) =>
                            setState(() => _biometricLogin = val),
                        activeColor: AppColors.copper,
                        title: Text(
                          'Biometric Login (Face / Fingerprint)',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Use device biometrics for quick authentication',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _twoFactorAuth,
                        onChanged: (val) =>
                            setState(() => _twoFactorAuth = val),
                        activeColor: AppColors.copper,
                        title: Text(
                          'Two-Factor Authentication (2FA)',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Require OTP on new device sign-in',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader(dark, 'Notifications & Preferences'),
                const SizedBox(height: 10),
                Container(
                  decoration: AppColors.cardDecoration(dark),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _pushNotifications,
                        onChanged: (val) =>
                            setState(() => _pushNotifications = val),
                        activeColor: AppColors.copper,
                        title: Text(
                          'Push Notifications',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Receive instant mobile alerts for leave and approvals',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _emailAlerts,
                        onChanged: (val) => setState(() => _emailAlerts = val),
                        activeColor: AppColors.copper,
                        title: Text(
                          'Email Digest & Alerts',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Send monthly payslip and company announcement emails',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionHeader(dark, 'App Session & Logout'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Log Out of Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings & Security',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage password, authentication security, and app preferences',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(bool dark, String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.text(dark),
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
