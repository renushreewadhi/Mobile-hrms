import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/notifications_api_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsApiService _api = NotificationsApiService();

  String _filter = 'All';
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getNotifications();
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final title =
              item['title']?.toString() ??
              item['subject']?.toString() ??
              'Notification';
          final message =
              item['message']?.toString() ??
              item['content']?.toString() ??
              item['body']?.toString() ??
              '';
          final category =
              item['category']?.toString() ??
              item['type']?.toString() ??
              'General';
          final isRead = item['isRead'] == true || item['read'] == true;
          final timeStr =
              item['createdAt']?.toString() ?? item['time']?.toString() ?? '';

          parsed.add({
            'id': id,
            'title': title,
            'message': message,
            'category': category,
            'time': _formatTime(timeStr),
            'isRead': isRead,
          });
        }
      }

      setState(() {
        _notifications = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return 'Recently';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllRead();
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark all as read: $e')));
    }
  }

  void _showDetail(Map<String, dynamic> notif) async {
    if (notif['isRead'] == false && notif['id'].toString().isNotEmpty) {
      try {
        await _api.markRead(notif['id'].toString());
        setState(() {
          notif['isRead'] = true;
        });
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppColors.isDarkMode,
          builder: (context, dark, _) {
            return AlertDialog(
              backgroundColor: dark ? AppColors.graphite : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                notif['title'],
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category: ${notif['category']} • ${notif['time']}',
                    style: TextStyle(
                      color: AppColors.accentText(dark),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    notif['message'],
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_filter == 'Unread') return n['isRead'] == false;
      return true;
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildHeader(dark)),
                      TextButton.icon(
                        onPressed: _markAllRead,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text(
                          'Mark All Read',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.copper,
                        ),
                      ),
                    ],
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildFilters(dark),
                  const SizedBox(height: 16),
                  if (!_loading && filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        _filter == 'Unread'
                            ? 'No unread notifications'
                            : 'No notifications found',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        final isRead = notif['isRead'] as bool;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showDetail(notif),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: AppColors.cardDecoration(dark)
                                  .copyWith(
                                    border: Border.all(
                                      color: isRead
                                          ? AppColors.glassBorder(dark)
                                          : AppColors.copper.withValues(
                                              alpha: 0.5,
                                            ),
                                      width: isRead ? 1 : 1.5,
                                    ),
                                  ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? AppColors.fieldFill(dark)
                                          : AppColors.copper.withValues(
                                              alpha: 0.15,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(
                                        notif['category'].toString(),
                                      ),
                                      color: isRead
                                          ? AppColors.muted(dark)
                                          : AppColors.copper,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif['title'],
                                                style: TextStyle(
                                                  color: AppColors.text(dark),
                                                  fontSize: 14,
                                                  fontWeight: isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.copper,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif['message'],
                                          style: TextStyle(
                                            color: AppColors.muted(dark),
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              notif['category'],
                                              style: TextStyle(
                                                color: AppColors.accentText(
                                                  dark,
                                                ),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              notif['time'],
                                              style: TextStyle(
                                                color: AppColors.muted(dark),
                                                fontSize: 10.5,
                                              ),
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
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('leave')) return Icons.event_available_outlined;
    if (cat.contains('pay') || cat.contains('salary'))
      return Icons.payments_outlined;
    if (cat.contains('announc')) return Icons.campaign_outlined;
    if (cat.contains('train') || cat.contains('course'))
      return Icons.school_outlined;
    if (cat.contains('task')) return Icons.task_alt_outlined;
    return Icons.notifications_active_outlined;
  }

  Widget _buildHeader(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Updates and alerts regarding your work activities',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFilters(bool dark) {
    return Row(
      children: ['All', 'Unread'].map((label) {
        final selected = _filter == label;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            selectedColor: AppColors.copper,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.text(dark),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            backgroundColor: AppColors.fieldFill(dark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => setState(() => _filter = label),
          ),
        );
      }).toList(),
    );
  }
}
