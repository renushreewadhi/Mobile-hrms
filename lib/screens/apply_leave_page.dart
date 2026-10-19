import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/leave_api_service.dart';
import '../services/profile_api_service.dart';
import '../theme/app_colors.dart';

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final _companyEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _reasonController = TextEditingController();

  final LeaveApiService _leaveApi = LeaveApiService();
  final ProfileApiService _profileApi = ProfileApiService();

  String _selectedLeaveTypeKey = 'Sick Leave';
  String _selectedDuration = 'Full Day(s)';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loadingBalances = true;
  bool _submitting = false;
  String? _error;

  // Map of leaveType -> formatted label with remaining balance
  Map<String, String> _leaveTypeOptions = {
    'Sick Leave': 'Sick Leave (6 days remaining)',
    'Casual Leave': 'Casual Leave (8 days remaining)',
    'Annual Leave': 'Annual Leave (12 days remaining)',
    'Unpaid Leave': 'Unpaid Leave',
  };

  static const List<String> _durationOptions = [
    'Full Day(s)',
    'Half Day (First Half)',
    'Half Day (Second Half)',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserAndBalances();
  }

  @override
  void dispose() {
    _companyEmailController.dispose();
    _contactPhoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndBalances() async {
    if (!mounted) return;
    setState(() => _loadingBalances = true);

    try {
      final profile =
          await _profileApi.getCachedProfile() ??
          await _profileApi.getMyProfile();
      if (profile.isNotEmpty && mounted) {
        final email =
            profile['email'] ?? profile['userEmail'] ?? 'emp@hrm.com';
        final phone =
            profile['phone'] ??
            profile['phoneNumber'] ??
            profile['mobileNumber'] ??
            '+91 98765 43210';
        final empId = ProfileApiService.extractEmployeeId(profile);

        setState(() {
          if (_companyEmailController.text.isEmpty) {
            _companyEmailController.text = email.toString();
          }
          if (_contactPhoneController.text.isEmpty) {
            _contactPhoneController.text = phone.toString();
          }
        });

        final balances = await _leaveApi.getLeaveBalances(employeeId: empId);
        if (balances is List && balances.isNotEmpty && mounted) {
          final updatedOptions = <String, String>{};
          for (final b in balances) {
            if (b is Map) {
              final rawType = (b['leaveType'] ?? b['type'] ?? 'Leave').toString().trim();
              if (rawType.isNotEmpty && !updatedOptions.containsKey(rawType)) {
                final rem = b['remaining']?.toString() ?? '0';
                updatedOptions[rawType] = '$rawType ($rem days remaining)';
              }
            }
          }
          if (updatedOptions.isNotEmpty) {
            setState(() {
              _leaveTypeOptions = updatedOptions;
              if (!_leaveTypeOptions.containsKey(_selectedLeaveTypeKey)) {
                _selectedLeaveTypeKey = _leaveTypeOptions.keys.first;
              }
            });
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingBalances = false);
      }
    }
  }

  double get _calculatedTotalDays {
    if (_startDate == null) return 0;
    if (_selectedDuration != 'Full Day(s)') return 0.5;
    if (_endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff < 1 ? 0 : diff.toDouble();
  }

  String get _totalDaysFormatted {
    final days = _calculatedTotalDays;
    if (days == 0) return '0 Days';
    if (days == 0.5) return '0.5 Day';
    if (days == 1) return '1 Day';
    return '${days.toInt()} Days';
  }

  String _formatMmDdYyyy(DateTime? date) {
    if (date == null) return 'mm/dd/yyyy';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);
    final first = isStart
        ? DateTime(now.year - 1)
        : (_startDate ?? DateTime(now.year - 1));

    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 2),
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = selected;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      _message('Please select a Start Date.');
      return;
    }
    if (_selectedDuration == 'Full Day(s)' && _endDate == null) {
      _message('Please select an End Date.');
      return;
    }
    if (_selectedDuration == 'Full Day(s)' && _endDate!.isBefore(_startDate!)) {
      _message('End Date cannot be before Start Date.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final effectiveEndDate =
        _selectedDuration != 'Full Day(s)' ? _startDate! : _endDate!;
    final email = _companyEmailController.text.trim();
    final contact = _contactPhoneController.text.trim();
    final rawReason = _reasonController.text.trim();

    final reasonWithContact = contact.isNotEmpty
        ? '$rawReason\n[Contact during leave: $contact]'
        : rawReason;

    final payload = <String, dynamic>{
      'leaveType': _selectedLeaveTypeKey,
      'duration': _selectedDuration,
      'startDate': _startDate!.toIso8601String(),
      'endDate': effectiveEndDate.toIso8601String(),
      'companyEmail': email,
      'contactPhone': contact,
      'reason': reasonWithContact,
    };

    try {
      await _leaveApi.applyLeave(payload);

      if (!mounted) return;

      setState(() {
        _submitting = false;
        _startDate = null;
        _endDate = null;
        _reasonController.clear();
      });

      final dark = AppColors.isDarkMode.value;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: dark ? AppColors.graphite : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF149B70),
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Leave Request Submitted!',
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Your request for $_selectedLeaveTypeKey ($_totalDaysFormatted) has been submitted successfully for manager approval.',
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 13,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.copper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final err = e
          .toString()
          .replaceFirst('ApiException: ', '')
          .replaceFirst('Exception: ', '');
      setState(() {
        _error = err;
        _submitting = false;
      });

      _message('Failed to submit leave: $err');
    }
  }

  void _message(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _surface(bool dark, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: AppColors.cardDecoration(dark, radius: 19),
          child: child,
        ),
      ),
    );
  }

  Widget _label(bool dark, String label, {bool isMandatory = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.text(dark),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        children: [
          if (isMandatory)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool dark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 12),
      filled: true,
      fillColor: AppColors.fieldFill(dark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.glassBorder(dark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.glassBorder(dark)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.copper, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 10),
    );
  }

  Widget _datePickerTile(
    bool dark,
    DateTime? date,
    VoidCallback onTap,
  ) {
    final isSelected = date != null;
    return Material(
      color: AppColors.fieldFill(dark),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder(dark)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatMmDdYyyy(date),
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.text(dark)
                        : AppColors.muted(dark),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: AppColors.accentText(dark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) => Scaffold(
        backgroundColor: dark ? AppColors.graphite : AppColors.cream,
        appBar: AppBar(
          backgroundColor: dark ? const Color(0xFF17191A) : Colors.white,
          foregroundColor: AppColors.text(dark),
          elevation: 0,
          title: Text(
            'Leave Request Form',
            style: TextStyle(
              color: AppColors.text(dark),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _surface(
                    dark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Leave Request Form',
                              style: TextStyle(
                                color: AppColors.text(dark),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_loadingBalances)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.copper,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '* Mandatory fields',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 1. Leave Type *
                        _label(dark, 'Leave Type', isMandatory: true),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final validLeaveTypeValue =
                                _leaveTypeOptions.containsKey(_selectedLeaveTypeKey)
                                    ? _selectedLeaveTypeKey
                                    : (_leaveTypeOptions.isNotEmpty
                                        ? _leaveTypeOptions.keys.first
                                        : null);
                            return DropdownButtonFormField<String>(
                              value: validLeaveTypeValue,
                              isExpanded: true,
                              dropdownColor:
                                  dark ? const Color(0xFF202326) : Colors.white,
                              style: TextStyle(
                                color: AppColors.text(dark),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration:
                                  _inputDecoration(dark, 'Select leave type'),
                              items: _leaveTypeOptions.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(
                                        entry.value,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedLeaveTypeKey = val);
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Duration *
                        _label(dark, 'Duration', isMandatory: true),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedDuration,
                          dropdownColor:
                              dark ? const Color(0xFF202326) : Colors.white,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration(dark, 'Select duration'),
                          items: _durationOptions
                              .map(
                                (opt) => DropdownMenuItem(
                                  value: opt,
                                  child: Text(opt),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDuration = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. Start Date *
                        _label(dark, 'Start Date', isMandatory: true),
                        const SizedBox(height: 6),
                        _datePickerTile(
                          dark,
                          _startDate,
                          () => _pickDate(isStart: true),
                        ),
                        const SizedBox(height: 16),

                        // 4. End Date * (disabled if Half Day)
                        _label(dark, 'End Date', isMandatory: true),
                        const SizedBox(height: 6),
                        _datePickerTile(
                          dark,
                          _selectedDuration != 'Full Day(s)'
                              ? _startDate
                              : _endDate,
                          _selectedDuration != 'Full Day(s)'
                              ? () {}
                              : () => _pickDate(isStart: false),
                        ),
                        const SizedBox(height: 16),

                        // 5. Total Days
                        _label(dark, 'Total Days'),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.copper.withValues(
                              alpha: dark ? 0.12 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.copper.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            _totalDaysFormatted,
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 6. Company Mail ID *
                        _label(dark, 'Company Mail ID', isMandatory: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _companyEmailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration(
                            dark,
                            'emp@hrm.com',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Company Mail ID is required';
                            }
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(val.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 7. Contact During Leave
                        _label(dark, 'Contact During Leave'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _contactPhoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration(
                            dark,
                            '+91 98765 43210',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 8. Reason for Leave *
                        _label(dark, 'Reason for Leave', isMandatory: true),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration(
                            dark,
                            'Provide context or description for your manager...',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a reason for your leave';
                            }
                            return null;
                          },
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              _submitting
                                  ? 'Submitting...'
                                  : 'Submit Leave Request',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
