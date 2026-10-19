import 'package:flutter/material.dart';

import '../services/profile_api_service.dart';
import '../theme/app_colors.dart';

class EditProfilePage extends StatefulWidget {
  final String employeeId;
  final String? accessToken;

  const EditProfilePage({
    super.key,
    required this.employeeId,
    this.accessToken,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final ProfileApiService _api;

  final _formKey = GlobalKey<FormState>();

  // Personal Information
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _nationalityController = TextEditingController();

  // Address & Work Location
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _regionController = TextEditingController();
  final _workLocationController = TextEditingController();

  // Financial & Bank Details
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _ifscController = TextEditingController();

  // Identity & Tax Details
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _taxIdController = TextEditingController();

  // Emergency Contact
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _gender;
  String? _maritalStatus;
  String? _bloodGroup;

  @override
  void initState() {
    super.initState();
    _api = ProfileApiService(token: widget.accessToken);
    _loadProfile();
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _formatDateForInput(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    if (str.isEmpty) return '';
    try {
      final dt = DateTime.parse(str);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return str.contains('T') ? str.split('T').first : str;
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getEmployeeProfile(widget.employeeId);

      if (!mounted) return;

      setState(() {
        _firstNameController.text = _stringValue(
          data['firstName'] ?? data['givenName'],
        );
        _lastNameController.text = _stringValue(
          data['lastName'] ?? data['familyName'],
        );
        _emailController.text = _stringValue(
          data['email'] ?? data['emailAddress'],
        );
        _phoneController.text = _stringValue(
          data['phone'] ?? data['phoneNumber'] ?? data['mobileNumber'],
        );
        _dobController.text = _formatDateForInput(
          data['dateOfBirth'] ?? data['dob'] ?? data['birthDate'],
        );
        _nationalityController.text = _stringValue(data['nationality']);

        _addressController.text = _stringValue(
          data['address'] ?? data['streetAddress'] ?? data['addressLine1'],
        );
        _cityController.text = _stringValue(data['city']);
        _stateController.text = _stringValue(data['state'] ?? data['province']);
        _countryController.text = _stringValue(data['country']);
        _zipCodeController.text = _stringValue(
          data['zipCode'] ?? data['postalCode'] ?? data['pinCode'],
        );
        _regionController.text = _stringValue(data['region']);
        _workLocationController.text = _stringValue(
          data['workLocation'] ?? data['location'],
        );

        _aadhaarController.text = _stringValue(
          data['aadhaarNumber'] ?? data['aadhaar'] ?? data['aadharNumber'],
        );
        _panController.text = _stringValue(
          data['panNumber'] ?? data['pan'],
        );
        _taxIdController.text = _stringValue(data['taxId']);

        _bankNameController.text = _stringValue(data['bankName']);
        _bankAccountController.text = _stringValue(
          data['bankAccountNumber'] ?? data['accountNumber'],
        );
        _ifscController.text = _stringValue(
          data['ifscCode'] ?? data['ifsc'],
        );

        _emergencyNameController.text = _stringValue(
          data['emergencyContactName'],
        );
        _emergencyPhoneController.text = _stringValue(
          data['emergencyContactPhone'],
        );
        _emergencyRelationController.text = _stringValue(
          data['emergencyContactRelation'] ??
              data['emergencyContactRelationship'],
        );

        _gender = _validOption(data['gender']?.toString(), [
          'Male',
          'Female',
          'Other',
        ]);
        _maritalStatus = _validOption(
          data['maritalStatus']?.toString(),
          ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'],
        );
        _bloodGroup = _validOption(
          data['bloodGroup']?.toString(),
          ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
        );

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

  String? _validOption(String? value, List<String> options) {
    if (value == null) return null;
    final match = options.firstWhere(
      (opt) => opt.toLowerCase() == value.trim().toLowerCase(),
      orElse: () => '',
    );
    return match.isNotEmpty ? match : null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'dateOfBirth': _dobController.text.trim(),
      'gender': _gender,
      'maritalStatus': _maritalStatus,
      'nationality': _nationalityController.text.trim(),
      'bloodGroup': _bloodGroup,
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'country': _countryController.text.trim(),
      'zipCode': _zipCodeController.text.trim(),
      'region': _regionController.text.trim(),
      'workLocation': _workLocationController.text.trim(),
      'aadhaarNumber': _aadhaarController.text.trim(),
      'panNumber': _panController.text.trim(),
      'taxId': _taxIdController.text.trim(),
      'bankName': _bankNameController.text.trim(),
      'bankAccountNumber': _bankAccountController.text.trim(),
      'ifscCode': _ifscController.text.trim(),
      'emergencyContactName': _emergencyNameController.text.trim(),
      'emergencyContactPhone': _emergencyPhoneController.text.trim(),
      'emergencyContactRelation': _emergencyRelationController.text.trim(),
    };

    payload.updateAll((key, value) {
      if (value is String && value.trim().isEmpty) return null;
      return value;
    });

    try {
      await _api.updateEmployeeProfile(widget.employeeId, payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: Color(0xFF149B70),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      final err = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = err;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _textField(
    bool dark,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppColors.text(dark),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.muted(dark), fontSize: 12),
          filled: true,
          fillColor: AppColors.fieldFill(dark),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.glassBorder(dark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.copper, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }

          if (label == 'Email' &&
              value != null &&
              value.trim().isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
            return 'Enter a valid email address';
          }

          return null;
        },
      ),
    );
  }

  Widget _datePickerField(
    bool dark,
    String label,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: TextStyle(
          color: AppColors.text(dark),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.muted(dark), fontSize: 12),
          filled: true,
          fillColor: AppColors.fieldFill(dark),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.glassBorder(dark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.copper, width: 1.5),
          ),
          suffixIcon: Icon(
            Icons.calendar_today_rounded,
            color: AppColors.accentText(dark),
            size: 18,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
        ),
        onTap: () async {
          DateTime initial =
              DateTime.tryParse(controller.text) ?? DateTime(2000, 1, 1);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            final formatted =
                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
            setState(() {
              controller.text = formatted;
            });
          }
        },
      ),
    );
  }

  Widget _dropdown(
    bool dark,
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: dark ? const Color(0xFF1F2223) : Colors.white,
        style: TextStyle(
          color: AppColors.text(dark),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.muted(dark), fontSize: 12),
          filled: true,
          fillColor: AppColors.fieldFill(dark),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.glassBorder(dark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.copper, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  style: TextStyle(color: AppColors.text(dark)),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _sectionHeader(bool dark, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.copper),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.text(dark),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _nationalityController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipCodeController.dispose();
    _regionController.dispose();
    _workLocationController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _taxIdController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          appBar: AppBar(
            backgroundColor: dark ? const Color(0xFF17191A) : Colors.white,
            foregroundColor: AppColors.text(dark),
            elevation: 0,
            title: Text(
              'Edit Profile',
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              if (!_loading)
                IconButton(
                  tooltip: 'Reload profile',
                  onPressed: _saving ? null : _loadProfile,
                  icon: Icon(Icons.refresh, color: AppColors.accentText(dark)),
                ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.copper),
                )
              : _error != null && _firstNameController.text.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 44,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.copper,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _sectionHeader(dark, 'Personal Information', Icons.person_outline_rounded),
                        _textField(
                          dark,
                          'First Name',
                          _firstNameController,
                          required: true,
                        ),
                        _textField(
                          dark,
                          'Last Name',
                          _lastNameController,
                          required: true,
                        ),
                        _textField(
                          dark,
                          'Email',
                          _emailController,
                          keyboardType: TextInputType.emailAddress,
                          required: true,
                        ),
                        _textField(
                          dark,
                          'Phone',
                          _phoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        _datePickerField(dark, 'Date of Birth (YYYY-MM-DD)', _dobController),
                        _dropdown(dark, 'Gender', _gender, [
                          'Male',
                          'Female',
                          'Other',
                        ], (v) => setState(() => _gender = v)),
                        _dropdown(dark, 'Marital Status', _maritalStatus, [
                          'SINGLE',
                          'MARRIED',
                          'DIVORCED',
                          'WIDOWED',
                        ], (v) => setState(() => _maritalStatus = v)),
                        _textField(dark, 'Nationality', _nationalityController),
                        _dropdown(dark, 'Blood Group', _bloodGroup, [
                          'A+',
                          'A-',
                          'B+',
                          'B-',
                          'AB+',
                          'AB-',
                          'O+',
                          'O-',
                        ], (v) => setState(() => _bloodGroup = v)),
                        
                        const SizedBox(height: 8),
                        _sectionHeader(dark, 'Address & Location', Icons.location_on_outlined),
                        _textField(dark, 'Address', _addressController),
                        _textField(dark, 'City', _cityController),
                        _textField(dark, 'State', _stateController),
                        _textField(dark, 'Country', _countryController),
                        _textField(dark, 'ZIP Code', _zipCodeController),
                        _textField(dark, 'Region', _regionController),
                        _textField(dark, 'Work Location', _workLocationController),

                        const SizedBox(height: 8),
                        _sectionHeader(dark, 'Identity & Tax Details', Icons.badge_outlined),
                        _textField(dark, 'Aadhaar Number', _aadhaarController, keyboardType: TextInputType.number),
                        _textField(dark, 'PAN Card Number', _panController),
                        _textField(dark, 'Tax ID', _taxIdController),

                        const SizedBox(height: 8),
                        _sectionHeader(dark, 'Financial & Bank Details', Icons.account_balance_outlined),
                        _textField(dark, 'Bank Name', _bankNameController),
                        _textField(dark, 'Bank Account Number', _bankAccountController, keyboardType: TextInputType.number),
                        _textField(dark, 'IFSC Code', _ifscController),

                        const SizedBox(height: 8),
                        _sectionHeader(dark, 'Emergency Contact', Icons.health_and_safety_outlined),
                        _textField(
                          dark,
                          'Emergency Contact Name',
                          _emergencyNameController,
                        ),
                        _textField(
                          dark,
                          'Emergency Contact Phone',
                          _emergencyPhoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        _textField(
                          dark,
                          'Emergency Contact Relation',
                          _emergencyRelationController,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.copper,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
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
}
