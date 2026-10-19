import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/announcements_api_service.dart';
//this is for testing purpose  --- 19 oct
/// Notifications and announcements center for ETAPRISE HRMS.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final TextEditingController _searchController = TextEditingController();
  final AnnouncementsApiService _announcementsApi = AnnouncementsApiService();

  String _activeTab = 'All';
  String _selectedCategoryFilter = 'All';
  List<_NotificationItem> _items = [];
  bool _loading = true;
  String? _error;

  static const filterOptions = [
    'All',
    'Pinned',
    'Festival',
    'Holiday',
    'Event',
    'General',
    'Policy',
    'Training',
    'Emergency',
  ];

  static const Color _orange = Color(0xFFFF8A35);
  static const Color _mutedBlue = Color(0xFF8A9AB7);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });

    try {
      final rawData = await _announcementsApi.getAnnouncements(
        role: 'EMPLOYEE',
      );
      final list = rawData is List
          ? rawData
          : (rawData is Map && rawData['data'] is List
                ? rawData['data'] as List
                : []);

      final parsedItems = list.map((item) {
        final map = item is Map ? Map<String, dynamic>.from(item) : {};
        final title =
            map['title'] ?? map['subject'] ?? map['name'] ?? 'Announcement';
        final message =
            map['content'] ??
            map['message'] ??
            map['description'] ??
            map['summary'] ??
            'No details provided';
        final category = map['category'] ?? map['department'] ?? 'General';
        final type = map['type'] ?? 'Announcements';
        final important =
            map['isImportant'] == true || map['priority'] == 'HIGH';
        final dateStr = map['createdAt'] ?? map['publishedAt'] ?? map['date'];
        final date = dateStr != null
            ? DateTime.tryParse(dateStr.toString()) ?? DateTime.now()
            : DateTime.now();
        final author =
            map['createdByName'] ??
            map['author'] ??
            map['publishedBy'] ??
            'HR Manager';

        return _NotificationItem(
          title: title.toString(),
          message: message.toString(),
          category: category.toString(),
          type: type.toString(),
          important: important,
          date: date,
          time:
              '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}',
          ago: author.toString(),
          icon: Icons.campaign_rounded,
          unread: false,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _items = parsedItems;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int get _announcementCount => _items.length;

  List<_NotificationItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      final matchesSearch =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.message.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);

      bool matchesCategory = true;
      if (_selectedCategoryFilter == 'Pinned') {
        matchesCategory = item.important;
      } else if (_selectedCategoryFilter != 'All') {
        final cat = item.category.toLowerCase();
        final type = item.type.toLowerCase();
        final title = item.title.toLowerCase();
        final target = _selectedCategoryFilter.toLowerCase();
        matchesCategory = cat.contains(target) || type.contains(target) || title.contains(target);
      }

      return matchesSearch && matchesCategory;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _pageHeading(dark),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.muted(dark),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.fieldFill(dark),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.glassBorder(dark)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategoryFilter,
                              isExpanded: true,
                              icon: Icon(Icons.filter_list_rounded, color: AppColors.copper),
                              dropdownColor: dark ? const Color(0xFF1F2223) : Colors.white,
                              style: TextStyle(
                                color: AppColors.text(dark),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              items: filterOptions.map((opt) {
                                return DropdownMenuItem<String>(
                                  value: opt,
                                  child: Row(
                                    children: [
                                      Icon(
                                        opt == 'Pinned'
                                            ? Icons.push_pin_outlined
                                            : Icons.category_outlined,
                                        size: 16,
                                        color: AppColors.copper,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(opt),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategoryFilter = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _searchField(dark),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _activeTab == 'All'
                                    ? 'Recent announcements'
                                    : '$_activeTab announcements',
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${_filteredItems.length} results',
                              style: TextStyle(
                                color: AppColors.muted(dark),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_filteredItems.isEmpty)
                          _emptyState(dark)
                        else
                          ..._filteredItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _notificationCard(item, dark),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'ETAPRISE  •  HRMS',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pageHeading(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Announcements Center',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'View and manage real-time alerts, announcements, and company updates.',
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabs(bool dark) {
    final tabs = <(String, String)>[
      ('All', '(${_items.length})'),
      ('Announcements', '($_announcementCount)'),
    ];
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.map((tab) {
              final selected = _activeTab == tab.$1;
              return InkWell(
                onTap: () => setState(() => _activeTab = tab.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  margin: const EdgeInsets.only(right: 25),
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? AppColors.copper : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    '${tab.$1}${tab.$2}',
                    style: TextStyle(
                      color: selected
                          ? AppColors.accentText(dark)
                          : AppColors.muted(dark),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: dark ? Colors.white12 : const Color(0xFFE0E6EF),
        ),
      ],
    );
  }

  Widget _searchField(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: .045) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0xFFE7ECF3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: AppColors.text(dark), fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search announcements...',
          hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 12),
          border: InputBorder.none,
          icon: Icon(
            Icons.search_rounded,
            color: AppColors.muted(dark),
            size: 19,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.muted(dark),
                    size: 18,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _notificationCard(_NotificationItem item, bool dark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _openDetails(item, dark),
        child: Ink(
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xDD1B1E20)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: .07)
                  : const Color(0xFFE8EDF3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .08 : .035),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: _orange,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 9,
                        runSpacing: 7,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          _pill(
                            item.category,
                            dark
                                ? const Color(0xFF2D3746)
                                : const Color(0xFFF0F4F9),
                            _mutedBlue,
                          ),
                          if (item.important)
                            _pill(
                              'Important',
                              const Color(0xFFFFF0D9),
                              _orange,
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        item.message,
                        style: TextStyle(
                          color: dark
                              ? const Color(0xFFB8C1CE)
                              : const Color(0xFF657A98),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 5,
                        children: [
                          _meta(Icons.person_outline_rounded, item.ago, dark),
                          _meta(
                            Icons.calendar_month_outlined,
                            _formatDate(item.date),
                            dark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _mutedBlue, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: _mutedBlue, fontSize: 10.5)),
      ],
    );
  }

  Widget _emptyState(bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, size: 42, color: AppColors.muted(dark)),
          const SizedBox(height: 12),
          Text(
            'No announcements found',
            style: TextStyle(
              color: AppColors.text(dark),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Check back later for company updates.',
            style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openDetails(_NotificationItem item, bool dark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? const Color(0xFF20262D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted(dark).withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                item.category,
                style: TextStyle(
                  color: AppColors.accentText(dark),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.message,
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: _mutedBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.ago} • ${_formatDate(item.date)}',
                    style: const TextStyle(color: _mutedBlue, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.copper,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _NotificationItem {
  final String title;
  final String message;
  final String category;
  final String type;
  final bool important;
  final DateTime date;
  final String time;
  final String ago;
  final IconData icon;
  bool unread;

  _NotificationItem({
    required this.title,
    required this.message,
    required this.category,
    required this.type,
    required this.important,
    required this.date,
    required this.time,
    required this.ago,
    required this.icon,
    required this.unread,
  });
}
