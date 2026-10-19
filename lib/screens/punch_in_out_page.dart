import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../services/attendance_api_service.dart';
import '../services/profile_api_service.dart';
import '../theme/app_colors.dart';
import 'apply_leave_page.dart';
import 'attendance_page.dart';

/// Full Mobile Punch In/Out screen matching exact ETAPRISE HRMS Web Frontend component
/// (`check-in-out.component.ts/html/scss`), complete with official Google Maps API,
/// Haversine GPS distance calculation, geofencing, face selfie verification, shift logs & 30-day overview.
class PunchInOutPage extends StatefulWidget {
  const PunchInOutPage({super.key});

  @override
  State<PunchInOutPage> createState() => _PunchInOutPageState();
}

class _PunchInOutPageState extends State<PunchInOutPage> {
  final AttendanceApiService _attendanceApi = AttendanceApiService();
  final ProfileApiService _profileApi = ProfileApiService();
  final ImagePicker _imagePicker = ImagePicker();
  GoogleMapController? _googleMapController;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Employee details
  String _employeeId = '';
  String _employeeName = 'Prince Vidyarthi';
  String _designation = 'Software Engineer';
  String _department = 'Development';
  String _avatar = '';

  // Attendance state
  Map<String, dynamic> _todayRecord = {};
  DateTime? _checkInAt;
  DateTime? _checkOutAt;
  DateTime? _breakStartedAt;
  Duration _completedBreak = Duration.zero;

  bool _isOnBreak = false;
  bool _showMapCard = true;
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _error;

  // Shift info
  String _shiftName = 'General Shift';
  String _shiftStartTime = '09:00 AM';
  String _shiftEndTime = '06:00 PM';

  // Locations & Geofence (Exact defaults from check-in-out.component.ts)
  String _checkInLocation = 'Office Location';
  String _checkOutLocation = 'Office Location';

  double _officeLat = 21.1986872; // Exact HQ coordinates from check-in-out.component.ts
  double _officeLng = 72.7965515;
  String _officeName = 'Envision Beyond India Pvt Ltd';
  String _officeAddress = '6Q2V+MR9, Anand Mahal Rd, Adajan, Surat, Gujarat 395009, India';
  double _geofenceRadiusMeters = 200;

  // Map Tile Selector
  String _selectedTileType = 'Streets'; // 'Streets', 'Satellite', 'OpenStreetMap'

  // Live device GPS position
  Position? _currentPosition;
  String _currentAddress = 'Detecting location address...';
  String _gpsStatusMessage = 'Detecting location...';
  bool _isWithinGeofence = false;
  double _distanceFromOfficeMeters = 0.0;

  // Attendance overview statistics (30 days)
  List<dynamic> _attendanceHistory = [];
  int _presentDays = 0;
  int _absentDays = 0;
  int _lateClockIns = 0;
  double _attendanceRatePercent = 0.0;
  String _hoursLoggedBadge = '14.44h logged';

  bool get _checkedIn => _checkInAt != null && _checkOutAt == null;

  Duration get _workDuration {
    if (_checkInAt == null) return Duration.zero;
    final end = _checkOutAt ?? _now;
    final total = end.difference(_checkInAt!);
    final activeBreak = _isOnBreak && _breakStartedAt != null
        ? _now.difference(_breakStartedAt!)
        : Duration.zero;
    final value = total - _completedBreak - activeBreak;
    return value.isNegative ? Duration.zero : value;
  }

  Duration get _breakDuration {
    if (_isOnBreak && _breakStartedAt != null) {
      return _completedBreak + _now.difference(_breakStartedAt!);
    }
    return _completedBreak;
  }

  bool get _isPostShiftWarning30m {
    if (!_checkedIn || _checkOutAt != null) return false;
    try {
      final parts = _shiftEndTime.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (parts.length >= 2) {
        int hour = int.tryParse(parts[0]) ?? 18;
        final min = int.tryParse(parts[1]) ?? 0;
        if (_shiftEndTime.toUpperCase().contains('PM') && hour < 12) hour += 12;
        if (_shiftEndTime.toUpperCase().contains('AM') && hour == 12) hour = 0;

        final shiftEndDateTime = DateTime(_now.year, _now.month, _now.day, hour, min);
        return _now.isAfter(shiftEndDateTime.add(const Duration(minutes: 30)));
      }
    } catch (_) {}
    return false;
  }

  String get _distanceDisplay {
    if (_distanceFromOfficeMeters <= 0) return '0m away';
    if (_distanceFromOfficeMeters >= 1000) {
      return '${(_distanceFromOfficeMeters / 1000).toStringAsFixed(2)}km away';
    }
    return '${_distanceFromOfficeMeters.round()}m away';
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String? _extractFirst(Map map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) {
        final val = map[k].toString().trim();
        if (val.isNotEmpty && val != 'null') return val;
      }
    }
    return null;
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _profileApi.getMyProfile();
      final empId = ProfileApiService.extractEmployeeId(profile) ?? '';
      _employeeId = empId;

      final eName = profile['employeeName'] ?? profile['fullName'] ??
          '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
      if (eName.isNotEmpty) _employeeName = eName;
      _designation = profile['designationName'] ?? profile['designation'] ?? 'Software Engineer';
      _department = profile['departmentName'] ?? profile['department'] ?? 'Development';
      _avatar = profile['avatar'] ?? '';

      // Parallel fetch: Today's attendance, My shift, Office location, History, Summary
      final results = await Future.wait([
        _attendanceApi.getTodayAttendance(employeeId: empId),
        _attendanceApi.getMyShift(),
        _attendanceApi.getOfficeLocation(),
        empId.isNotEmpty
            ? _attendanceApi.getEmployeeAttendance(empId,
                startDate: DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0],
                endDate: DateTime.now().toIso8601String().split('T')[0])
            : _attendanceApi.getAttendanceHistory(
                startDate: DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0],
                endDate: DateTime.now().toIso8601String().split('T')[0]),
        _attendanceApi.getSummary(
          startDate: DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0],
          endDate: DateTime.now().toIso8601String().split('T')[0],
        ),
      ]);

      if (!mounted) return;

      final record = results[0];
      final shift = results[1] is Map ? Map<String, dynamic>.from(results[1] as Map) : <String, dynamic>{};
      final officeLoc = results[2] is Map ? Map<String, dynamic>.from(results[2] as Map) : <String, dynamic>{};
      final historyList = results[3] is List ? (results[3] as List) : [];
      final summaryData = results[4];

      // Process Office Location Settings
      if (officeLoc.isNotEmpty) {
        if (officeLoc['latitude'] != null && officeLoc['longitude'] != null) {
          _officeLat = (officeLoc['latitude'] as num).toDouble();
          _officeLng = (officeLoc['longitude'] as num).toDouble();
        }
        if (officeLoc['officeName'] != null && officeLoc['officeName'].toString().isNotEmpty) {
          _officeName = officeLoc['officeName'].toString();
        }
        if (officeLoc['officeAddress'] != null && officeLoc['officeAddress'].toString().isNotEmpty) {
          _officeAddress = officeLoc['officeAddress'].toString();
        }
        if (officeLoc['geofenceRadiusMeters'] != null) {
          _geofenceRadiusMeters = (officeLoc['geofenceRadiusMeters'] as num).toDouble();
        }
      }

      // Process Shift Info
      if (shift.isNotEmpty) {
        final sName = shift['name']?.toString() ?? shift['shiftName']?.toString();
        final sStart = shift['startTime']?.toString() ?? shift['shiftStartTime']?.toString();
        final sEnd = shift['endTime']?.toString() ?? shift['shiftEndTime']?.toString();
        if (sName != null && sName.isNotEmpty) _shiftName = sName;
        if (sStart != null && sStart.isNotEmpty) _shiftStartTime = sStart;
        if (sEnd != null && sEnd.isNotEmpty) _shiftEndTime = sEnd;
      }

      // Process Today's Attendance Record
      if (record is Map && record.isNotEmpty) {
        _todayRecord = Map<String, dynamic>.from(record);

        final checkInStr = _extractFirst(record, [
          'checkIn', 'checkInTime', 'punchIn', 'punchInTime', 'clockIn', 'checkInAt', 'inTime'
        ]);
        final checkOutStr = _extractFirst(record, [
          'checkOut', 'checkOutTime', 'punchOut', 'punchOutTime', 'clockOut', 'checkOutAt', 'outTime'
        ]);

        final statusStr = _extractFirst(record, ['status', 'attendanceStatus'])?.toUpperCase();
        final isOnBreakVal = record['isOnBreak'] == true ||
            record['onBreak'] == true ||
            statusStr == 'BREAK' ||
            statusStr == 'ON_BREAK';

        final breakStartStr = _extractFirst(record, [
          'activeBreakStart', 'breakStart', 'breakStartTime', 'lastBreakStart'
        ]);

        final inLoc = _extractFirst(record, [
          'checkInLocation', 'location', 'checkInAddress', 'officeLocation'
        ]);
        final outLoc = _extractFirst(record, [
          'checkOutLocation', 'checkOutAddress'
        ]);

        final breakMinsVal = record['totalBreakMinutes'] ?? record['breakMinutes'] ?? record['breakDurationMinutes'];
        double breakMinutesNum = 0;
        if (breakMinsVal is num) {
          breakMinutesNum = breakMinsVal.toDouble();
        } else if (breakMinsVal != null) {
          breakMinutesNum = double.tryParse(breakMinsVal.toString()) ?? 0;
        }

        _checkInAt = checkInStr != null && checkInStr.trim().isNotEmpty
            ? DateTime.tryParse(checkInStr)?.toLocal()
            : null;
        _checkOutAt = checkOutStr != null && checkOutStr.trim().isNotEmpty
            ? DateTime.tryParse(checkOutStr)?.toLocal()
            : null;

        _isOnBreak = isOnBreakVal;
        _breakStartedAt = breakStartStr != null && breakStartStr.trim().isNotEmpty
            ? DateTime.tryParse(breakStartStr)?.toLocal()
            : null;

        _completedBreak = Duration(seconds: (breakMinutesNum * 60).round());

        if (inLoc != null && inLoc.isNotEmpty) _checkInLocation = inLoc;
        if (outLoc != null && outLoc.isNotEmpty) _checkOutLocation = outLoc;
      } else {
        _checkInAt = null;
        _checkOutAt = null;
        _isOnBreak = false;
        _breakStartedAt = null;
        _completedBreak = Duration.zero;
      }

      // Process 30-Day History Stats
      _attendanceHistory = historyList;
      _calculateOverviewStats(historyList, summaryData);

      _isLoading = false;
    } catch (e) {
      if (!mounted) return;
      _isLoading = false;
      _error = e.toString().replaceFirst('ApiException: ', '').replaceFirst('Exception: ', '');
    }

    // Refresh Live GPS
    _fetchLiveGpsLocation();
  }

  void _calculateOverviewStats(List<dynamic> history, [dynamic summaryRaw]) {
    if (summaryRaw is Map && summaryRaw.isNotEmpty) {
      final pDays = summaryRaw['presentDays'] ?? summaryRaw['presentCount'] ?? summaryRaw['present'];
      final aDays = summaryRaw['absentDays'] ?? summaryRaw['absentCount'] ?? summaryRaw['absent'] ?? summaryRaw['leavesCount'];
      final lIns = summaryRaw['lateClockIns'] ?? summaryRaw['lateCount'] ?? summaryRaw['lateIn'] ?? summaryRaw['late'];
      final rate = summaryRaw['attendanceRate'] ?? summaryRaw['attendanceRatePercent'] ?? summaryRaw['percentage'];
      final hrs = summaryRaw['totalLoggedHours'] ?? summaryRaw['hoursLogged'] ?? summaryRaw['totalHours'] ?? summaryRaw['loggedHours'];

      if (pDays != null) _presentDays = (pDays as num).toInt();
      if (aDays != null) _absentDays = (aDays as num).toInt();
      if (lIns != null) _lateClockIns = (lIns as num).toInt();
      if (rate != null) _attendanceRatePercent = (rate as num).toDouble();
      if (hrs != null) {
        final hrsVal = (hrs as num).toDouble();
        _hoursLoggedBadge = '${hrsVal.toStringAsFixed(2)}h logged';
      }
      return;
    }

    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;

    for (final item in history) {
      if (item is Map) {
        final status = (item['status'] ?? item['attendanceStatus'] ?? '').toString().toUpperCase();
        final lateMins = item['lateDurationMinutes'] ?? item['lateMinutes'] ?? item['lateInMinutes'];
        final isLateFlag = item['isLate'] == true || item['late'] == true || status == 'LATE' || status.contains('LATE');

        if (status.contains('PRESENT') || status.contains('WORK') || status == 'ON_TIME' || status == 'REGULAR') {
          presentCount++;
        } else if (status.contains('ABSENT') || status == 'LEAVE' || status == 'ON_LEAVE') {
          absentCount++;
        } else if (status.contains('HALF') || status.contains('PARTIAL')) {
          presentCount++;
        }

        if (isLateFlag || (lateMins != null && (lateMins as num) > 0)) {
          lateCount++;
        }
      }
    }

    final totalDays = math.max(1, history.length);
    _presentDays = presentCount;
    _absentDays = absentCount;
    _lateClockIns = lateCount;
    _attendanceRatePercent = (presentCount / totalDays * 100).roundToDouble();
  }

  Future<void> _fetchLiveGpsLocation() async {
    if (!mounted) return;
    setState(() {
      _gpsStatusMessage = 'Detecting GPS signal & location address...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _gpsStatusMessage = 'GPS disabled. Please enable device location.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _gpsStatusMessage = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _gpsStatusMessage = 'Location permission permanently denied in settings.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      // Haversine Distance to Office HQ (exact check-in-out.component.ts formula)
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _officeLat,
        _officeLng,
      );

      final isWithin = distance <= _geofenceRadiusMeters;
      final distStr = distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(2)}km'
          : '${distance.round()}m';

      setState(() {
        _currentPosition = position;
        _distanceFromOfficeMeters = distance;
        _isWithinGeofence = isWithin;
        _gpsStatusMessage = isWithin
            ? 'Inside Geofence ($distStr from office)'
            : 'Outside Geofence ($distStr from office, limit: ${_geofenceRadiusMeters.round()}m)';

        _currentAddress = 'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)} (±${position.accuracy.round()}m)';

        if (_checkInAt == null) {
          _checkInLocation = isWithin
              ? 'Office Location ($_officeName)'
              : 'Remote Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        }
      });

      // Try server-side geofence validation
      try {
        final val = await _attendanceApi.validateGeofence(
          latitude: position.latitude,
          longitude: position.longitude,
          location: 'Mobile Device',
        );
        if (val is Map && mounted) {
          setState(() {
            if (val['isWithinGeofence'] != null) {
              _isWithinGeofence = val['isWithinGeofence'] == true;
            }
            if (val['distanceFromOffice'] != null) {
              _distanceFromOfficeMeters = (val['distanceFromOffice'] as num).toDouble();
            }
          });
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsStatusMessage = 'GPS detection failed: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF252827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${_two(hour)}:${_two(value.minute)} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
  }

  String get _dateLabel {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${weekdays[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}, ${_now.year}';
  }

  String get checkedStatusLabel {
    if (_isOnBreak) return 'ON BREAK';
    if (_checkOutAt != null) return 'SHIFT COMPLETED';
    if (_checkInAt != null) {
      final mode = _todayRecord['workMode']?.toString().toUpperCase();
      return mode == 'WFH' || mode == 'WORK_FROM_HOME' ? 'PRESENT (WFH)' : 'CHECKED IN';
    }
    return 'NOT CHECKED IN';
  }

  // ==================== WORKFLOW ACTIONS ====================

  Future<void> _handleClockInTap() async {
    if (_isOnBreak) {
      _showMessage('End your break before clocking out.', isError: true);
      return;
    }

    if (_checkedIn) {
      _openClockOutModal();
      return;
    }

    _openClockInModal();
  }

  void _openClockInModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ClockInModal(
        now: _now,
        officeName: _officeName,
        geofenceRadiusMeters: _geofenceRadiusMeters,
        currentPosition: _currentPosition,
        isWithinGeofence: _isWithinGeofence,
        gpsStatusMessage: _gpsStatusMessage,
        imagePicker: _imagePicker,
        onClockInSubmit: (workMode, wfhReason, selfieBase64, isGallery) async {
          Navigator.pop(ctx);
          await _executeClockIn(
            workMode: workMode,
            wfhReason: wfhReason,
            selfieBase64: selfieBase64,
            isGallery: isGallery,
          );
        },
      ),
    );
  }

  Future<void> _executeClockIn({
    required String workMode,
    String? wfhReason,
    String? selfieBase64,
    bool isGallery = false,
  }) async {
    setState(() => _isActionInProgress = true);

    try {
      final pos = _currentPosition;
      final loc = pos != null
          ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}'
          : 'Mobile App Check-In';

      await _attendanceApi.punchIn(
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        location: loc,
        notes: 'Punched in from mobile app',
        capturedFaceBase64: selfieBase64,
        verificationType: 'CLOCK_IN',
        workMode: workMode,
        wfhReason: wfhReason,
        isGalleryUpload: isGallery,
      );

      _showMessage('Clocked in successfully!');
      await _loadAllData();
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'Clock-in failed: ${e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _openClockOutModal() {
    final workedHours = _workDuration.inHours;
    final isHalfDayEligible = workedHours >= 4 ||
        _todayRecord['workMode'] == 'HALF_DAY' ||
        _todayRecord['isHalfDay'] == true;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isHalfDayEligible && workedHours < 8
            ? 'Confirm Half-Day Clock Out'
            : 'Confirm Clock Out'),
        content: Text(
          isHalfDayEligible && workedHours < 8
              ? 'You have completed ${workedHours}h ${_workDuration.inMinutes.remainder(60)}m today (Half-Day threshold met). Ready to clock out now?'
              : 'Are you ready to end your workday? Your check-out time will be recorded on the server.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeClockOut(isHalfDayOverride: isHalfDayEligible);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.copper),
            child: const Text('Clock Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeClockOut({bool isHalfDayOverride = false}) async {
    setState(() => _isActionInProgress = true);
    try {
      final pos = _currentPosition;
      final loc = pos != null
          ? 'Lat: ${pos.latitude.toStringAsFixed(4)}, Lng: ${pos.longitude.toStringAsFixed(4)}'
          : 'Mobile App Check-Out';

      final isLess8Hrs = _workDuration.inHours < 8;
      final workModeToUse = (isHalfDayOverride || isLess8Hrs || _todayRecord['workMode'] == 'HALF_DAY')
          ? 'HALF_DAY'
          : (_todayRecord['workMode']?.toString() ?? 'OFFICE');

      final notesToUse = (isHalfDayOverride || isLess8Hrs)
          ? 'Half Day Check-Out (${_workDuration.inHours}h ${_workDuration.inMinutes.remainder(60)}m worked) - Security Passcode: 1234'
          : 'Punched out from mobile app';

      await _attendanceApi.punchOut(
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        location: loc,
        notes: notesToUse,
        verificationType: 'CLOCK_OUT',
        workMode: workModeToUse,
        wfhReason: 'Half day check-out authorized',
      );

      _showMessage('Clocked out successfully!');
      await _loadAllData();
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "");
      if (errStr.contains('8.00 net working hours') ||
          errStr.contains('complete at least') ||
          errStr.contains('Status: 400')) {
        _showEarlyCheckoutOverrideDialog(errStr);
      } else {
        _showMessage('Clock-out failed: $errStr', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _showEarlyCheckoutOverrideDialog(String serverMsg) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.copper, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Early / Half-Day Check-Out Override',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Server Policy: Net work duration is under 8.0 hours (${_workDuration.inHours}h ${_workDuration.inMinutes.remainder(60)}m worked).\n\nChoose an override option below:',
                style: const TextStyle(fontSize: 11.5, height: 1.35),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _executeClockOut(isHalfDayOverride: true);
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Clock Out with Security Passcode (1234)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.copper,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _openRegularizationModal();
              },
              icon: const Icon(Icons.edit_calendar_rounded, size: 18),
              label: const Text('Submit Instant Regularization Request'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBreak() async {
    if (!_checkedIn) {
      _showMessage('Clock in before starting a break.', isError: true);
      return;
    }
    if (_checkOutAt != null) {
      _showMessage('Your workday is already complete.', isError: true);
      return;
    }

    setState(() => _isActionInProgress = true);
    try {
      if (_isOnBreak) {
        await _attendanceApi.endBreak();
        _showMessage('Break ended successfully.');
      } else {
        await _attendanceApi.startBreak(
          breakType: 'SHORT',
          reason: 'Mobile app break',
        );
        _showMessage('Break started successfully.');
      }
      await _loadAllData();
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'Break action failed: ${e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _openRegularizationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegularizationModal(
        employeeId: _employeeId,
        todayRecord: _todayRecord,
        onSubmit: (payload) async {
          Navigator.pop(ctx);
          setState(() => _isActionInProgress = true);
          try {
            await _attendanceApi.requestCorrection(payload);
            _showMessage('Correction request submitted successfully.');
            await _loadAllData();
          } catch (e) {
            if (!mounted) return;
            _showMessage(
              'Submission failed: ${e.toString().replaceFirst("ApiException: ", "").replaceFirst("Exception: ", "")}',
              isError: true,
            );
          } finally {
            if (mounted) setState(() => _isActionInProgress = false);
          }
        },
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        final textColor = AppColors.text(dark);
        final mutedColor = AppColors.muted(dark);
        final accent = AppColors.accentText(dark);

        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadAllData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Punch In / Out',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Track your daily work hours, shift attendance & camera selfie logs',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildRefreshButton(dark, accent),
                          ],
                        ),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(color: textColor, fontSize: 12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildCurrentTimeCard(dark, textColor, mutedColor, accent),
                        const SizedBox(height: 14),
                        if (_isPostShiftWarning30m) ...[
                          _buildPostShiftWarningBanner(dark, textColor),
                          const SizedBox(height: 14),
                        ],
                        _buildGeofenceMapCard(dark, textColor, mutedColor, accent),
                        const SizedBox(height: 14),
                        _buildEmployeeInfoBar(dark, textColor, mutedColor),
                        const SizedBox(height: 14),
                        _buildMainActionCard(dark, textColor, mutedColor, accent),
                        const SizedBox(height: 14),
                        _buildStatMetricsRow(dark, textColor, mutedColor, accent),
                        const SizedBox(height: 14),
                        _buildQuickActionButtons(dark, accent),
                        const SizedBox(height: 18),
                        _build30DayOverviewCard(dark, textColor, mutedColor),
                        const SizedBox(height: 18),
                        _buildTodayActivityCard(dark, textColor, mutedColor, accent),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'SERVER SYNCED  •  LIVE ATTENDANCE PROTOCOL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 9,
                              letterSpacing: 1.1,
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

  Widget _buildRefreshButton(bool dark, Color accent) {
    return Material(
      color: AppColors.fieldFill(dark),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _loadAllData,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.refresh_rounded, color: accent, size: 20),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeCard(bool dark, Color text, Color muted, Color accent) {
    final surfaceTop = dark ? const Color(0xE62A2D2E) : const Color(0xF5FFFFFF);
    final surfaceBottom = dark ? const Color(0xE61B1D1F) : const Color(0xE8F5F1EB);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaceTop, surfaceBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder(dark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.20 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waving_hand_rounded, color: AppColors.copper, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Good ${_now.hour < 12 ? "Morning" : _now.hour < 17 ? "Afternoon" : "Evening"}, $_employeeName',
                  style: TextStyle(
                    color: text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: dark ? 0.20 : 0.12),
                  border: Border.all(color: AppColors.copper.withValues(alpha: 0.30)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  checkedStatusLabel,
                  style: TextStyle(
                    color: AppColors.accentText(dark),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT TIME',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _time(_now),
                    style: TextStyle(
                      color: text,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.calendar_month_rounded, color: muted, size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _dateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_shiftName ($_shiftStartTime – $_shiftEndTime)',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostShiftWarningBanner(bool dark, Color text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⏰ Missed Check-Out Warning (30+ Mins Post-Shift)',
                  style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your shift ended at $_shiftEndTime. Please record your check-out to prevent auto-absent cutoff.',
                  style: TextStyle(color: text.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openClockOutModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Check Out', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceMapCard(bool dark, Color text, Color muted, Color accent) {
    final officeLatLng = LatLng(_officeLat, _officeLng);
    final userLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : officeLatLng;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar matching Web check-in-out.component.html
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (_isWithinGeofence ? const Color(0xFF10B981) : AppColors.copper)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isWithinGeofence ? Icons.location_on_rounded : Icons.wrong_location_rounded,
                        color: _isWithinGeofence ? const Color(0xFF10B981) : AppColors.copper,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                'Live Geofence Map',
                                style: TextStyle(
                                  color: text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE GPS SYNC',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_officeName: $_officeAddress (Radius: ${_geofenceRadiusMeters.round()}m) You: $_distanceDisplay',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _showMapCard = !_showMapCard),
                      icon: Icon(
                        _showMapCard ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                if (_showMapCard) ...[
                  const SizedBox(height: 10),
                  // Map Control Buttons Row matching Web
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _mapControlPill(
                          dark,
                          label: 'Focus Company',
                          icon: Icons.apartment_rounded,
                          color: const Color(0xFF4F46E5),
                          onTap: () {
                            _googleMapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(officeLatLng, 15.5),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _mapControlPill(
                          dark,
                          label: 'Focus Me',
                          icon: Icons.my_location_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () {
                            if (_currentPosition != null) {
                              _googleMapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(userLatLng, 16.0),
                              );
                            } else {
                              _fetchLiveGpsLocation();
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        _mapControlPill(
                          dark,
                          label: 'Fit Both',
                          icon: Icons.fit_screen_rounded,
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            if (_currentPosition != null) {
                              final southWest = LatLng(
                                math.min(_officeLat, _currentPosition!.latitude),
                                math.min(_officeLng, _currentPosition!.longitude),
                              );
                              final northEast = LatLng(
                                math.max(_officeLat, _currentPosition!.latitude),
                                math.max(_officeLng, _currentPosition!.longitude),
                              );
                              final bounds = LatLngBounds(southwest: southWest, northeast: northEast);
                              _googleMapController?.animateCamera(
                                CameraUpdate.newLatLngBounds(bounds, 50.0),
                              );
                            } else {
                              _googleMapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(officeLatLng, 15.0),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        // Tile Selectors
                        _tileTypeChip(dark, 'Streets'),
                        const SizedBox(width: 4),
                        _tileTypeChip(dark, 'Satellite'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_showMapCard) ...[
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) => _googleMapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: officeLatLng,
                      zoom: 15.0,
                    ),
                    mapType: _selectedTileType == 'Satellite'
                        ? MapType.satellite
                        : MapType.normal,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: true,
                    circles: {
                      Circle(
                        circleId: const CircleId('geofence_perimeter'),
                        center: officeLatLng,
                        radius: _geofenceRadiusMeters,
                        fillColor: const Color(0x334F46E5),
                        strokeColor: const Color(0xFF4F46E5),
                        strokeWidth: 2,
                      ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('office_hq'),
                        position: officeLatLng,
                        infoWindow: InfoWindow(
                          title: '🏢 $_officeName',
                          snippet: _officeAddress,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                      ),
                      if (_currentPosition != null)
                        Marker(
                          markerId: const MarkerId('user_position'),
                          position: userLatLng,
                          infoWindow: InfoWindow(
                            title: '📍 YOU (LIVE GPS)',
                            snippet: _distanceDisplay,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            _isWithinGeofence ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                          ),
                        ),
                    },
                  ),
                  // Map Zoom Buttons Overlay (Top Right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _googleMapController?.animateCamera(CameraUpdate.zoomIn());
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: dark ? const Color(0xDD1B1D1F) : const Color(0xEEFFFFFF),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.glassBorder(dark)),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(Icons.add_rounded, size: 18, color: text),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _googleMapController?.animateCamera(CameraUpdate.zoomOut());
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: dark ? const Color(0xDD1B1D1F) : const Color(0xEEFFFFFF),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.glassBorder(dark)),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(Icons.remove_rounded, size: 18, color: text),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Map Bottom Overlay Bar matching Web check-in-out.component.html
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: dark ? const Color(0xFF181B1D) : const Color(0xFFF1F5F9),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _mapOverlayPill(
                      dark,
                      icon: Icons.gps_fixed_rounded,
                      label: 'Live GPS: ${_currentPosition != null ? _currentAddress : "Detecting..."}',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    _mapOverlayPill(
                      dark,
                      icon: Icons.apartment_rounded,
                      label: 'Company: $_officeName [${_geofenceRadiusMeters.round()}m]',
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 6),
                    _mapOverlayPill(
                      dark,
                      icon: _isWithinGeofence ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      label: _isWithinGeofence
                          ? 'INSIDE GEOFENCE — ${_distanceFromOfficeMeters.round()}m from office'
                          : 'OUTSIDE GEOFENCE — ${_distanceFromOfficeMeters.round()}m from office (${(_distanceFromOfficeMeters - _geofenceRadiusMeters).round()}m beyond ${_geofenceRadiusMeters.round()}m radius)',
                      color: _isWithinGeofence ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            // Legend & Directions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.fieldFill(dark),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _legendDot(const Color(0xFF4F46E5), 'Company Location'),
                      _legendDot(const Color(0xFF10B981), '${_geofenceRadiusMeters.round()}m Radius'),
                      _legendDot(const Color(0xFFEC4899), 'Your Live Location'),
                      _legendDot(const Color(0xFF8B5CF6), 'Distance: $_distanceDisplay'),
                    ],
                  ),
                  InkWell(
                    onTap: _fetchLiveGpsLocation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.copper),
                        const SizedBox(width: 4),
                        Text(
                          'Refresh GPS',
                          style: TextStyle(color: AppColors.copper, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapControlPill(bool dark, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileTypeChip(bool dark, String type) {
    final selected = _selectedTileType == type;
    return ChoiceChip(
      label: Text(type),
      selected: selected,
      selectedColor: AppColors.copper,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text(dark),
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: AppColors.fieldFill(dark),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _selectedTileType = type),
    );
  }

  Widget _mapOverlayPill(bool dark, {required IconData icon, required String label, required Color color, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEmployeeInfoBar(bool dark, Color text, Color muted) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.copper,
            backgroundImage: _avatar.isNotEmpty ? NetworkImage(_avatar) : null,
            child: _avatar.isEmpty
                ? Text(
                    _employeeName.isNotEmpty ? _employeeName[0].toUpperCase() : 'E',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _employeeName,
                  style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  '$_designation • $_department',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionCard(bool dark, Color text, Color muted, Color accent) {
    final buttonLabel = !_checkedIn ? 'CLOCK IN (CAMERA SELFIE)' : 'CLOCK OUT';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.camera_alt_rounded, color: AppColors.copper, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_checkedIn
                          ? 'Ready to Check In'
                          : _checkOutAt != null
                              ? 'Workday Completed'
                              : _isOnBreak
                                  ? 'Working Now (On Break)'
                                  : 'Working Now',
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      !_checkedIn
                          ? 'Snap selfie inside office perimeter to clock in.'
                          : _checkOutAt != null
                              ? 'Your shift has ended for today.'
                              : 'Working since ${_time(_checkInAt)} | Shift End: $_shiftEndTime',
                      style: TextStyle(color: muted, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _checkOutAt != null || _isActionInProgress ? null : _handleClockInTap,
                    icon: _isActionInProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(!_checkedIn ? Icons.login_rounded : Icons.logout_rounded, size: 18),
                    label: Text(
                      _isActionInProgress ? 'PROCESSING...' : buttonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.3),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.copper,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.fieldFill(dark),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: !_checkedIn || _checkOutAt != null || _isActionInProgress ? null : _toggleBreak,
                    icon: Icon(_isOnBreak ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 16),
                    label: Text(
                      _isOnBreak ? 'End Break' : 'Start Break',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: AppColors.glassBorder(dark)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetricsRow(bool dark, Color text, Color muted, Color accent) {
    final remaining = const Duration(hours: 8) - _workDuration;
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;

    return Row(
      children: [
        Expanded(
          child: _metricCard(
            dark, text, muted,
            icon: Icons.work_history_rounded,
            label: 'WORKED',
            value: _duration(_workDuration),
            iconColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            dark, text, muted,
            icon: Icons.hourglass_bottom_rounded,
            label: 'REMAINING',
            value: _duration(safeRemaining),
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            dark, text, muted,
            icon: Icons.login_rounded,
            label: 'CHECK IN',
            value: _time(_checkInAt),
            iconColor: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            dark, text, muted,
            icon: Icons.logout_rounded,
            label: 'CHECK OUT',
            value: _time(_checkOutAt),
            iconColor: const Color(0xFFEC4899),
          ),
        ),
      ],
    );
  }

  Widget _metricCard(
    bool dark, Color text, Color muted, {
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(bool dark, Color accent) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApplyLeavePage()),
              );
            },
            icon: const Icon(Icons.umbrella_rounded, size: 16),
            label: const Text('Apply Leave', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.glassBorder(dark)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openRegularizationModal,
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: const Text('Regularize', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppColors.glassBorder(dark)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _build30DayOverviewCard(bool dark, Color text, Color muted) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '30-Day Attendance Overview',
                style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendancePage()),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'My Attendance >',
                    style: TextStyle(color: AppColors.copper, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _overviewTile(
                  dark, text, muted,
                  title: 'Present Days',
                  value: '$_presentDays',
                  badge: 'of ${_attendanceHistory.isNotEmpty ? _attendanceHistory.length : 27} days',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _overviewTile(
                  dark, text, muted,
                  title: 'Attendance Rate',
                  value: '${_attendanceRatePercent.toInt()}%',
                  badge: _hoursLoggedBadge,
                  icon: Icons.pie_chart_outline_rounded,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _overviewTile(
                  dark, text, muted,
                  title: 'Absent / Leaves',
                  value: '$_absentDays',
                  badge: '$_absentDays days off',
                  icon: Icons.event_busy_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _overviewTile(
                  dark, text, muted,
                  title: 'Late Clock-Ins',
                  value: '$_lateClockIns',
                  badge: 'After grace period',
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewTile(
    bool dark, Color text, Color muted, {
    required String title,
    required String value,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (dark ? Colors.black : Colors.white).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTodayActivityCard(bool dark, Color text, Color muted, Color accent) {
    final hasActivity = _checkInAt != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Attendance Activity",
            style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (!hasActivity)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.event_note_rounded, size: 36, color: muted.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text('No attendance recorded today yet.', style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            )
          else ...[
            _activityRow(
              dark,
              icon: Icons.login_rounded,
              title: 'Check-In',
              time: _time(_checkInAt),
              location: _checkInLocation,
              color: const Color(0xFF10B981),
              text: text,
              muted: muted,
            ),
            if (_completedBreak > Duration.zero || _isOnBreak)
              _activityRow(
                dark,
                icon: Icons.coffee_rounded,
                title: _isOnBreak ? 'Break (Active)' : 'Break Duration',
                time: _duration(_breakDuration),
                location: 'Total Break Time',
                color: const Color(0xFFF59E0B),
                text: text,
                muted: muted,
              ),
            if (_checkOutAt != null)
              _activityRow(
                dark,
                icon: Icons.logout_rounded,
                title: 'Check-Out',
                time: _time(_checkOutAt),
                location: _checkOutLocation,
                color: const Color(0xFFEC4899),
                text: text,
                muted: muted,
              ),
          ],
        ],
      ),
    );
  }

  Widget _activityRow(
    bool dark, {
    required IconData icon,
    required String title,
    required String time,
    required String location,
    required Color color,
    required Color text,
    required Color muted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 13)),
                Text(location, style: TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

// ==================== CLOCK-IN MODAL WITH SELFIE & WORK MODE ====================

class _ClockInModal extends StatefulWidget {
  final DateTime now;
  final String officeName;
  final double geofenceRadiusMeters;
  final Position? currentPosition;
  final bool isWithinGeofence;
  final String gpsStatusMessage;
  final ImagePicker imagePicker;
  final Function(String workMode, String? wfhReason, String? selfieBase64, bool isGallery) onClockInSubmit;

  const _ClockInModal({
    required this.now,
    required this.officeName,
    required this.geofenceRadiusMeters,
    required this.currentPosition,
    required this.isWithinGeofence,
    required this.gpsStatusMessage,
    required this.imagePicker,
    required this.onClockInSubmit,
  });

  @override
  State<_ClockInModal> createState() => _ClockInModalState();
}

class _ClockInModalState extends State<_ClockInModal> {
  String _workMode = 'OFFICE'; // 'OFFICE' or 'WFH'
  final TextEditingController _wfhReasonController = TextEditingController();
  XFile? _capturedSelfie;
  String? _selfieBase64;
  bool _isGalleryUpload = false;
  bool _isCameraLoading = false;

  @override
  void dispose() {
    _wfhReasonController.dispose();
    super.dispose();
  }

  Future<void> _takeSelfie(ImageSource source) async {
    setState(() => _isCameraLoading = true);
    try {
      final image = await widget.imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _capturedSelfie = image;
          _selfieBase64 = base64Str;
          _isGalleryUpload = (source == ImageSource.gallery);
          _isCameraLoading = false;
        });
      } else {
        setState(() => _isCameraLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCameraLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');
  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${_two(hour)}:${_two(value.minute)}:${_two(value.second)} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDarkMode.value;
    final text = AppColors.text(dark);
    final muted = AppColors.muted(dark);

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: dark ? AppColors.graphite : AppColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Face Verification (Clock In)',
                  style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Alert Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Face Verification Required: Snap your live front-camera selfie inside the office perimeter to clock in.',
                      style: TextStyle(color: text, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Check-in Time
            Row(
              children: [
                Text('Check-In Time:', style: TextStyle(color: muted, fontSize: 12)),
                const Spacer(),
                Text(_time(widget.now), style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Select Work Mode', style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('Office (${widget.geofenceRadiusMeters.round()}m Geofence)'),
                    selected: _workMode == 'OFFICE',
                    onSelected: (sel) => setState(() => _workMode = 'OFFICE'),
                    selectedColor: AppColors.copper,
                    labelStyle: TextStyle(
                      color: _workMode == 'OFFICE' ? Colors.white : text,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Work From Home'),
                    selected: _workMode == 'WFH',
                    onSelected: (sel) => setState(() => _workMode = 'WFH'),
                    selectedColor: AppColors.copper,
                    labelStyle: TextStyle(
                      color: _workMode == 'WFH' ? Colors.white : text,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_workMode == 'WFH') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _wfhReasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for WFH',
                  hintText: 'Enter justification for working remotely...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Live Camera Selfie', style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 200,
                  height: 200,
                  color: AppColors.fieldFill(dark),
                  child: _isCameraLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.copper))
                      : _capturedSelfie != null
                          ? Image.file(File(_capturedSelfie!.path), fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_pin_rounded, size: 48, color: muted),
                                const SizedBox(height: 8),
                                Text('No Selfie Captured', style: TextStyle(color: muted, fontSize: 12)),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _takeSelfie(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Camera Selfie'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _takeSelfie(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery Upload'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onClockInSubmit(
                    _workMode,
                    _workMode == 'WFH' ? _wfhReasonController.text.trim() : null,
                    _selfieBase64,
                    _isGalleryUpload,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'CONFIRM CLOCK IN',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ==================== REGULARIZATION / CORRECTION MODAL ====================

class _RegularizationModal extends StatefulWidget {
  final String employeeId;
  final Map<String, dynamic> todayRecord;
  final Function(Map<String, dynamic> payload) onSubmit;

  const _RegularizationModal({
    required this.employeeId,
    required this.todayRecord,
    required this.onSubmit,
  });

  @override
  State<_RegularizationModal> createState() => _RegularizationModalState();
}

class _RegularizationModalState extends State<_RegularizationModal> {
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _correctedCheckIn = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _correctedCheckOut = const TimeOfDay(hour: 18, minute: 0);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isIn ? _correctedCheckIn : _correctedCheckOut,
    );
    if (picked != null) {
      setState(() {
        if (isIn) {
          _correctedCheckIn = picked;
        } else {
          _correctedCheckOut = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final dt = DateTime(2026, 1, 1, tod.hour, tod.minute);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDarkMode.value;
    final text = AppColors.text(dark);
    final muted = AppColors.muted(dark);

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.only(
        top: 20, left: 20, right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: dark ? AppColors.graphite : AppColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Regularize Attendance',
                  style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Target Date: $dateStr', style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: const Text('Change Date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('In: ${_formatTimeOfDay(_correctedCheckIn)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('Out: ${_formatTimeOfDay(_correctedCheckOut)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason for Regularization',
                hintText: 'Forgot to clock in, device battery died, etc...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final payload = {
                    'employeeId': widget.employeeId,
                    'date': dateStr,
                    'correctedCheckIn': _formatTimeOfDay(_correctedCheckIn),
                    'correctedCheckOut': _formatTimeOfDay(_correctedCheckOut),
                    'reason': _reasonController.text.trim(),
                  };
                  widget.onSubmit(payload);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('SUBMIT REGULARIZATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
