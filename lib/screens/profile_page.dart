import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/hrms_services.dart';
import '../theme/app_colors.dart';
import 'edit_profile_page.dart';

enum _ProfileSection { employment, personal, financial, security }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  _ProfileSection _selectedSection = _ProfileSection.employment;
  bool _pushNotifications = true;
  bool _gpsValidation = true;

  final ApiClient _apiClient = ApiClient();
  final ProfileApiService _profileApi = ProfileApiService();
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    final cached = await _profileApi.getCachedProfile();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _profile = cached;
        _isLoading = false;
        _loadError = null;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final freshProfile = await _profileApi.getMyProfile(refresh: true);
      if (!mounted) return;
      setState(() {
        _profile = freshProfile;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_profile.isEmpty) {
        setState(() {
          _loadError = error is ApiException
              ? error.message
              : 'Unable to load your profile.';
          _isLoading = false;
        });
      }
    }
  }

  void _openEditProfile() async {
    final employeeUuid = ProfileApiService.extractEmployeeId(_profile) ?? '';
    final token = await _apiClient.getToken();
    if (!mounted) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditProfilePage(employeeId: employeeUuid, accessToken: token),
      ),
    );

    if (updated == true) {
      _loadProfile();
    }
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  String _profileValue(List<String> keys, {String fallback = 'Not provided'}) {
    for (final key in keys) {
      final value = _profile[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String _dateProfileValue(List<String> keys) {
    final value = _profileValue(keys);
    if (value == 'Not provided') return value;
    try {
      final parsed = DateTime.parse(value);
      return '${parsed.day.toString().padLeft(2, '0')} ${_monthName(parsed.month)} ${parsed.year}';
    } catch (_) {
      return value;
    }
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  String _fullName() {
    final explicitName = _firstNonEmpty([
      _profile['fullName'],
      _profile['name'],
      _profile['employeeName'],
      _profile['displayName'],
    ]);
    if (explicitName != null) return explicitName;
    final first = _firstNonEmpty([_profile['firstName']]) ?? '';
    final last = _firstNonEmpty([_profile['lastName']]) ?? '';
    final combined = '$first $last'.trim();
    return combined.isEmpty ? 'Employee' : combined;
  }

  String _email() => _profileValue(['email', 'emailAddress', 'userEmail']);

  String _designation() =>
      _profileValue(['designation', 'jobTitle', 'position', 'title']);

  String _employeeId() => _profileValue([
    'employeeId',
    'employeeCode',
    'employeeNumber',
    'staffId',
    'code',
  ]);

  String _organization() {
    final direct = _profileValue([
      'companyName',
      'organizationName',
      'company_name',
      'organization_name',
      'orgName',
      'tenantName',
      'businessUnit',
    ]);
    if (direct != 'Not provided') return direct;

    // Check direct string fields
    for (final key in ['company', 'organization', 'tenant', 'businessUnit']) {
      final val = _profile[key];
      if (val is String && val.trim().isNotEmpty && val != 'Not provided') {
        return val.trim();
      }
    }

    // Check nested objects
    for (final key in [
      'organization', 'company', 'tenant', 'businessUnit',
      'organizationDetails', 'companyDetails', 'tenantDetails', 'companyProfile'
    ]) {
      final obj = _profile[key];
      if (obj is Map) {
        final name = obj['name'] ??
            obj['title'] ??
            obj['companyName'] ??
            obj['organizationName'] ??
            obj['tenantName'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString().trim();
        }
      }
    }

    // Check inside user or employee nested map
    for (final parentKey in ['user', 'employee', 'profile']) {
      final parent = _profile[parentKey];
      if (parent is Map) {
        for (final k in ['companyName', 'organizationName', 'company', 'organization', 'tenantName']) {
          final name = parent[k];
          if (name is String && name.trim().isNotEmpty) {
            return name.trim();
          } else if (name is Map) {
            final n = name['name'] ?? name['companyName'] ?? name['organizationName'];
            if (n != null && n.toString().trim().isNotEmpty) {
              return n.toString().trim();
            }
          }
        }
      }
    }

    return 'ETAPRISE HRMS';
  }

  String _salary() {
    final value = _firstNonEmpty([
      _profile['salary'],
      _profile['salaryCtc'],
      _profile['ctc'],
      _profile['annualSalary'],
    ]);
    if (value == null) return 'Not provided';
    final amount = double.tryParse(value);
    if (amount == null) return value;
    return '₹${amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)}';
  }

  String _maskedAccount() {
    final account = _profileValue(['bankAccountNumber', 'accountNumber']);
    if (account == 'Not provided') return account;
    final digits = account.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return digits;
    return '••••••••${digits.substring(digits.length - 4)}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (_loadError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _loadError!,
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadProfile,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _buildEmployeeSummary(dark),
                      const SizedBox(height: 17),
                      _buildTabs(dark),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey<_ProfileSection>(_selectedSection),
                          child: _buildSelectedContent(dark),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'ETAPRISE  •  HRMS',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmployeeSummary(bool dark) {
    return _mainSurface(
      dark,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark
                      ? Colors.white.withOpacity(0.09)
                      : const Color(0xFFF0F2F5),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withOpacity(0.15)
                        : const Color(0xFFE2E6EC),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: dark
                      ? const Color(0xFFB5BDCA)
                      : const Color(0xFF8D99AC),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _designation(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.accentText(dark),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 14,
                          color: AppColors.muted(dark),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _email(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _activeBadge(dark),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openEditProfile,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.copper.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.copper.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 12, color: AppColors.copper),
                          SizedBox(width: 4),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: AppColors.copper,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _summaryTag(
                dark,
                icon: Icons.badge_outlined,
                label: _employeeId(),
              ),
              _summaryTag(
                dark,
                icon: Icons.business_outlined,
                label: _organization(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeBadge(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF19A66A).withOpacity(dark ? 0.17 : 0.11),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFF19A66A)),
          const SizedBox(width: 5),
          const Text(
            'Active',
            style: TextStyle(
              color: Color(0xFF19A66A),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTag(
    bool dark, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(0.045)
            : Colors.white.withOpacity(0.55),
        border: Border.all(color: AppColors.glassBorder(dark)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accentText(dark)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool dark) {
    final tabs = <_ProfileTabData>[
      _ProfileTabData(
        section: _ProfileSection.employment,
        label: 'Employment',
        icon: Icons.work_outline_rounded,
      ),
      _ProfileTabData(
        section: _ProfileSection.personal,
        label: 'Personal & Address',
        icon: Icons.person_outline_rounded,
      ),
      _ProfileTabData(
        section: _ProfileSection.financial,
        label: 'Financial',
        icon: Icons.account_balance_wallet_outlined,
      ),
      _ProfileTabData(
        section: _ProfileSection.security,
        label: 'Security',
        icon: Icons.shield_outlined,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            _tabButton(
              dark,
              data: tab,
              selected: _selectedSection == tab.section,
              onTap: () => setState(() => _selectedSection = tab.section),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(
    bool dark, {
    required _ProfileTabData data,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.copper.withOpacity(dark ? 0.22 : 0.18)
          : (dark
                ? Colors.white.withOpacity(0.045)
                : Colors.white.withOpacity(0.68)),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? AppColors.copper.withOpacity(0.75)
                  : AppColors.glassBorder(dark),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                data.icon,
                size: 16,
                color: selected
                    ? AppColors.accentText(dark)
                    : AppColors.muted(dark),
              ),
              const SizedBox(width: 7),
              Text(
                data.label,
                style: TextStyle(
                  color: selected
                      ? AppColors.text(dark)
                      : AppColors.muted(dark),
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedContent(bool dark) {
    switch (_selectedSection) {
      case _ProfileSection.employment:
        return _buildEmployment(dark);
      case _ProfileSection.personal:
        return _buildPersonal(dark);
      case _ProfileSection.financial:
        return _buildFinancial(dark);
      case _ProfileSection.security:
        return _buildSecurity(dark);
    }
  }

  Widget _buildEmployment(bool dark) {
    return Column(
      children: [
        _detailsPanel(
          dark,
          title: 'Employment overview',
          subtitle: 'Official role and organization details',
          icon: Icons.badge_outlined,
          fields: [
            _ProfileField(
              'Organization',
              _organization(),
              Icons.business_outlined,
            ),
            _ProfileField('Employee ID', _employeeId(), Icons.badge_outlined),
            _ProfileField(
              'Department',
              _profileValue(['departmentName', 'department']),
              Icons.account_tree_outlined,
            ),
            _ProfileField(
              'Designation',
              _designation(),
              Icons.work_outline_rounded,
            ),
            _ProfileField(
              'Branch',
              _profileValue(['branchName', 'branch']),
              Icons.hub_outlined,
            ),
            _ProfileField(
              'Team',
              _profileValue(['teamName', 'team']),
              Icons.groups_2_outlined,
            ),
            _ProfileField(
              'Reporting manager',
              _profileValue([
                'reportingManagerName',
                'managerName',
                'reportingManager',
              ]),
              Icons.person_outline_rounded,
            ),
            _ProfileField(
              'Joined date',
              _dateProfileValue(['joiningDate', 'dateOfJoining', 'hireDate']),
              Icons.calendar_month_outlined,
            ),
            _ProfileField(
              'Work location',
              _profileValue(['workLocation', 'location']),
              Icons.location_on_outlined,
            ),
            _ProfileField(
              'Assigned shift',
              _profileValue(['shiftName', 'assignedShift']),
              Icons.schedule_rounded,
            ),
            _ProfileField(
              'Salary (CTC)',
              _salary(),
              Icons.account_balance_wallet_outlined,
            ),
          ],
          showEdit: true,
        ),
        const SizedBox(height: 12),
        _branchHistory(dark),
      ],
    );
  }

  Widget _buildPersonal(bool dark) {
    return Column(
      children: [
        _detailsPanel(
          dark,
          title: 'Personal details',
          subtitle: 'Basic personal identifiers',
          icon: Icons.person_outline_rounded,
          fields: [
            _ProfileField(
              'Email address',
              _email(),
              Icons.mail_outline_rounded,
            ),
            _ProfileField(
              'Phone number',
              _profileValue(['phone', 'phoneNumber', 'mobileNumber']),
              Icons.phone_outlined,
            ),
            _ProfileField(
              'Date of birth',
              _dateProfileValue(['dateOfBirth', 'dob', 'birthDate']),
              Icons.cake_outlined,
            ),
            _ProfileField(
              'Gender',
              _profileValue(['gender']),
              Icons.person_outline_rounded,
            ),
            _ProfileField(
              'Marital status',
              _profileValue(['maritalStatus']),
              Icons.favorite_border_rounded,
            ),
            _ProfileField(
              'Nationality',
              _profileValue(['nationality']),
              Icons.public_rounded,
            ),
          ],
          showEdit: true,
        ),
        const SizedBox(height: 12),
        _detailsPanel(
          dark,
          title: 'Residential address',
          subtitle: 'Current home address',
          icon: Icons.location_on_outlined,
          fields: [
            _ProfileField(
              'Street address',
              _profileValue(['streetAddress', 'addressLine1', 'address']),
              Icons.home_outlined,
            ),
            _ProfileField(
              'City',
              _profileValue(['city']),
              Icons.location_city_outlined,
            ),
            _ProfileField(
              'State / province',
              _profileValue(['state', 'province']),
              Icons.map_outlined,
            ),
            _ProfileField(
              'Country',
              _profileValue(['country']),
              Icons.flag_outlined,
            ),
            _ProfileField(
              'Postal code',
              _profileValue(['zipCode', 'postalCode', 'pinCode']),
              Icons.markunread_mailbox_outlined,
            ),
            _ProfileField(
              'Region',
              _profileValue(['region']),
              Icons.public_outlined,
            ),
          ],
          showEdit: true,
        ),
      ],
    );
  }

  Widget _buildFinancial(bool dark) {
    return Column(
      children: [
        _detailsPanel(
          dark,
          title: 'Bank & payroll accounts',
          subtitle: 'Financial details • account number masked',
          icon: Icons.account_balance_outlined,
          fields: [
            _ProfileField(
              'Bank name',
              _profileValue(['bankName']),
              Icons.account_balance_outlined,
            ),
            _ProfileField(
              'Account number',
              _maskedAccount(),
              Icons.credit_card_outlined,
            ),
            _ProfileField(
              'IFSC code',
              _profileValue(['ifscCode', 'ifsc']),
              Icons.qr_code_2_rounded,
            ),
            _ProfileField(
              'Tax ID / PAN',
              _profileValue(['taxId', 'panNumber', 'pan']),
              Icons.description_outlined,
            ),
            _ProfileField(
              'PAN card number',
              _profileValue(['panNumber', 'pan']),
              Icons.badge_outlined,
            ),
          ],
          showEdit: true,
        ),
        const SizedBox(height: 12),
        _detailsPanel(
          dark,
          title: 'Emergency contact',
          subtitle: 'Primary contact for emergency situations',
          icon: Icons.health_and_safety_outlined,
          fields: [
            _ProfileField(
              'Contact name',
              _profileValue(['emergencyContactName']),
              Icons.person_outline_rounded,
            ),
            _ProfileField(
              'Contact phone',
              _profileValue(['emergencyContactPhone']),
              Icons.phone_outlined,
            ),
            _ProfileField(
              'Relationship',
              _profileValue([
                'emergencyContactRelation',
                'emergencyContactRelationship',
              ]),
              Icons.groups_2_outlined,
            ),
          ],
          showEdit: true,
        ),
      ],
    );
  }

  Widget _buildSecurity(bool dark) {
    final geofenceEnabled = _profile['gpsEnabled'] == true ||
        _profile['geofence'] != null ||
        _profile['geofenceValidation'] == true ||
        true; // Enabled by default as admin setting

    return _panel(
      dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeading(
            dark,
            title: 'Security & preferences',
            subtitle: 'Notification and admin location configuration',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 8),
          _preferenceRow(
            dark,
            title: 'Push notifications',
            subtitle: 'Real-time alerts for attendance, shifts and leave requests',
            icon: Icons.notifications_none_rounded,
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
              _showMessage(
                value ? 'Push notifications enabled.' : 'Push notifications disabled.',
              );
            },
          ),
          Divider(height: 1, color: _dividerColor(dark)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_searching_rounded, color: AppColors.accentText(dark), size: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS Geofence Validation',
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Validate punch location near approved office radius (Auto-configured by Admin)',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (geofenceEnabled ? const Color(0xFF19A66A) : AppColors.copper).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    geofenceEnabled ? 'Admin Set: Active' : 'Admin Set: Disabled',
                    style: TextStyle(
                      color: geofenceEnabled ? const Color(0xFF19A66A) : AppColors.copper,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GPS geofence parameters are automatically managed by your administrator.',
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsPanel(
    bool dark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_ProfileField> fields,
    bool showEdit = false,
  }) {
    return _panel(
      dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(dark, icon),
              const SizedBox(width: 11),
              Expanded(
                child: _panelHeading(dark, title: title, subtitle: subtitle),
              ),
              if (showEdit)
                TextButton.icon(
                  onPressed: _openEditProfile,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentText(dark),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: _dividerColor(dark)),
          for (var i = 0; i < fields.length; i++) ...[
            _detailRow(dark, fields[i]),
            if (i != fields.length - 1)
              Divider(height: 1, indent: 31, color: _dividerColor(dark)),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(bool dark, _ProfileField field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 21,
            child: Icon(
              field.icon,
              size: 17,
              color: AppColors.accentText(dark),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              field.label,
              style: TextStyle(
                color: AppColors.muted(dark),
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 7,
            child: Text(
              field.value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchHistory(bool dark) {
    final rawHistory = _profile['branchHistory'];
    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return _panel(
      dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeading(
            dark,
            title: 'Branch assignment history',
            subtitle: 'Previous and current branch assignments',
            icon: Icons.account_tree_outlined,
          ),
          const SizedBox(height: 14),
          if (history.isEmpty)
            Text(
              'No branch history available',
              style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
            )
          else
            ...history.map((item) {
              final branchName =
                  _firstNonEmpty([item['branchName'], item['branch']]) ??
                  'Branch not provided';
              final startDate = _formatDateValue(item['startDate']);
              final endDate = item['endDate'] == null
                  ? 'Present'
                  : _formatDateValue(item['endDate']);
              final active = item['isActive'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.hub_outlined, size: 17, color: AppColors.copper),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branchName,
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$startDate – $endDate',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusPill(dark, active ? 'ACTIVE' : 'INACTIVE'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatDateValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return 'Not provided';
    try {
      final parsed = DateTime.parse(value.toString());
      return '${parsed.day.toString().padLeft(2, '0')} ${_monthName(parsed.month)} ${parsed.year}';
    } catch (_) {
      return value.toString();
    }
  }

  Widget _panelHeading(
    bool dark, {
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          _sectionIcon(dark, icon),
          const SizedBox(width: 11),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionIcon(bool dark, IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.copper.withOpacity(dark ? 0.19 : 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: AppColors.accentText(dark)),
    );
  }

  Widget _preferenceRow(
    bool dark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentText(dark), size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.copper,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _statusPill(bool dark, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF19A66A).withOpacity(dark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFF19A66A)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF19A66A),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(bool dark, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: AppColors.cardDecoration(dark, radius: 18),
          child: child,
        ),
      ),
    );
  }

  Widget _mainSurface(
    bool dark, {
    required Widget child,
    required EdgeInsetsGeometry padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: AppColors.cardDecoration(dark, radius: 19),
          child: child,
        ),
      ),
    );
  }

  Color _dividerColor(bool dark) =>
      dark ? Colors.white.withOpacity(0.10) : const Color(0xFFE8E2DA);
}

class _ProfileField {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileField(this.label, this.value, this.icon);
}

class _ProfileTabData {
  final _ProfileSection section;
  final String label;
  final IconData icon;

  const _ProfileTabData({
    required this.section,
    required this.label,
    required this.icon,
  });
}
