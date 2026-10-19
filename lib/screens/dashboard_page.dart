import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/api_client.dart';
import '../services/attendance_api_service.dart';
import '../services/leave_api_service.dart';
import '../services/announcements_api_service.dart';
import '../services/profile_api_service.dart';
import '../services/tasks_api_service.dart';
import '../services/performance_api_service.dart';
import 'attendance_page.dart';
import 'my_leave_page.dart';
import 'apply_leave_page.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _attendanceApi = AttendanceApiService();
  final _leaveApi = LeaveApiService();
  final _announcementsApi = AnnouncementsApiService();
  final _profileApi = ProfileApiService();
  final _tasksApi = TasksApiService();
  final _performanceApi = PerformanceApiService();

  String _employeeName = 'Employee';
  Map<String, dynamic> _today = {};
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic> _performanceData = {};
  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });

    Map<String, dynamic> profile = {};
    try {
      profile = await _profileApi.getMyProfile();
    } catch (_) {}

    final employeeId = ProfileApiService.extractEmployeeId(profile) ?? '';
    final name =
        profile['firstName'] ??
        profile['employeeName'] ??
        profile['fullName'] ??
        profile['name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      _employeeName = name.toString().trim();
    }

    final startDateStr = DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .split('T')[0];
    final endDateStr = DateTime.now().toIso8601String().split('T')[0];

    final results = await Future.wait<Object?>([
      _safe(() => _attendanceApi.getTodayAttendance()),
      _safe(
        () => employeeId.isNotEmpty
            ? _attendanceApi.getEmployeeAttendance(
                employeeId,
                startDate: startDateStr,
                endDate: endDateStr,
              )
            : _attendanceApi.getAttendanceHistory(
                startDate: startDateStr,
                endDate: endDateStr,
              ),
      ),
      _safe(() => _leaveApi.getLeaveBalances(employeeId: employeeId)),
      _safe(() => _leaveApi.getMyLeaveRequests(employeeId: employeeId)),
      _safe(() => _leaveApi.getHolidays()),
      _safe(() => _fetchTasks(employeeId)),
      _safe(() => _fetchPerformance(employeeId)),
      _safe(() => _announcementsApi.getAnnouncements(role: 'EMPLOYEE')),
    ]);

    if (!mounted) return;
    setState(() {
      _today = _asMap(results[0]);
      _attendance = _asList(results[1]);
      _balances = _asList(results[2]);
      _leaveRequests = _asList(results[3]);
      _holidays = _asList(results[4]);
      _tasks = _asList(results[5]);
      _performanceData = _asMap(results[6]);
      _announcements = _asList(results[7]);
      _loading = false;
      if (results.every((e) => e == null)) {
        _error = 'Could not load your dashboard. Pull down to retry.';
      }
    });
  }

  Future<Object?> _fetchTasks(String employeeId) async {
    try {
      return await _tasksApi.getMyTasks(employeeId: employeeId);
    } catch (_) {
      return [];
    }
  }

  Future<Object?> _fetchPerformance(String employeeId) async {
    try {
      return await _performanceApi.getDashboard();
    } catch (_) {
      return {};
    }
  }

  Future<Object?> _safe(Future<Object?> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    final unwrapped = ApiClient.unwrap(value);
    if (unwrapped is Map) return Map<String, dynamic>.from(unwrapped);
    return {};
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    final unwrapped = ApiClient.unwrap(value);
    if (unwrapped is List) {
      return unwrapped
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  dynamic _field(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key) &&
          map[key] != null &&
          map[key].toString().trim().isNotEmpty) {
        return map[key];
      }
    }
    return null;
  }

  String _text(dynamic value, [String fallback = '—']) =>
      value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString();

  String _greeting() {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return '$timeGreeting, $_employeeName';
  }

  String _dateLabel(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTimeString(dynamic isoStr) {
    if (isoStr == null || isoStr.toString().trim().isEmpty) return '—';
    final str = isoStr.toString().trim();
    if (str.contains('AM') || str.contains('PM')) return str;
    try {
      final dt = DateTime.parse(str).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:$minute $amPm';
    } catch (_) {
      if (str.contains('T')) {
        final timePart = str.split('T').last;
        return timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
      }
      return str;
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _balanceValue(Map<String, dynamic> item, List<String> keys) =>
      _number(_field(item, keys));
  double get _remainingLeave => _balances.fold<double>(
    0,
    (sum, item) =>
        sum +
        _balanceValue(item, [
          'remaining',
          'remainingDays',
          'available',
          'balance',
          'availableBalance',
        ]),
  );
  double get _usedLeave => _balances.fold<double>(
    0,
    (sum, item) =>
        sum + _balanceValue(item, ['used', 'usedDays', 'taken', 'consumed']),
  );
  double get _totalLeave => _balances.fold<double>(
    0,
    (sum, item) =>
        sum +
        _balanceValue(item, [
          'total',
          'totalDays',
          'entitled',
          'allocated',
          'annualQuota',
        ]),
  );

  int get _completedTasks {
    final perfVal = _field(_performanceData, [
      'completedTasks',
      'completed',
      'completedCount',
    ]);
    if (perfVal != null) return _number(perfVal).toInt();
    return _tasks.where((t) {
      final s = _text(
        _field(t, ['status', 'taskStatus', 'state']),
        '',
      ).toLowerCase();
      return s.contains('complete') || s == 'done' || s == 'closed';
    }).length;
  }

  int get _inProgressTasks {
    final perfVal = _field(_performanceData, [
      'inProgressTasks',
      'inProgress',
      'inProgressCount',
    ]);
    if (perfVal != null) return _number(perfVal).toInt();
    return _tasks.where((t) {
      final s = _text(
        _field(t, ['status', 'taskStatus', 'state']),
        '',
      ).toLowerCase();
      return s.contains('progress') || s == 'doing' || s == 'working';
    }).length;
  }

  int get _pendingTasks {
    final perfVal = _field(_performanceData, [
      'pendingTasks',
      'pending',
      'pendingCount',
      'openTasks',
    ]);
    if (perfVal != null) return _number(perfVal).toInt();
    final count = _tasks.where((t) {
      final s = _text(
        _field(t, ['status', 'taskStatus', 'state']),
        '',
      ).toLowerCase();
      return s.contains('pend') || s == 'open' || s == 'todo' || s == 'new';
    }).length;
    if (count == 0 && _tasks.isNotEmpty) {
      final nonCompleted = _tasks.length - _completedTasks;
      return nonCompleted > 0 ? nonCompleted : 0;
    }
    return count;
  }

  int get _totalTasks {
    final perfVal = _field(_performanceData, ['totalTasks', 'total']);
    if (perfVal != null) return _number(perfVal).toInt();
    return _completedTasks + _inProgressTasks + _pendingTasks;
  }

  int get _productivityPercentage {
    final perfVal = _field(_performanceData, [
      'productivity',
      'productivityPercentage',
      'performance',
    ]);
    if (perfVal != null) return _number(perfVal).round();
    if (_totalTasks > 0) {
      return ((_completedTasks / _totalTasks) * 100).round();
    }
    return 0;
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) => Scaffold(
        backgroundColor: dark ? AppColors.graphite : const Color(0xFFF5F7FB),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your workday at a glance',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateTime.now().weekday == 1
                                ? 'Monday'
                                : DateTime.now().weekday == 2
                                ? 'Tuesday'
                                : DateTime.now().weekday == 3
                                ? 'Wednesday'
                                : DateTime.now().weekday == 4
                                ? 'Thursday'
                                : DateTime.now().weekday == 5
                                ? 'Friday'
                                : DateTime.now().weekday == 6
                                ? 'Saturday'
                                : 'Sunday'}, ${_dateLabel(DateTime.now())}',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: dark
                          ? 'Switch to light mode'
                          : 'Switch to dark mode',
                      onPressed: () => AppColors.isDarkMode.value = !dark,
                      icon: Icon(
                        dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.accentText(dark),
                      ),
                    ),
                  ],
                ),
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
                const SizedBox(height: 18),
                _summaryGrid(dark),
                const SizedBox(height: 24),
                _sectionTitle(
                  dark,
                  'My Attendance',
                  'View details',
                  () => _open(const AttendancePage()),
                ),
                const SizedBox(height: 10),
                _attendanceCard(dark),
                const SizedBox(height: 22),
                _sectionTitle(
                  dark,
                  'My Leave Summary',
                  'View leave',
                  () => _open(const MyLeavePage()),
                ),
                const SizedBox(height: 10),
                _leaveSummary(dark),
                const SizedBox(height: 22),
                _sectionTitle(
                  dark,
                  'Leave Balance',
                  'All leave types',
                  () => _open(const MyLeavePage()),
                ),
                const SizedBox(height: 10),
                _leaveBalanceCards(dark),
                const SizedBox(height: 22),
                _sectionTitle(
                  dark,
                  'My Work Performance',
                  'Based on my tasks',
                  null,
                ),
                const SizedBox(height: 10),
                _performance(dark),
                const SizedBox(height: 22),
                _sectionTitle(
                  dark,
                  'Upcoming Holidays',
                  'Company holidays',
                  null,
                ),
                const SizedBox(height: 10),
                _dataList(
                  dark,
                  _holidays,
                  titleKeys: ['name', 'holidayName', 'title'],
                  subtitleKeys: ['date', 'holidayDate', 'type'],
                  icon: Icons.event_rounded,
                  empty: 'No holiday information available.',
                ),
                const SizedBox(height: 22),
                _sectionTitle(dark, 'Recent Tasks', 'My tasks', null),
                const SizedBox(height: 10),
                _dataList(
                  dark,
                  _tasks,
                  titleKeys: ['title', 'taskName', 'name'],
                  subtitleKeys: ['status', 'taskStatus', 'dueDate'],
                  icon: Icons.task_alt_rounded,
                  empty: 'No tasks available.',
                ),
                const SizedBox(height: 22),
                _sectionTitle(
                  dark,
                  'My Requests',
                  'View all',
                  () => _open(const MyLeavePage()),
                ),
                const SizedBox(height: 10),
                _dataList(
                  dark,
                  _leaveRequests,
                  titleKeys: ['leaveType', 'type', 'title'],
                  subtitleKeys: ['startDate', 'fromDate', 'createdAt'],
                  icon: Icons.work_outline_rounded,
                  statusKeys: ['status', 'leaveStatus'],
                  empty: 'No leave requests found.',
                ),
                const SizedBox(height: 22),
                _sectionTitle(dark, 'Quick Actions', 'Shortcuts', null),
                const SizedBox(height: 10),
                _quickActions(dark),
                const SizedBox(height: 22),
                _sectionTitle(
                  dark,
                  'Recent Announcements',
                  'Company updates',
                  null,
                ),
                const SizedBox(height: 10),
                _dataList(
                  dark,
                  _announcements,
                  titleKeys: ['title', 'subject', 'name'],
                  subtitleKeys: ['createdAt', 'publishedAt', 'type'],
                  icon: Icons.campaign_rounded,
                  empty: 'No announcements available.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryGrid(bool dark) {
    final checkInFormatted = _formatTimeString(
      _field(_today, ['checkInTime', 'clockIn', 'checkIn']),
    );
    final todayStatus = _field(_today, [
      'status',
      'attendanceStatus',
    ])?.toString();
    final checkInValue = checkInFormatted != '—'
        ? checkInFormatted
        : (todayStatus ?? (_loading ? 'Loading…' : 'Not checked in'));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _summaryTile(
          dark,
          'Check-in today',
          checkInValue,
          'Attendance',
          const Color(0xFF08A879),
          Icons.event_available_rounded,
        ),
        _summaryTile(
          dark,
          'Leave balance',
          _totalLeave > 0 || _remainingLeave > 0
              ? '${_remainingLeave.toStringAsFixed(_remainingLeave % 1 == 0 ? 0 : 1)} days'
              : (_loading ? 'Loading…' : '—'),
          'Days remaining',
          const Color(0xFF5978F5),
          Icons.beach_access_rounded,
        ),
        _summaryTile(
          dark,
          'My Tasks',
          _loading
              ? 'Loading…'
              : '${_pendingTasks > 0 ? _pendingTasks : (_tasks.isNotEmpty ? _tasks.length : 0)}',
          'Pending',
          const Color(0xFF6554E8),
          Icons.checklist_rounded,
        ),
        _summaryTile(
          dark,
          'Announcements',
          _loading ? 'Loading…' : '${_announcements.length}',
          'Company updates',
          const Color(0xFFE88736),
          Icons.campaign_rounded,
        ),
      ],
    );
  }

  Widget _summaryTile(
    bool dark,
    String title,
    String value,
    String detail,
    Color tint,
    IconData icon,
  ) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF202326) : Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.glassBorder(dark)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: tint, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted(dark), fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(
    bool dark,
    String title,
    String trailing,
    VoidCallback? onTap,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (onTap != null)
        TextButton(
          onPressed: onTap,
          child: Text(
            trailing,
            style: TextStyle(
              color: AppColors.accentText(dark),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        )
      else
        Text(
          trailing,
          style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
        ),
    ],
  );

  Widget _panel(bool dark, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF202326) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.glassBorder(dark)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .08 : .025),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );

  Widget _attendanceCard(bool dark) => _panel(
    dark,
    _attendance.isEmpty
        ? Text(
            _loading
                ? 'Loading attendance…'
                : 'No attendance records available.',
            style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
          )
        : Column(
            children: _attendance.take(7).map((item) {
              final rawDate = _field(item, [
                'date',
                'attendanceDate',
                'workDate',
              ]);
              final dateStr = rawDate != null
                  ? rawDate.toString().split('T')[0]
                  : 'Date unavailable';
              final status = _text(
                _field(item, ['status', 'attendanceStatus']),
                'PRESENT',
              );
              final checkIn = _formatTimeString(
                _field(item, ['checkInTime', 'clockIn', 'checkIn']),
              );
              final checkOut = _formatTimeString(
                _field(item, ['checkOutTime', 'clockOut', 'checkOut']),
              );
              final statusColor = status.toUpperCase() == 'PRESENT'
                  ? const Color(0xFF08A879)
                  : status.toUpperCase() == 'LATE'
                  ? const Color(0xFFE9A23B)
                  : const Color(0xFFE85D5D);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$checkIn  –  $checkOut',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
  );

  Widget _leaveSummary(bool dark) => _panel(
    dark,
    Row(
      children: [
        Expanded(child: _leaveMetric(dark, 'Total', _totalLeave)),
        Expanded(child: _leaveMetric(dark, 'Used', _usedLeave)),
        Expanded(child: _leaveMetric(dark, 'Remaining', _remainingLeave)),
      ],
    ),
  );
  Widget _leaveMetric(bool dark, String label, double value) => Column(
    children: [
      Text(
        '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} days',
        style: TextStyle(
          color: AppColors.text(dark),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: AppColors.muted(dark), fontSize: 10)),
    ],
  );

  Widget _leaveBalanceCards(bool dark) {
    if (_balances.isEmpty)
      return _panel(
        dark,
        Text(
          _loading
              ? 'Loading leave balances…'
              : 'Leave balance details are not available.',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
        ),
      );
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _balances.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = _balances[index];
        final name = _text(
          _field(item, ['leaveTypeName', 'leaveType', 'type', 'name']),
          'Leave',
        );
        final remaining = _balanceValue(item, [
          'remaining',
          'remainingDays',
          'available',
          'balance',
          'availableBalance',
        ]);
        final total = _balanceValue(item, [
          'total',
          'totalDays',
          'entitled',
          'allocated',
          'annualQuota',
        ]);
        final color = [
          const Color(0xFFE9A23B),
          const Color(0xFFE85D5D),
          const Color(0xFF08A879),
          const Color(0xFF6554E8),
        ][index % 4];
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? .13 : .09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${remaining.toStringAsFixed(remaining % 1 == 0 ? 0 : 1)} days',
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Available${total > 0 ? ' / ${total.toStringAsFixed(total % 1 == 0 ? 0 : 1)}' : ''}',
                style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _performance(bool dark) {
    final completed = _completedTasks;
    final inProgress = _inProgressTasks;
    final pending = _pendingTasks;
    final productivity = _productivityPercentage;

    return _panel(
      dark,
      Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (productivity / 100).clamp(0.0, 1.0),
                    strokeWidth: 9,
                    backgroundColor: dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E6EC),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF08A879),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$productivity%',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Productivity',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _perfLegendRow(
                  dark,
                  const Color(0xFF08A879),
                  '$completed',
                  'Tasks Completed',
                ),
                const SizedBox(height: 10),
                _perfLegendRow(
                  dark,
                  const Color(0xFF5978F5),
                  '$inProgress',
                  'In Progress',
                ),
                const SizedBox(height: 10),
                _perfLegendRow(
                  dark,
                  const Color(0xFFE85D5D),
                  '$pending',
                  'Pending',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _perfLegendRow(bool dark, Color color, String count, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          count,
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dataList(
    bool dark,
    List<Map<String, dynamic>> items, {
    required List<String> titleKeys,
    required List<String> subtitleKeys,
    required IconData icon,
    required String empty,
    List<String> statusKeys = const [],
  }) {
    if (items.isEmpty)
      return _panel(
        dark,
        Text(
          _loading ? 'Loading…' : empty,
          style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
        ),
      );
    return _panel(
      dark,
      Column(
        children: items.take(5).toList().asMap().entries.map((entry) {
          final item = entry.value;
          final title = _text(_field(item, titleKeys), 'Untitled');
          final rawSub = _field(item, subtitleKeys);
          final subtitle = rawSub != null
              ? rawSub.toString().split('T')[0]
              : '';
          final status = _field(item, statusKeys);
          return Column(
            children: [
              if (entry.key > 0)
                Divider(height: 1, color: AppColors.glassBorder(dark)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.copper.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.accentText(dark),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.muted(dark),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status != null) ...[
                      Builder(
                        builder: (_) {
                          final sUpper = status.toString().toUpperCase();
                          final isAppr = sUpper.contains('APPR') ||
                              sUpper.contains('COMPLET') ||
                              sUpper.contains('DONE') ||
                              sUpper.contains('REIMBURS') ||
                              sUpper.contains('PRESENT') ||
                              sUpper.contains('PAID') ||
                              sUpper.contains('ACCEPT');
                          final isRej = sUpper.contains('REJ') ||
                              sUpper.contains('DECLIN') ||
                              sUpper.contains('FAIL') ||
                              sUpper.contains('CANCEL') ||
                              sUpper.contains('REFUS') ||
                              sUpper.contains('ABSENT');
                          final badgeColor = isAppr
                              ? const Color(0xFF08A879)
                              : isRej
                                  ? const Color(0xFFE85D5D)
                                  : const Color(0xFFE88736);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              sUpper,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _quickActions(bool dark) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 2.1,
    children: [
      _quickAction(
        dark,
        'Apply Leave',
        Icons.beach_access_rounded,
        const Color(0xFF08A879),
        () => _open(const ApplyLeavePage()),
      ),
      _quickAction(
        dark,
        'Attendance',
        Icons.fact_check_rounded,
        const Color(0xFF5978F5),
        () => _open(const AttendancePage()),
      ),
      _quickAction(
        dark,
        'My Leave',
        Icons.event_note_rounded,
        const Color(0xFF6554E8),
        () => _open(const MyLeavePage()),
      ),
      _quickAction(
        dark,
        'My Profile',
        Icons.person_outline_rounded,
        const Color(0xFFE88736),
        () => _open(const ProfilePage()),
      ),
    ],
  );

  Widget _quickAction(
    bool dark,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF202326) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder(dark)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
