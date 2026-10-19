import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/attendance_api_service.dart';
import '../services/profile_api_service.dart';

class BreakTrackerPage extends StatefulWidget {
  const BreakTrackerPage({super.key});

  @override
  State<BreakTrackerPage> createState() => _BreakTrackerPageState();
}

class _BreakTrackerPageState extends State<BreakTrackerPage> {
  final AttendanceApiService _attendanceApi = AttendanceApiService();
  final ProfileApiService _profileApi = ProfileApiService();

  bool _isOnBreak = false;
  String _activeBreakType = 'Lunch Break';
  DateTime? _breakStartTime;
  Timer? _breakTimer;
  Duration _elapsed = Duration.zero;

  String _selectedType = 'Lunch Break';
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _error;

  List<Map<String, dynamic>> _breakLogs = [];

  @override
  void initState() {
    super.initState();
    _loadTodayStatus();
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _profileApi.getMyProfile();
      final employeeId = ProfileApiService.extractEmployeeId(profile);

      final results = await Future.wait([
        _attendanceApi.getTodayAttendance(employeeId: employeeId),
        _attendanceApi.getAttendanceHistory(),
      ]);

      if (!mounted) return;

      final record = results[0];
      final history = results[1];

      if (record is Map && record.isNotEmpty) {
        final statusStr = record['status']?.toString().toUpperCase();
        final isOnBreakVal =
            record['isOnBreak'] == true ||
            record['onBreak'] == true ||
            statusStr == 'BREAK' ||
            statusStr == 'ON_BREAK';

        final breakStartStr =
            record['activeBreakStart']?.toString() ??
            record['breakStart']?.toString() ??
            record['breakStartTime']?.toString();

        DateTime? parsedStart;
        if (breakStartStr != null) {
          parsedStart = DateTime.tryParse(breakStartStr);
        }

        if (isOnBreakVal) {
          _isOnBreak = true;
          _breakStartTime = parsedStart ?? DateTime.now();
          _startTimer();
        } else {
          _isOnBreak = false;
          _breakTimer?.cancel();
          _elapsed = Duration.zero;
        }

        final rawBreaks =
            record['breaks'] ?? record['breakLogs'] ?? record['breakHistory'];
        if (rawBreaks is List && rawBreaks.isNotEmpty) {
          _breakLogs = rawBreaks.whereType<Map>().map((b) {
            final bMap = Map<String, dynamic>.from(b);
            final type =
                bMap['breakType']?.toString() ?? bMap['type']?.toString() ?? 'Break';
            final start =
                bMap['startTime']?.toString() ?? bMap['checkIn']?.toString() ?? '';
            final end =
                bMap['endTime']?.toString() ??
                bMap['checkOut']?.toString() ??
                'Active';
            final durationStr =
                end == 'Active' ? 'In Progress' : _calculateBreakDuration(bMap);
            return <String, dynamic>{
              'id': bMap['id']?.toString() ?? 'BRK-${_breakLogs.length + 1}',
              'date': 'Today',
              'type': type,
              'startTime': _formatTimeString(start),
              'endTime': end == 'Active' ? 'Active' : _formatTimeString(end),
              'duration': durationStr,
              'status': end == 'Active' ? 'In Progress' : 'Completed',
            };
          }).toList();
        }
      }

      // If break logs empty from today's record, extract break history from general attendance history
      if (_breakLogs.isEmpty && history != null) {
        final list = history is List ? history : (history is Map && history['data'] is List ? history['data'] as List : []);
        final collected = <Map<String, dynamic>>[];
        for (final item in list) {
          if (item is Map && item['breaks'] is List) {
            final dateVal = item['date']?.toString() ?? 'Recent';
            for (final b in (item['breaks'] as List)) {
              if (b is Map) {
                final bMap = Map<String, dynamic>.from(b);
                final type = bMap['breakType']?.toString() ?? bMap['type']?.toString() ?? 'Break';
                final start = bMap['startTime']?.toString() ?? '';
                final end = bMap['endTime']?.toString() ?? '';
                final duration = _calculateBreakDuration(bMap);
                collected.add({
                  'id': bMap['id']?.toString() ?? 'BRK-${collected.length + 1}',
                  'date': dateVal.contains('T') ? dateVal.split('T')[0] : dateVal,
                  'type': type,
                  'startTime': _formatTimeString(start),
                  'endTime': end.isEmpty || end == 'Active' ? 'Active' : _formatTimeString(end),
                  'duration': duration,
                  'status': 'Completed',
                });
              }
            }
          }
        }
        _breakLogs = collected;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  void _startTimer() {
    _breakTimer?.cancel();
    if (_breakStartTime == null) _breakStartTime = DateTime.now();
    _elapsed = DateTime.now().difference(_breakStartTime!);

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_breakStartTime!);
      });
    });
  }

  Future<void> _startBreak() async {
    if (_isActionInProgress) return;
    setState(() {
      _isActionInProgress = true;
      _error = null;
    });

    try {
      await _attendanceApi.startBreak(
        breakType: _selectedType.toUpperCase().replaceAll(' ', '_'),
        reason: 'Employee requested $_selectedType',
      );

      if (!mounted) return;

      setState(() {
        _isOnBreak = true;
        _activeBreakType = _selectedType;
        _breakStartTime = DateTime.now();
        _elapsed = Duration.zero;
        _isActionInProgress = false;
      });

      _startTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started $_selectedType'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      _loadTodayStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isActionInProgress = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Failed to start break')),
      );
    }
  }

  Future<void> _endBreak() async {
    if (_isActionInProgress) return;
    setState(() {
      _isActionInProgress = true;
      _error = null;
    });

    try {
      await _attendanceApi.endBreak();

      if (!mounted) return;

      _breakTimer?.cancel();

      setState(() {
        _isOnBreak = false;
        _breakStartTime = null;
        _elapsed = Duration.zero;
        _isActionInProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Break ended successfully'),
          backgroundColor: Color(0xFF1565C0),
        ),
      );

      _loadTodayStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isActionInProgress = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_error ?? 'Failed to end break')));
    }
  }

  String _formatTimeString(String isoStr) {
    if (isoStr.isEmpty || isoStr == 'Active') return isoStr;
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (_) {
      return isoStr;
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

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadTodayStatus,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(dark),
                  if (_isLoading)
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
                  _buildActiveBreakCard(dark),
                  const SizedBox(height: 20),
                  _buildBreakAllowances(dark),
                  const SizedBox(height: 24),
                  _buildBreakHistoryHeader(dark),
                  const SizedBox(height: 12),
                  _buildBreakHistoryList(dark),
                ],
              ),
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
          'Break Tracker',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track and manage your daily shift break intervals',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildActiveBreakCard(bool dark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.cardDecoration(dark),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isOnBreak
                      ? const Color(0xFFED6C02).withValues(alpha: 0.15)
                      : AppColors.copper.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOnBreak
                      ? Icons.timer_outlined
                      : Icons.free_breakfast_outlined,
                  color: _isOnBreak
                      ? const Color(0xFFED6C02)
                      : AppColors.copper,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnBreak
                          ? 'Currently on $_activeBreakType'
                          : 'Break Station',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isOnBreak
                          ? (_breakStartTime != null
                                ? 'Timer running since ${_formatTimeString(_breakStartTime!.toIso8601String())}'
                                : 'Timer running')
                          : 'Select a break type and start timing',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isOnBreak) ...[
            Text(
              _formatDuration(_elapsed),
              style: TextStyle(
                color: AppColors.accentText(dark),
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isActionInProgress ? null : _endBreak,
                icon: _isActionInProgress
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.stop_rounded, color: Colors.white),
                label: const Text(
                  'End Break Now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Break Type',
                      filled: true,
                      fillColor: AppColors.fieldFill(dark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.fieldBorder(dark),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Lunch Break',
                        child: Text('Lunch Break (45m)'),
                      ),
                      DropdownMenuItem(
                        value: 'Tea Break',
                        child: Text('Tea Break (15m)'),
                      ),
                      DropdownMenuItem(
                        value: 'Casual Break',
                        child: Text('Casual Break (10m)'),
                      ),
                      DropdownMenuItem(
                        value: 'Personal Break',
                        child: Text('Personal Break'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isActionInProgress ? null : _startBreak,
                icon: _isActionInProgress
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, color: Colors.white),
                label: const Text(
                  'Start Break',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakAllowances(bool dark) {
    return Row(
      children: [
        Expanded(
          child: _allowanceCard(
            dark,
            title: 'Lunch Allowance',
            time: '45 mins',
            used: 'Standard policy',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _allowanceCard(
            dark,
            title: 'Tea Allowance',
            time: '30 mins total',
            used: 'Standard policy',
            icon: Icons.coffee_outlined,
            color: const Color(0xFFED6C02),
          ),
        ),
      ],
    );
  }

  Widget _allowanceCard(
    bool dark, {
    required String title,
    required String time,
    required String used,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppColors.cardDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: TextStyle(
              color: AppColors.accentText(dark),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            used,
            style: TextStyle(color: AppColors.muted(dark), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakHistoryHeader(bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Break History',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${_breakLogs.length} Records',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBreakHistoryList(bool dark) {
    if (_breakLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppColors.cardDecoration(dark),
        child: Center(
          child: Text(
            'No break logs recorded today',
            style: TextStyle(color: AppColors.muted(dark)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _breakLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = _breakLogs[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: AppColors.cardDecoration(dark),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.copper.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  log['type'].toString().contains('Lunch')
                      ? Icons.restaurant
                      : Icons.coffee,
                  color: AppColors.copper,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['type'] ?? 'Break',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log['date']} • ${log['startTime']} - ${log['endTime']}',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    log['duration'] ?? '—',
                    style: TextStyle(
                      color: AppColors.accentText(dark),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log['status'] ?? 'Completed',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
