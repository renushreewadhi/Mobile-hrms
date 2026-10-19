import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class ProfileApiService {
  final ApiClient _apiClient = ApiClient();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Map<String, dynamic>? _memoryCache;

  static void clearCache() {
    _memoryCache = null;
    _secureStorage.delete(key: 'cached_profile');
  }

  ProfileApiService({String? token}) {
    if (token != null && token.isNotEmpty) {
      _apiClient.setToken(token);
    }
  }

  static bool _isUuid(String? str) {
    if (str == null) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(str.trim());
  }

  static String? extractEmployeeId(Map<String, dynamic> data) {
    // 1. Check for employeeId / employeeID / employee_id if it's a valid UUID
    for (final key in ['employeeId', 'employeeID', 'employee_id']) {
      final val = data[key]?.toString().trim();
      if (val != null && _isUuid(val)) {
        return val;
      }
    }

    // 2. Check nested objects (employee, profile, user) for a valid UUID
    for (final key in ['employee', 'profile', 'user']) {
      final nested = data[key];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        for (final k in ['employeeId', 'employeeID', 'employee_id']) {
          final val = nestedMap[k]?.toString().trim();
          if (val != null && _isUuid(val)) {
            return val;
          }
        }
        final nestedId = (nestedMap['id'] ?? nestedMap['_id'])?.toString().trim();
        if (nestedId != null && _isUuid(nestedId)) {
          return nestedId;
        }
      }
    }

    // 3. Check top-level id / _id if it's a valid UUID (EmployeeDto format)
    final idVal = (data['id'] ?? data['_id'])?.toString().trim();
    if (idVal != null && _isUuid(idVal)) {
      return idVal;
    }

    // 4. Fallback when no UUID format is found
    for (final key in ['employeeId', 'employeeID', 'employee_id']) {
      final val = data[key]?.toString().trim();
      if (val != null && val.isNotEmpty) {
        return val;
      }
    }

    for (final key in ['employee', 'profile', 'user']) {
      final nested = data[key];
      if (nested is Map) {
        final nestedMap = Map<String, dynamic>.from(nested);
        final nestedId = extractEmployeeId(nestedMap);
        if (nestedId != null) return nestedId;
      }
    }

    if (idVal != null && idVal.isNotEmpty) {
      return idVal;
    }

    return null;
  }

  Future<Map<String, dynamic>?> getCachedProfile() async {
    if (_memoryCache != null && _memoryCache!.isNotEmpty) {
      return _memoryCache;
    }
    try {
      final cachedStr = await _secureStorage.read(key: 'cached_profile');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final data = jsonDecode(cachedStr);
        if (data is Map) {
          _memoryCache = Map<String, dynamic>.from(data);
          return _memoryCache;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _enrichWithCompanyProfile(Map<String, dynamic> target) async {
    final existing = target['companyName'] ??
        target['organizationName'] ??
        target['company_name'] ??
        target['organization_name'];
    if (existing != null && existing.toString().trim().isNotEmpty) return;

    for (final endpoint in [
      '/settings/company-profile',
      '/system-settings/company-profile',
      '/organization/profile',
      '/tenant/current',
    ]) {
      try {
        final res = await _apiClient.get(endpoint);
        final data = ApiClient.unwrap(res);
        if (data is Map) {
          final name = data['companyName'] ??
              data['organizationName'] ??
              data['name'] ??
              data['title'] ??
              data['tenantName'];
          if (name != null && name.toString().trim().isNotEmpty) {
            target['companyName'] = name.toString().trim();
            target['organizationName'] = name.toString().trim();
            break;
          }
        }
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> getMyProfile({bool refresh = false}) async {
    if (!refresh) {
      final cached = await getCachedProfile();
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final meResponse = await _apiClient.get('/users/me');
    final mePayload = ApiClient.unwrap(meResponse);
    final me = mePayload is Map
        ? Map<String, dynamic>.from(mePayload)
        : <String, dynamic>{};

    final employeeId = extractEmployeeId(me);
    if (employeeId == null || employeeId.isEmpty) {
      await _enrichWithCompanyProfile(me);
      _memoryCache = me;
      await _secureStorage.write(key: 'cached_profile', value: jsonEncode(me));
      return me;
    }

    try {
      final empResponse = await _apiClient.get('/employees/$employeeId');
      final empPayload = ApiClient.unwrap(empResponse);
      if (empPayload is Map) {
        final nestedEmp = empPayload['employee'] ?? empPayload['profile'];
        final result = nestedEmp is Map
            ? Map<String, dynamic>.from(nestedEmp)
            : Map<String, dynamic>.from(empPayload);
        result['employeeId'] ??= employeeId;
        await _enrichWithCompanyProfile(result);
        _memoryCache = result;
        await _secureStorage.write(
          key: 'cached_profile',
          value: jsonEncode(result),
        );
        return result;
      }
    } catch (_) {}

    me['employeeId'] ??= employeeId;
    await _enrichWithCompanyProfile(me);
    _memoryCache = me;
    await _secureStorage.write(key: 'cached_profile', value: jsonEncode(me));
    return me;
  }

  Future<Map<String, dynamic>> getEmployeeProfile(String employeeId) async {
    if (employeeId.isNotEmpty) {
      try {
        final empResponse = await _apiClient.get('/employees/$employeeId');
        final empPayload = ApiClient.unwrap(empResponse);
        if (empPayload is Map) {
          final nestedEmp = empPayload['employee'] ?? empPayload['profile'];
          final result = nestedEmp is Map
              ? Map<String, dynamic>.from(nestedEmp)
              : Map<String, dynamic>.from(empPayload);
          result['employeeId'] ??= employeeId;
          _memoryCache = result;
          await _secureStorage.write(
            key: 'cached_profile',
            value: jsonEncode(result),
          );
          return result;
        }
      } catch (_) {
        // Fallback to /users/me if /employees/{id} returns 404 or fails
      }
    }
    return getMyProfile();
  }

  Future<Map<String, dynamic>> updateEmployeeProfile(
    String employeeId,
    Map<String, dynamic> payload,
  ) async {
    String idToUse = employeeId.trim();

    if (idToUse.isEmpty || !_isUuid(idToUse)) {
      final cached = await getCachedProfile();
      if (cached != null) {
        final extracted = extractEmployeeId(cached);
        if (extracted != null && extracted.isNotEmpty) {
          idToUse = extracted;
        }
      }
    }

    if (idToUse.isEmpty) {
      throw const ApiException('Employee ID is required for profile update.');
    }

    final response = await _apiClient.put('/employees/$idToUse', body: payload);
    final data = ApiClient.unwrap(response) ?? {};
    final updated = data is Map ? Map<String, dynamic>.from(data) : payload;

    final current = await getCachedProfile() ?? {};
    final merged = Map<String, dynamic>.from(current)..addAll(updated);
    _memoryCache = merged;
    await _secureStorage.write(
      key: 'cached_profile',
      value: jsonEncode(merged),
    );
    return merged;
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    final cached = await getCachedProfile();
    final empId = cached != null ? extractEmployeeId(cached) : null;
    if (empId != null && empId.isNotEmpty) {
      return updateEmployeeProfile(empId, payload);
    }
    throw const ApiException('Employee ID is required to update profile.');
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _apiClient.post(
      '/users/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
