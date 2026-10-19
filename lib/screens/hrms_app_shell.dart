import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'hrms_sidebar.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'punch_in_out_page.dart';
import 'attendance_page.dart';
import 'my_leave_page.dart';
import 'apply_leave_page.dart';
import 'profile_page.dart';
import 'announcements_page.dart';
import 'my_certifications_page.dart';
import 'my_courses_page.dart';
import 'break_tracker_page.dart';
import 'daily_work_update_page.dart';
import 'my_payslips_page.dart';
import 'my_expenses_page.dart';
import 'my_tasks_page.dart';
import 'my_documents_page.dart';
import 'notifications_page.dart';
import 'my_settings_page.dart';

// Persistent mobile app shell.
// The header remains mounted while the nested Navigator replaces
// only the page content below it.
class HrmsAppShell extends StatefulWidget {
  const HrmsAppShell({super.key});

  @override
  State<HrmsAppShell> createState() => _HrmsAppShellState();
}

class _HrmsAppShellState extends State<HrmsAppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  final AuthService _authService = AuthService();

  String _currentPage = 'Dashboard';
  bool _isLoggingOut = false;

  // Clear the authentication session and return to login.
  Future<void> _logout() async {
    if (_isLoggingOut) return;

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

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out. Please try again.')),
      );

      setState(() {
        _isLoggingOut = false;
      });
    }
  }

  void _openPage(String title) {
    // Handle Logout separately from normal page navigation.
    if (title.trim().toLowerCase() == 'logout') {
      Navigator.of(context).maybePop();
      _logout();
      return;
    }

    Widget? page;

    switch (title) {
      case 'Dashboard':
        page = const DashboardPage();
        break;

      case 'Punch In/Out':
        page = const PunchInOutPage();
        break;

      case 'Attendance':
        page = const AttendancePage();
        break;

      case 'Break Tracker':
        page = const BreakTrackerPage();
        break;

      case 'Daily Work Update':
      case 'EOD Updates':
        page = const DailyWorkUpdatePage();
        break;

      case 'Leave Apply':
      case 'Apply Leave':
        page = const ApplyLeavePage();
        break;

      case 'My Leave':
      case 'Leave':
        page = const MyLeavePage();
        break;

      case 'My Payslips & Salary':
      case 'My Payslips':
      case 'Payslips':
      case 'Salary':
        page = const MyPayslipsPage();
        break;

      case 'My Expenses':
      case 'Expenses':
        page = const MyExpensesPage();
        break;

      case 'My Tasks':
      case 'Tasks':
        page = const MyTasksPage();
        break;

      case 'My Documents':
      case 'Documents':
        page = const MyDocumentsPage();
        break;

      case 'Announcements':
        page = const AnnouncementsPage();
        break;

      case 'Notifications':
        page = const NotificationsPage();
        break;

      case 'My Settings':
      case 'Settings':
        page = const MySettingsPage();
        break;

      case 'Profile':
      case 'My Profile':
        page = const ProfilePage();
        break;

      case 'My Certifications':
        page = const MyCertificationsPage();
        break;

      case 'My Courses':
        page = const MyCoursesPage();
        break;

      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title is not connected yet.')));
        return;
    }

    setState(() {
      _currentPage = title;
    });

    // Close the drawer after selecting a page.
    Navigator.of(context).maybePop();

    _navigatorKey.currentState?.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => page!),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          drawer: HrmsSidebar(currentPage: _currentPage, onSelected: _openPage),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildPersistentTopBar(dark),
                Expanded(
                  child: Navigator(
                    key: _navigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => const DashboardPage(),
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

  Widget _buildPersistentTopBar(bool dark) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF111820) : const Color(0xFFF8F7F4))
            .withOpacity(dark ? 0.92 : 0.94),
        border: Border(bottom: BorderSide(color: AppColors.glassBorder(dark))),
      ),
      child: Row(
        children: [
          _topBarButton(
            dark,
            icon: Icons.menu_rounded,
            tooltip: 'Open menu',
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                dark
                    ? 'assets/etaprise_logo_dark.png'
                    : 'assets/etaprise_logo.png',
                width: 126,
                height: 38,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) {
                  return Text(
                    'etaprise',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
          ),
          _topBarButton(
            dark,
            icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
            onTap: () {
              AppColors.isDarkMode.value = !dark;
            },
          ),
          const SizedBox(width: 7),
          _topBarButton(
            dark,
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () => _openPage('Announcements'),
          ),
        ],
      ),
    );
  }

  Widget _topBarButton(
    bool dark, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(dark ? 0.07 : 0.35),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.glassBorder(dark)),
              ),
              child: Tooltip(
                message: tooltip,
                child: Icon(icon, color: AppColors.accentText(dark), size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
