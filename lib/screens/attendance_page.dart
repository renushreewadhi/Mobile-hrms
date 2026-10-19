import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/hrms_services.dart';

/// Mobile Attendance module for ETAPRISE HRMS integrated with live backend APIs.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

enum _AttendanceSection { history, shift, corrections, rules }

class _AttendancePageState extends State<AttendancePage> {
  _AttendanceSection _section = _AttendanceSection.history;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  final AttendanceApiService _attendanceApi = AttendanceApiService();
  final ProfileApiService _profileApi = ProfileApiService();

  List<dynamic> _attendanceRecords = [];
  Map<String, dynamic> _myShift = {};
  List<_CorrectionRequest> _requests = [];
  List<dynamic> _rulesList = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _employeeName = 'Employee';
  String _employeeId = '';

  static const _purple = Color(0xFF6255D9);
  static const _green = Color(0xFF149B70);
  static const _red = Color(0xFFD94B45);
  static const _amber = Color(0xFFD18A25);

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileApi.getMyProfile();
      final empId = ProfileApiService.extractEmployeeId(profile) ?? '';
      _employeeId = empId;

      final name =
          profile['employeeName'] ??
              profile['firstName'] ??
              profile['fullName'] ??
              profile['name'];
      if (name != null && name.toString().trim().isNotEmpty) {
        _employeeName = name.toString().trim();
      }

      final startDateStr = "${_month.year}-${_month.month.toString().padLeft(2, '0')}-01";
      final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
      final endDateStr = "${_month.year}-${_month.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";

      final results = await Future.wait([
        empId.isNotEmpty
            ? _attendanceApi.getEmployeeAttendance(empId, startDate: startDateStr, endDate: endDateStr)
            : _attendanceApi.getAttendanceHistory(startDate: startDateStr, endDate: endDateStr),
        _attendanceApi.getMyShift(),
        _attendanceApi.getCorrections(employeeId: empId),
        _attendanceApi.getRules(),
      ]);

      if (!mounted) return;

      final records = results[0] is List ? (results[0] as List) : [];
      final shiftData = results[1] is Map
          ? Map<String, dynamic>.from(results[1] as Map)
          : <String, dynamic>{};
      final rawCorrections = results[2];
      final rawRules = results[3] is List ? (results[3] as List) : [];

      final correctionsList = <_CorrectionRequest>[];
      if (rawCorrections is List) {
        for (final c in rawCorrections) {
          if (c is Map) {
            final dateStr = c['date']?.toString() ?? '';
            final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
            final origIn = _formatTimeString(c['originalCheckIn']);
            final origOut = _formatTimeString(c['originalCheckOut']);
            final corrIn = _formatTimeString(c['correctedCheckIn']);
            final corrOut = _formatTimeString(c['correctedCheckOut']);
            final reason = c['reason']?.toString() ?? 'Correction request';
            final status = c['status']?.toString() ?? 'Pending';
            final submittedStr = c['createdAt']?.toString() ?? '';

            correctionsList.add(
              _CorrectionRequest(
                id: c['id']?.toString() ?? '',
                date: parsedDate,
                original: '$origIn – $origOut',
                corrected: '$corrIn – $corrOut',
                reason: reason,
                status: status,
                submitted: _formatDateString(submittedStr),
              ),
            );
          }
        }
      }

      setState(() {
        _attendanceRecords = records;
        _myShift = shiftData;
        _requests = correctionsList;
        _rulesList = rawRules;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getLatestShiftInfo() {
    if (_myShift.isNotEmpty) {
      return _myShift;
    }
    if (_attendanceRecords.isNotEmpty) {
      for (final r in _attendanceRecords) {
        if (r is Map && r.containsKey('shiftName') && r['shiftName'] != null) {
          return Map<String, dynamic>.from(r);
        }
      }
    }
    return {};
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
              onRefresh: _loadAttendanceData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Attendance',
                                    style: TextStyle(
                                      color: AppColors.text(dark),
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Personal attendance, shifts and corrections',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _employeePill(dark),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionTabs(dark),
                        const SizedBox(height: 18),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.copper,
                              ),
                            ),
                          )
                        else if (_errorMessage != null &&
                            _attendanceRecords.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadAttendanceData,
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
                              child: _sectionContent(dark),
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
        );
      },
    );
  }

  Widget _employeePill(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_rounded,
            size: 14,
            color: AppColors.accentText(dark),
          ),
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
  }

  Widget _sectionTabs(bool dark) {
    final entries = <(_AttendanceSection, String, IconData)>[
      (_AttendanceSection.history, 'History', Icons.calendar_month_outlined),
      (_AttendanceSection.shift, 'My Shift', Icons.schedule_rounded),
      (
      _AttendanceSection.corrections,
      'Corrections',
      Icons.edit_calendar_outlined,
      ),
      (_AttendanceSection.rules, 'Rules', Icons.policy_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: entries.map((entry) {
          final selected = _section == entry.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: selected
                  ? AppColors.copper.withValues(alpha: dark ? 0.22 : 0.17)
                  : AppColors.fieldFill(dark),
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() => _section = entry.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
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
                        entry.$3,
                        size: 15,
                        color: selected
                            ? AppColors.accentText(dark)
                            : AppColors.muted(dark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.$2,
                        style: TextStyle(
                          color: selected
                              ? AppColors.text(dark)
                              : AppColors.muted(dark),
                          fontSize: 10,
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

  Widget _sectionContent(bool dark) {
    switch (_section) {
      case _AttendanceSection.history:
        return _history(dark);
      case _AttendanceSection.shift:
        return _shiftDetails(dark);
      case _AttendanceSection.corrections:
        return _corrections(dark);
      case _AttendanceSection.rules:
        return _rules(dark);
    }
  }

  List<dynamic> _getFilteredRecordsForMonth() {
    return _attendanceRecords.where((record) {
      if (record is! Map) return false;
      final dateVal = record['date'];
      if (dateVal == null) return true;
      final parsed = DateTime.tryParse(dateVal.toString());
      if (parsed == null) return true;
      return parsed.year == _month.year && parsed.month == _month.month;
    }).toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _loadAttendanceData();
  }

  Widget _history(bool dark) {
    final monthName = _monthLabel(_month);
    final monthRecords = _getFilteredRecordsForMonth();
    final recordsToDisplay = monthRecords;

    final presentCount = recordsToDisplay
        .where(
          (r) => r is Map && r['status']?.toString().toUpperCase() == 'PRESENT',
    )
        .length;
    final absentCount = recordsToDisplay
        .where(
          (r) => r is Map && r['status']?.toString().toUpperCase() == 'ABSENT',
    )
        .length;
    final lateCount = recordsToDisplay
        .where(
          (r) => r is Map && r['status']?.toString().toUpperCase() == 'LATE',
    )
        .length;

    final shiftInfo = _getLatestShiftInfo();
    final shiftName =
        shiftInfo['name']?.toString() ??
            shiftInfo['shiftName']?.toString() ??
            'Not assigned';
    final shiftStart =
        shiftInfo['startTime']?.toString() ??
            shiftInfo['shiftStartTime']?.toString() ??
            '—';
    final shiftEnd =
        shiftInfo['endTime']?.toString() ??
            shiftInfo['shiftEndTime']?.toString() ??
            '—';
    final gracePeriod =
        shiftInfo['lateGracePeriodMinutes']?.toString() ??
            shiftInfo['gracePeriodMinutes']?.toString() ??
            '—';
    final breakMins =
        shiftInfo['breakDurationMinutes']?.toString() ??
            shiftInfo['breakMinutes']?.toString() ??
            '—';
    final workingDays = shiftInfo['workingDays'] != null
        ? (shiftInfo['workingDays'] is List
        ? (shiftInfo['workingDays'] as List).join(', ')
        : shiftInfo['workingDays'].toString())
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surface(
          dark,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _smallIconButton(
                dark,
                Icons.chevron_left_rounded,
                    () => _changeMonth(-1),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.accentText(dark),
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monthName,
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _smallIconButton(
                dark,
                Icons.chevron_right_rounded,
                    () => _changeMonth(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _surface(
          dark,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconTile(dark, Icons.people_alt_rounded, _purple),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shiftName,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          shiftStart != '—'
                              ? '$shiftStart – $shiftEnd'
                              : 'No shift schedule configured',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _pill(
                    dark,
                    shiftName != 'Not assigned' ? 'ASSIGNED' : 'UNASSIGNED',
                    AppColors.copper,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 9,
                children: [
                  _inlineInfo(
                    Icons.shield_outlined,
                    'Grace: ${gracePeriod != '—' ? '$gracePeriod min' : '—'}',
                    _green,
                    dark,
                  ),
                  _inlineInfo(
                    Icons.coffee_rounded,
                    'Break: ${breakMins != '—' ? '$breakMins min' : '—'}',
                    _amber,
                    dark,
                  ),
                  _inlineInfo(
                    Icons.calendar_month_outlined,
                    workingDays,
                    _purple,
                    dark,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                      '$monthName summary',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _pill(dark, '${recordsToDisplay.length} ENTRIES', _purple),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _summaryMetric(
                      dark,
                      '$presentCount',
                      'Present',
                      _green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryMetric(dark, '$absentCount', 'Absent', _red),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryMetric(dark, '$lateCount', 'Late', _amber),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Attendance Logs',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (recordsToDisplay.isEmpty)
          _surface(
            dark,
            padding: const EdgeInsets.all(15),
            child: _emptyState(
              dark,
              Icons.event_note_rounded,
              'No attendance records available',
              'Your daily attendance entries will appear here.',
            ),
          )
        else
          ...recordsToDisplay.map(
                (record) => _attendanceRecordCard(dark, record),
          ),
      ],
    );
  }

  Widget _attendanceRecordCard(bool dark, dynamic record) {
    final map = record is Map
        ? Map<String, dynamic>.from(record)
        : <String, dynamic>{};
    final dateFormatted = _formatDateString(map['date']);
    final status = map['status']?.toString().toUpperCase() ?? 'PRESENT';
    final workHours = _formatWorkHours(map['workHours']);
    final overtime =
    map['overtime'] != null &&
        (double.tryParse(map['overtime'].toString()) ?? 0) > 0
        ? _formatWorkHours(map['overtime'])
        : null;

    final checkInFormatted = _formatTimeString(
      map['checkIn'] ?? map['checkInTime'],
    );
    final checkOutFormatted = _formatTimeString(
      map['checkOut'] ?? map['checkOutTime'],
    );
    final location =
        map['checkInLocation']?.toString() ??
            map['location']?.toString() ??
            'Office';
    final checkOutLocation = map['checkOutLocation']?.toString();
    final lateDurationMins = map['lateDurationMinutes'];
    final verificationStatus = map['verificationStatus']?.toString();
    final workMode = map['workMode']?.toString();

    final Color statusColor;
    if (status == 'PRESENT') {
      statusColor = _green;
    } else if (status == 'LATE') {
      statusColor = _amber;
    } else {
      statusColor = _red;
    }

    final breaksList = map['breaks'] is List ? (map['breaks'] as List) : [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _surface(
        dark,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateFormatted,
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (workMode != null) ...[
                  _pill(dark, workMode, _purple),
                  const SizedBox(width: 6),
                ],
                _pill(dark, status, statusColor),
              ],
            ),
            const SizedBox(height: 10),
            _keyValue(
              dark,
              'Check In / Out',
              '$checkInFormatted – $checkOutFormatted',
            ),
            const SizedBox(height: 6),
            _keyValue(
              dark,
              'Work Hours',
              overtime != null ? '$workHours (OT: $overtime)' : workHours,
            ),
            if (lateDurationMins != null &&
                (int.tryParse(lateDurationMins.toString()) ?? 0) > 0) ...[
              const SizedBox(height: 6),
              _keyValue(dark, 'Late Duration', '$lateDurationMins minutes'),
            ],
            const SizedBox(height: 6),
            _keyValue(dark, 'Check-In Location', location),
            if (checkOutLocation != null && checkOutLocation != location) ...[
              const SizedBox(height: 6),
              _keyValue(dark, 'Check-Out Location', checkOutLocation),
            ],
            if (verificationStatus != null) ...[
              const SizedBox(height: 6),
              _keyValue(dark, 'Verification', verificationStatus),
            ],
            if (breaksList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Breaks (${breaksList.length})',
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              ...breaksList.map((b) {
                final bMap = b is Map
                    ? Map<String, dynamic>.from(b)
                    : <String, dynamic>{};
                final start = _formatTimeString(bMap['startTime']);
                final end = _formatTimeString(bMap['endTime']);
                final durStr = _calculateBreakDuration(bMap);
                final durLabel = (durStr.isNotEmpty && durStr != '—') ? ' ($durStr)' : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $start – $end$durLabel',
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 10.5,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shiftDetails(bool dark) {
    final shiftInfo = _getLatestShiftInfo();
    final shiftName =
        shiftInfo['name']?.toString() ??
            shiftInfo['shiftName']?.toString() ??
            'Not assigned';
    final shiftStart =
        shiftInfo['startTime']?.toString() ??
            shiftInfo['shiftStartTime']?.toString() ??
            '—';
    final shiftEnd =
        shiftInfo['endTime']?.toString() ??
            shiftInfo['shiftEndTime']?.toString() ??
            '—';
    final gracePeriod =
        shiftInfo['lateGracePeriodMinutes']?.toString() ??
            shiftInfo['gracePeriodMinutes']?.toString() ??
            '—';
    final breakMins =
        shiftInfo['breakDurationMinutes']?.toString() ??
            shiftInfo['breakMinutes']?.toString() ??
            '—';

    return _surface(
      dark,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(dark, Icons.people_alt_rounded, _purple),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Shift Schedule',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your configured shift and break policy',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _shiftTile(
            dark,
            Icons.apartment_rounded,
            'SHIFT NAME',
            shiftName,
            _purple,
          ),
          const SizedBox(height: 10),
          _shiftTile(
            dark,
            Icons.schedule_rounded,
            'TIMINGS',
            shiftStart != '—' ? '$shiftStart – $shiftEnd' : '—',
            _purple,
          ),
          const SizedBox(height: 10),
          _shiftTile(
            dark,
            Icons.shield_outlined,
            'GRACE PERIOD',
            gracePeriod != '—' ? '$gracePeriod Minutes' : '—',
            _green,
          ),
          const SizedBox(height: 10),
          _shiftTile(
            dark,
            Icons.coffee_rounded,
            'BREAK DURATION',
            breakMins != '—' ? '$breakMins Minutes' : '—',
            _amber,
          ),
        ],
      ),
    );
  }

  Widget _corrections(bool dark) {
    return Column(
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
                  _iconTile(dark, Icons.edit_calendar_rounded, _purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Corrections',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Request a correction for a missed punch',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCorrectionDialog(dark),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Correction Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.copper,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._requests.map(
              (request) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _correctionCard(dark, request),
          ),
        ),
        if (_requests.isEmpty)
          _surface(
            dark,
            padding: const EdgeInsets.all(16),
            child: _emptyState(
              dark,
              Icons.inbox_outlined,
              'No correction requests yet',
              'Use the button above to submit a request.',
            ),
          ),
      ],
    );
  }

  Widget _correctionCard(bool dark, _CorrectionRequest request) {
    final statusColor = request.status.toUpperCase() == 'APPROVED'
        ? _green
        : request.status.toUpperCase() == 'REJECTED'
        ? _red
        : _amber;
    return _surface(
      dark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dateLabelFor(request.date),
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _pill(dark, request.status.toUpperCase(), statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _keyValue(dark, 'Original time', request.original),
          const SizedBox(height: 7),
          _keyValue(dark, 'Corrected time', request.corrected),
          const SizedBox(height: 7),
          _keyValue(dark, 'Reason', request.reason),
          const SizedBox(height: 7),
          _keyValue(dark, 'Submitted', request.submitted),
        ],
      ),
    );
  }

  Widget _rules(bool dark) {
    return _surface(
      dark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(dark, Icons.policy_outlined, _green),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Rules & Policies',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Policies applicable to your attendance',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_rulesList.isEmpty)
            _emptyState(
              dark,
              Icons.policy_outlined,
              'No custom rules found',
              'Standard company attendance policies apply.',
            )
          else
            ..._rulesList.map((rMap) {
              final rule = rMap is Map
                  ? Map<String, dynamic>.from(rMap)
                  : <String, dynamic>{};
              final name = rule['name']?.toString() ?? 'Attendance Rule';
              final desc =
                  rule['description']?.toString() ??
                      'Configured attendance rule.';
              final grace = rule['graceMinutes']?.toString() ?? '—';
              final minHours = rule['minWorkHours']?.toString() ?? '—';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill(dark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder(dark)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: _green,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• Grace period: $grace minutes',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• Minimum working hours: $minHours hours',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _surface(
      bool dark, {
        required Widget child,
        EdgeInsetsGeometry? padding,
      }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xCC17191A)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: child,
    );
  }

  Widget _iconTile(bool dark, IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  Widget _smallIconButton(bool dark, IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.fieldFill(dark),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder(dark)),
          ),
          child: Icon(icon, color: AppColors.text(dark), size: 18),
        ),
      ),
    );
  }

  Widget _pill(bool dark, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _summaryMetric(bool dark, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyValue(bool dark, String key, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            key,
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.text(dark),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shiftTile(
      bool dark,
      IconData icon,
      String title,
      String value,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineInfo(IconData icon, String text, Color color, bool dark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(bool dark, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.muted(dark)),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors.text(dark),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 11,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _dateLabelFor(DateTime date) {
    return '${date.day} ${_monthLabel(date).split(' ')[0]} ${date.year}';
  }

  String _formatDateString(dynamic dateVal) {
    if (dateVal == null || dateVal.toString().trim().isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateVal.toString());
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
      return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateVal.toString().split('T')[0];
    }
  }

  String _formatTimeString(dynamic isoStr) {
    if (isoStr == null || isoStr.toString().trim().isEmpty) return '--:--';
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

  String _calculateBreakDuration(Map<String, dynamic> bMap) {
    final explicit = bMap['durationMinutes'] ??
        bMap['duration'] ??
        bMap['durationMins'] ??
        bMap['breakMinutes'] ??
        bMap['minutes'];

    if (explicit != null) {
      final str = explicit.toString().trim();
      if (str.isNotEmpty && str != '—' && str != 'null') {
        final parsed = double.tryParse(str);
        if (parsed != null && parsed > 0) {
          return '${parsed.round()} min';
        }
        if (str.contains('min') || str.contains('m') || str.contains('sec')) {
          return str;
        }
      }
    }

    final startStr = bMap['startTime'] ?? bMap['start'] ?? bMap['breakStart'] ?? bMap['checkIn'];
    final endStr = bMap['endTime'] ?? bMap['end'] ?? bMap['breakEnd'] ?? bMap['checkOut'];

    if (startStr != null && endStr != null) {
      final startDt = DateTime.tryParse(startStr.toString());
      final endDt = DateTime.tryParse(endStr.toString());
      if (startDt != null && endDt != null) {
        final diffSeconds = endDt.difference(startDt).inSeconds;
        if (diffSeconds > 0) {
          final diffMinutes = diffSeconds ~/ 60;
          final remSeconds = diffSeconds % 60;
          if (diffMinutes > 0) {
            if (remSeconds > 0) {
              return '$diffMinutes min ${remSeconds}s';
            }
            return '$diffMinutes min';
          } else {
            return '$diffSeconds sec';
          }
        }
      }
    }

    return '—';
  }

  String _formatWorkHours(dynamic value) {
    if (value == null) return '0 hrs';
    final numVal = double.tryParse(value.toString());
    if (numVal == null) return '$value hrs';
    return '${numVal.toStringAsFixed(2)} hrs';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  void _showCorrectionDialog(bool dark) {
    final reasonController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay checkInTime = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay checkOutTime = const TimeOfDay(hour: 16, minute: 0);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: dark ? AppColors.graphite : Colors.white,
          title: Text(
            'Request Correction',
            style: TextStyle(
              color: AppColors.text(dark),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit an attendance correction request for review.',
                  style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Text(
                  'DATE *',
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill(dark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder(dark)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.accentText(dark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabelFor(selectedDate),
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'CORRECTED CHECK-IN TIME *',
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: checkInTime,
                    );
                    if (picked != null) {
                      setDialogState(() => checkInTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill(dark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder(dark)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.accentText(dark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeOfDay(checkInTime),
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'CORRECTED CHECK-OUT TIME *',
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: checkOutTime,
                    );
                    if (picked != null) {
                      setDialogState(() => checkOutTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill(dark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder(dark)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 16,
                          color: AppColors.accentText(dark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimeOfDay(checkOutTime),
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'REASON FOR CORRECTION *',
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.text(dark), fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. Forgot to clock in/out',
                    hintStyle: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 11,
                    ),
                    filled: true,
                    fillColor: AppColors.fieldFill(dark),
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.glassBorder(dark)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                Navigator.of(dialogCtx).pop();

                try {
                  final checkInDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    checkInTime.hour,
                    checkInTime.minute,
                  );
                  final checkOutDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    checkOutTime.hour,
                    checkOutTime.minute,
                  );

                  final payload = <String, dynamic>{
                    'employeeId': _employeeId,
                    'date': selectedDate.toIso8601String(),
                    'correctedCheckIn': checkInDateTime.toIso8601String(),
                    'correctedCheckOut': checkOutDateTime.toIso8601String(),
                    'reason': reason,
                  };
                  await _attendanceApi.requestCorrection(payload);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Correction request submitted.'),
                      backgroundColor: Color(0xFF149B70),
                    ),
                  );
                  _loadAttendanceData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Submission failed: ${e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "")}',
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.copper,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionRequest {
  final String id;
  final DateTime date;
  final String original;
  final String corrected;
  final String reason;
  final String status;
  final String submitted;

  const _CorrectionRequest({
    required this.id,
    required this.date,
    required this.original,
    required this.corrected,
    required this.reason,
    required this.status,
    required this.submitted,
  });
}
