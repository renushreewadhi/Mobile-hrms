import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/leave_api_service.dart';
import '../services/profile_api_service.dart';
import 'apply_leave_page.dart';

/// My Leave module for ETAPRISE HRMS integrated with ASP.NET Core backend.
class MyLeavePage extends StatefulWidget {
  const MyLeavePage({super.key});

  @override
  State<MyLeavePage> createState() => _MyLeavePageState();
}

enum _LeaveSection { overview, history }

class _MyLeavePageState extends State<MyLeavePage> {
  _LeaveSection _section = _LeaveSection.overview;
  String _statusFilter = 'All';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  final LeaveApiService _leaveApi = LeaveApiService();
  final ProfileApiService _profileApi = ProfileApiService();

  bool _loading = true;
  String? _error;
  String _employeeName = 'Employee';

  List<_LeaveBalance> _balances = [];
  List<_LeaveRecord> _records = [];

  static const Color _purple = Color(0xFF6255D9);
  static const Color _green = Color(0xFF149B70);
  static const Color _red = Color(0xFFD94B45);
  static const Color _amber = Color(0xFFD18A25);
  static const Color _blue = Color(0xFF4285C5);

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _profileApi.getMyProfile();
      final employeeId = ProfileApiService.extractEmployeeId(profile) ?? '';
      final name =
          profile['employeeName'] ??
          profile['firstName'] ??
          profile['fullName'] ??
          profile['name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        _employeeName = name.toString().trim();
      }

      dynamic rawBalances;
      dynamic rawRequests;

      try {
        rawBalances = await _leaveApi.getLeaveBalances(employeeId: employeeId);
      } catch (_) {}

      try {
        rawRequests = await _leaveApi.getMyLeaveRequests(employeeId: employeeId);
      } catch (_) {}

      final balancesList = <_LeaveBalance>[];
      if (rawBalances is List) {
        for (var i = 0; i < rawBalances.length; i++) {
          final b = rawBalances[i];
          if (b is Map) {
            final typeName =
                b['leaveType']?.toString() ??
                b['leaveTypeName']?.toString() ??
                b['name']?.toString() ??
                'Leave';
            final entitled = _toInt(
              b['entitled'] ?? b['total'] ?? b['totalDays'] ?? b['annualQuota'],
            );
            final used = _toInt(
              b['taken'] ?? b['used'] ?? b['usedDays'] ?? b['consumed'],
            );
            final remaining = _toInt(
              b['remaining'] ??
                  b['available'] ??
                  b['remainingDays'] ??
                  b['balance'] ??
                  (entitled - used),
            );

            final color = [_purple, _red, _green, _amber, _blue][i % 5];
            balancesList.add(
              _LeaveBalance(
                name: typeName,
                available: remaining,
                entitled: entitled,
                used: used,
                color: color,
                icon: _getLeaveIcon(typeName),
              ),
            );
          }
        }
      }

      final recordsList = <_LeaveRecord>[];
      if (rawRequests is List) {
        for (final r in rawRequests) {
          if (r is Map) {
            final typeName =
                r['leaveType']?.toString() ?? r['type']?.toString() ?? 'Leave';
            final startStr =
                r['startDate']?.toString() ??
                r['fromDate']?.toString() ??
                r['start']?.toString() ??
                '';
            final endStr =
                r['endDate']?.toString() ??
                r['toDate']?.toString() ??
                r['end']?.toString() ??
                '';
            final start = DateTime.tryParse(startStr) ?? DateTime.now();
            final end = DateTime.tryParse(endStr) ?? start;
            final days = _toInt(
              r['totalDays'] ?? r['days'] ?? (end.difference(start).inDays + 1),
            );
            final reason = r['reason']?.toString() ?? 'No reason specified';
            final statusRaw = r['status']?.toString() ?? 'Pending';
            final statusFormatted = _formatStatus(statusRaw);
            final reviewer =
                r['approvedByName']?.toString() ??
                r['approvedBy']?.toString() ??
                r['reviewer']?.toString() ??
                'Awaiting review';

            recordsList.add(
              _LeaveRecord(
                id: r['id']?.toString() ?? '',
                type: typeName,
                start: start,
                end: end,
                days: days > 0 ? days : 1,
                reason: reason,
                status: statusFormatted,
                reviewer: reviewer,
              ),
            );
          }
        }
      }

      setState(() {
        _balances = balancesList;
        _records = recordsList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int _toInt(dynamic val) {
    if (val is num) return val.toInt();
    if (val == null) return 0;
    return int.tryParse(val.toString()) ?? 0;
  }

  IconData _getLeaveIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('sick')) return Icons.medical_services_outlined;
    if (lower.contains('annual') || lower.contains('earned'))
      return Icons.calendar_month_rounded;
    if (lower.contains('casual')) return Icons.event_available_outlined;
    if (lower.contains('paid')) return Icons.beenhere_outlined;
    if (lower.contains('comp')) return Icons.card_giftcard_rounded;
    return Icons.person_outline_rounded;
  }

  String _formatStatus(String status) {
    final s = status.toUpperCase();
    if (s.contains('APPROV')) return 'Approved';
    if (s.contains('REJECT')) return 'Rejected';
    if (s.contains('CANCEL')) return 'Cancelled';
    return 'Pending';
  }

  bool get _dark => AppColors.isDarkMode.value;
  int get _totalAvailable =>
      _balances.fold(0, (sum, item) => sum + item.available);
  int get _pendingCount =>
      _records.where((item) => item.status == 'Pending').length;
  int get _approvedCount =>
      _records.where((item) => item.status == 'Approved').length;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) => Scaffold(
        backgroundColor: dark ? AppColors.graphite : AppColors.cream,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadLeaveData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Leave',
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Leave balance, requests and history',
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _employeePill(dark),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _sectionTabs(dark),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.copper,
                            ),
                          ),
                        )
                      else if (_error != null && _records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadLeaveData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.copper,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          child: KeyedSubtree(
                            key: ValueKey(_section),
                            child: _section == _LeaveSection.overview
                                ? _overview(dark)
                                : _history(dark),
                          ),
                        ),
                      const SizedBox(height: 22),
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openApplyLeavePage,
          backgroundColor: AppColors.copper,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Apply Leave',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _employeePill(bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.fieldFill(dark),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.glassBorder(dark)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_rounded, size: 14, color: AppColors.accentText(dark)),
        const SizedBox(width: 5),
        Text(
          _employeeName,
          style: TextStyle(
            color: AppColors.accentText(dark),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _sectionTabs(bool dark) {
    final tabs = <(_LeaveSection, String, IconData)>[
      (_LeaveSection.overview, 'Overview', Icons.dashboard_outlined),
      (_LeaveSection.history, 'Leave history', Icons.history_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final selected = _section == tab.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: selected
                  ? AppColors.copper.withValues(alpha: dark ? 0.22 : 0.17)
                  : AppColors.fieldFill(dark),
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() => _section = tab.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? AppColors.copper.withValues(alpha: 0.75)
                          : AppColors.glassBorder(dark),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.$3,
                        size: 15,
                        color: selected
                            ? AppColors.accentText(dark)
                            : AppColors.muted(dark),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        tab.$2,
                        style: TextStyle(
                          color: selected
                              ? AppColors.text(dark)
                              : AppColors.muted(dark),
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _overview(bool dark) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _surface(
        dark,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Leave at a glance',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _pill(dark, 'CURRENT BALANCE', AppColors.copper),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.copper.withValues(alpha: dark ? 0.27 : 0.20),
                    AppColors.fieldFill(dark),
                  ],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: AppColors.copper.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      color: AppColors.copper.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      color: AppColors.accentText(dark),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total days available',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_totalAvailable days',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Across all leave categories',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    dark,
                    '$_pendingCount',
                    'Pending',
                    Icons.schedule_rounded,
                    _amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statTile(
                    dark,
                    '$_approvedCount',
                    'Approved',
                    Icons.check_circle_outline_rounded,
                    _green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statTile(
                    dark,
                    '${_records.length}',
                    'Requests',
                    Icons.list_alt_rounded,
                    _purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              'Leave balances',
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            'Allocation & usage',
            style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_balances.isEmpty)
        _surface(
          dark,
          padding: const EdgeInsets.all(16),
          child: _emptyState(
            dark,
            Icons.event_note_rounded,
            'No leave balances configured',
            'Your leave quota will appear here once allocated.',
          ),
        )
      else
        ..._balances.map(
          (balance) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _balanceCard(dark, balance),
          ),
        ),
      const SizedBox(height: 4),
      _surface(
        dark,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: AppColors.accentText(dark),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent leave requests',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _section = _LeaveSection.history),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.accentText(dark),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_records.isEmpty)
              _emptyState(
                dark,
                Icons.inbox_outlined,
                'No leave requests submitted',
                'Apply for leave using the button below.',
              )
            else
              ..._records.take(3).map((record) => _recordTile(dark, record)),
          ],
        ),
      ),
    ],
  );

  Widget _statTile(
    bool dark,
    String value,
    String label,
    IconData icon,
    Color color,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: dark ? 0.13 : 0.075),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.23)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(height: 9),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.muted(dark),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _balanceCard(bool dark, _LeaveBalance balance) {
    final progress = balance.entitled == 0
        ? 0.0
        : (balance.used / balance.entitled).clamp(0.0, 1.0);
    return _surface(
      dark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: balance.color.withValues(alpha: dark ? 0.18 : 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(balance.icon, color: balance.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  balance.name,
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${balance.available}',
                style: TextStyle(
                  color: balance.color,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'left',
                style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.glassBorder(dark),
              valueColor: AlwaysStoppedAnimation<Color>(balance.color),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Used: ${balance.used} days',
                  style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
                ),
              ),
              Text(
                'Entitled: ${balance.entitled} days',
                style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _history(bool dark) {
    final statuses = ['All', 'Pending', 'Approved', 'Rejected', 'Cancelled'];
    final filtered = _records.where((record) {
      final statusMatches =
          _statusFilter == 'All' || record.status == _statusFilter;
      final query = _search.trim().toLowerCase();
      final searchMatches =
          query.isEmpty ||
          record.type.toLowerCase().contains(query) ||
          record.reason.toLowerCase().contains(query) ||
          record.status.toLowerCase().contains(query) ||
          record.reviewer.toLowerCase().contains(query);
      return statusMatches && searchMatches;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surface(
          dark,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Leave history & status',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _pill(dark, '${filtered.length} RECORDS', AppColors.copper),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                style: TextStyle(color: AppColors.text(dark), fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search leave records...',
                  hintStyle: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 11,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.muted(dark),
                    size: 19,
                  ),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.muted(dark),
                            size: 18,
                          ),
                        ),
                  filled: true,
                  fillColor: AppColors.fieldFill(dark),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: AppColors.glassBorder(dark)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: AppColors.glassBorder(dark)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide(color: AppColors.copper),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: statuses.map((status) {
                    final selected = _statusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(status),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _statusFilter = status),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.text(dark),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: AppColors.copper,
                        backgroundColor: AppColors.fieldFill(dark),
                        side: BorderSide(
                          color: selected
                              ? AppColors.copper
                              : AppColors.glassBorder(dark),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _surface(
            dark,
            padding: const EdgeInsets.all(20),
            child: _emptyState(
              dark,
              Icons.search_off_rounded,
              'No leave records found',
              'Try another search term or status filter.',
            ),
          )
        else
          ...filtered.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _recordTile(dark, record, expanded: true),
            ),
          ),
      ],
    );
  }

  Widget _recordTile(bool dark, _LeaveRecord record, {bool expanded = false}) {
    final color = _statusColor(record.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _showRecordDetails(dark, record),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.fieldFill(dark).withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.glassBorder(dark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.type,
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _pill(dark, record.status.toUpperCase(), color),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.muted(dark),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_dateLabel(record.start)} – ${_dateLabel(record.end)}',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${record.days} days',
                      style: TextStyle(
                        color: AppColors.accentText(dark),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: AppColors.glassBorder(dark)),
                  const SizedBox(height: 9),
                  _keyValue(dark, 'Reason', record.reason),
                  const SizedBox(height: 7),
                  _keyValue(dark, 'Reviewed by', record.reviewer),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showRecordDetails(dark, record),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text(
                        'View details',
                        style: TextStyle(fontSize: 10),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentText(dark),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      record.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 10,
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

  Future<void> _openApplyLeavePage() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ApplyLeavePage()),
    );

    if (updated == true && mounted) {
      _loadLeaveData();
    }
  }

  void _showRecordDetails(bool dark, _LeaveRecord record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF202326) : const Color(0xFFF9F8F5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          border: Border.all(color: AppColors.glassBorder(dark)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted(dark).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Leave request details',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _pill(
                    dark,
                    record.status.toUpperCase(),
                    _statusColor(record.status),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _detailLine(
                dark,
                Icons.event_note_rounded,
                'Leave type',
                record.type,
              ),
              _detailLine(
                dark,
                Icons.calendar_today_rounded,
                'Start date',
                _dateLabel(record.start),
              ),
              _detailLine(
                dark,
                Icons.event_available_rounded,
                'End date',
                _dateLabel(record.end),
              ),
              _detailLine(
                dark,
                Icons.timelapse_rounded,
                'Duration',
                '${record.days} days',
              ),
              _detailLine(dark, Icons.notes_rounded, 'Reason', record.reason),
              _detailLine(
                dark,
                Icons.person_outline_rounded,
                'Reviewed by',
                record.reviewer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(bool dark, IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: AppColors.accentText(dark)),
            const SizedBox(width: 10),
            SizedBox(
              width: 95,
              child: Text(
                label,
                style: TextStyle(color: AppColors.muted(dark), fontSize: 11),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _surface(
    bool dark, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(15),
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(19),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xDD1B1E20)
              : Colors.white.withValues(alpha: 0.91),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE2DED7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.10 : 0.025),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  Widget _pill(bool dark, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: dark ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.35,
      ),
    ),
  );

  Widget _keyValue(
    bool dark,
    String label,
    String value, {
    Color? valueColor,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: AppColors.muted(dark), fontSize: 10.5),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: valueColor ?? AppColors.text(dark),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _emptyState(bool dark, IconData icon, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 29, color: AppColors.muted(dark)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );

  Color _statusColor(String status) => switch (status) {
    'Approved' => _green,
    'Rejected' => _red,
    'Cancelled' => AppColors.muted(_dark),
    _ => _amber,
  };

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
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}

class _LeaveBalance {
  const _LeaveBalance({
    required this.name,
    required this.available,
    required this.entitled,
    required this.used,
    required this.color,
    required this.icon,
  });
  final String name;
  final int available;
  final int entitled;
  final int used;
  final Color color;
  final IconData icon;
}

class _LeaveRecord {
  const _LeaveRecord({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.days,
    required this.reason,
    required this.status,
    required this.reviewer,
  });
  final String id;
  final String type;
  final DateTime start;
  final DateTime end;
  final int days;
  final String reason;
  final String status;
  final String reviewer;
}
