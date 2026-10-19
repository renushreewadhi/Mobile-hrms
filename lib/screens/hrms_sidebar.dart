import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HrmsSidebar extends StatefulWidget {
  final String currentPage;
  final ValueChanged<String> onSelected;

  const HrmsSidebar({
    super.key,
    required this.currentPage,
    required this.onSelected,
  });

  @override
  State<HrmsSidebar> createState() => _HrmsSidebarState();
}

class _HrmsSidebarState extends State<HrmsSidebar> {
  final ScrollController _menuScrollController = ScrollController();

  String? _expandedGroup;
  String? _selectedGroup;
  late String _selectedItem;

  final List<_SidebarGroup> _groups = const [
    _SidebarGroup(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      items: [
        _SidebarItem(title: 'Dashboard', icon: Icons.space_dashboard_outlined),
      ],
    ),
    _SidebarGroup(
      title: 'My Space',
      icon: Icons.person_outline_rounded,
      items: [
        _SidebarItem(title: 'Profile', icon: Icons.account_circle_outlined),
        _SidebarItem(title: 'Punch In/Out', icon: Icons.touch_app_outlined),
        _SidebarItem(title: 'Attendance', icon: Icons.fact_check_outlined),
        _SidebarItem(
          title: 'Break Tracker',
          icon: Icons.free_breakfast_outlined,
        ),
        _SidebarItem(
          title: 'Daily Work Update',
          icon: Icons.edit_note_outlined,
        ),
      ],
    ),
    _SidebarGroup(
      title: 'Work & Projects',
      icon: Icons.business_center_outlined,
      items: [
        _SidebarItem(title: 'My Tasks', icon: Icons.task_alt_rounded),
        _SidebarItem(title: 'My Documents', icon: Icons.folder_shared_outlined),
      ],
    ),
    _SidebarGroup(
      title: 'Leave Management',
      icon: Icons.event_available_outlined,
      items: [
        _SidebarItem(title: 'Leave Apply', icon: Icons.note_add_outlined),
        _SidebarItem(title: 'My Leave', icon: Icons.beach_access_outlined),
      ],
    ),
    _SidebarGroup(
      title: 'Payroll & Finance',
      icon: Icons.account_balance_wallet_outlined,
      items: [
        _SidebarItem(
          title: 'My Payslips & Salary',
          icon: Icons.payments_outlined,
        ),
        _SidebarItem(title: 'My Expenses', icon: Icons.receipt_long_outlined),
      ],
    ),
    _SidebarGroup(
      title: 'Company & Support',
      icon: Icons.forum_outlined,
      items: [
        _SidebarItem(title: 'Announcements', icon: Icons.campaign_outlined),
        _SidebarItem(
          title: 'Notifications',
          icon: Icons.notifications_none_outlined,
        ),
      ],
    ),
    _SidebarGroup(
      title: 'Training & Learning',
      icon: Icons.school_outlined,
      items: [
        _SidebarItem(title: 'My Courses', icon: Icons.menu_book_outlined),
        _SidebarItem(
          title: 'My Certifications',
          icon: Icons.workspace_premium_outlined,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _selectedItem = widget.currentPage;

    final group = _findGroupForItem(widget.currentPage);
    _selectedGroup = group?.title;
    _expandedGroup = group?.title;
  }

  @override
  void didUpdateWidget(covariant HrmsSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentPage != widget.currentPage) {
      _selectedItem = widget.currentPage;

      final group = _findGroupForItem(widget.currentPage);
      _selectedGroup = group?.title;
      _expandedGroup = group?.title;
    }
  }

  @override
  void dispose() {
    _menuScrollController.dispose();
    super.dispose();
  }

  _SidebarGroup? _findGroupForItem(String itemTitle) {
    for (final group in _groups) {
      for (final item in group.items) {
        if (item.title == itemTitle) {
          return group;
        }
      }
    }

    return null;
  }

  void _selectItem(_SidebarGroup group, _SidebarItem item) {
    setState(() {
      _selectedGroup = group.title;
      _selectedItem = item.title;
      _expandedGroup = group.title;
    });

    // Close the drawer, then delegate EVERY route to the parent app shell.
    // Do not push module pages from the drawer itself: its context belongs to
    // the shell Scaffold, so a direct push can cover the persistent top bar.
    Navigator.of(context).pop();
    widget.onSelected(item.title);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, child) {
        return Drawer(
          width: 300,
          elevation: 12,
          backgroundColor: dark ? AppColors.graphite : AppColors.warmWhite,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fixed header.
                _buildHeader(dark),

                const SizedBox(height: 8),

                // Fixed section label.
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 16, 8),
                  child: _sectionLabel('WORKSPACE', dark),
                ),

                // The menu area gets the remaining height and scrolls.
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const SidebarScrollBehavior(),
                    child: Scrollbar(
                      controller: _menuScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      thickness: 6,
                      radius: const Radius.circular(20),
                      child: ListView(
                        controller: _menuScrollController,
                        primary: false,
                        shrinkWrap: false,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 0, 10, 12),
                        children: [
                          for (final group in _groups)
                            _buildMenuGroup(group, dark),

                          const SizedBox(height: 12),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 12, 8, 8),
                            child: _sectionLabel('PREFERENCES', dark),
                          ),

                          _buildSimpleMenuItem(
                            title: 'My Settings',
                            icon: Icons.tune_outlined,
                            dark: dark,
                          ),

                          const SizedBox(height: 12),

                          Divider(
                            height: 1,
                            thickness: 1,
                            color: _lineColor(dark),
                          ),

                          const SizedBox(height: 8),

                          _buildLogout(dark),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                // Fixed footer; it does not scroll with the menu.
                _buildFooter(dark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool dark) {
    final foreground = AppColors.text(dark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 17, 10, 12),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : AppColors.cream,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _lineColor(dark)),
            ),
            child: Image.asset(
              'assets/etaprise_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.apartment_rounded,
                  color: _accent(dark),
                  size: 28,
                );
              },
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ETAPRISE HRMS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PEOPLE OPERATIONS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Close sidebar',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: AppColors.muted(dark),
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGroup(_SidebarGroup group, bool dark) {
    final isExpanded = _expandedGroup == group.title;
    final isSelectedGroup = _selectedGroup == group.title;
    final foreground = AppColors.text(dark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (_expandedGroup == group.title) {
                    _expandedGroup = null;
                  } else {
                    // Only one module can remain expanded.
                    _expandedGroup = group.title;
                    _selectedGroup = group.title;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelectedGroup || isExpanded
                      ? _selectedBackground(dark)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      group.icon,
                      size: 19,
                      color: isSelectedGroup || isExpanded
                          ? _accent(dark)
                          : AppColors.muted(dark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelectedGroup || isExpanded
                              ? _accent(dark)
                              : foreground,
                          fontSize: 12.5,
                          fontWeight: isSelectedGroup || isExpanded
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 19,
                        color: AppColors.muted(dark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Animated submenu.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 18, top: 4, bottom: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in group.items)
                          _buildSubmenuItem(group, item, dark),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmenuItem(_SidebarGroup group, _SidebarItem item, bool dark) {
    final isSelected =
        _selectedItem == item.title && _selectedGroup == group.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => _selectItem(group, item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            constraints: const BoxConstraints(minHeight: 39),
            padding: const EdgeInsets.only(
              left: 12,
              right: 9,
              top: 9,
              bottom: 9,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? _selectedBackground(dark)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: isSelected ? _accent(dark) : AppColors.muted(dark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? _accent(dark) : AppColors.text(dark),
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3,
                    height: 22,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: _accent(dark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleMenuItem({
    required String title,
    required IconData icon,
    required bool dark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).pop();
            widget.onSelected(title);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: AppColors.muted(dark)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
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

  Widget _buildLogout(bool dark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
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
                    backgroundColor: const Color(0xFFD96859),
                  ),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          );

          if (confirm == true && mounted) {
            Navigator.of(context).pop();
            widget.onSelected('Logout');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 19,
                color: Color(0xFFD96859),
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFD96859),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _lineColor(dark), width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.muted(dark), size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'ETAPRISE  •  HRMS',
              style: TextStyle(
                color: AppColors.muted(dark),
                fontSize: 9.5,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF55B889),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Active',
            style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, bool dark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.muted(dark),
          fontSize: 9.5,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _selectedBackground(bool dark) {
    return dark ? const Color(0xFF352B20) : const Color(0xFFFFEEDC);
  }

  Color _accent(bool dark) {
    return dark ? AppColors.copperLight : const Color(0xFF955426);
  }

  Color _lineColor(bool dark) {
    return dark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE5D8C9);
  }
}

class _SidebarGroup {
  final String title;
  final IconData icon;
  final List<_SidebarItem> items;

  const _SidebarGroup({
    required this.title,
    required this.icon,
    required this.items,
  });
}

class _SidebarItem {
  final String title;
  final IconData icon;

  const _SidebarItem({required this.title, required this.icon});
}

/// Allows mouse, touch, and trackpad dragging in scrollable areas.
class SidebarScrollBehavior extends MaterialScrollBehavior {
  const SidebarScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
