import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'profile_api_service.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      includeAuth: false,
    );

    final data = ApiClient.unwrap(response);

    if (data is! Map) {
      throw Exception('Invalid login response from the server.');
    }

    final result = Map<String, dynamic>.from(data);

    final token =
        result['token'] ?? result['accessToken'] ?? result['access_token'];

    if (token == null || token.toString().trim().isEmpty) {
      throw Exception(
        result['message']?.toString() ??
            'Login succeeded without an access token.',
      );
    }

    // Save the authentication token using the existing ApiClient.
    await _apiClient.setToken(token.toString());

    // Save the complete login response for profile resolution.
    await _secureStorage.write(key: 'auth_user', value: jsonEncode(result));

    // Clear any profile cached from a previous login.
    ProfileApiService.clearCache();

    return result;
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String confirmPassword,
    String? role,
    String? ppt,
    String? department,
    String? designation,
  }) async {
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email.trim(),
      'password': password,
      'confirmPassword': confirmPassword,
    };
    if (role != null) body['role'] = role;
    if (ppt != null) body['ppt'] = ppt;
    if (department != null) body['department'] = department;
    if (designation != null) body['designation'] = designation;

    final response = await _apiClient.post(
      '/auth/register',
      body: body,
      includeAuth: false,
    );

    final data = ApiClient.unwrap(response);

    return data is Map ? Map<String, dynamic>.from(data) : {'raw': data};
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {
      // Logout must still clear local credentials if the request fails.
    }

    await _apiClient.clearToken();

    ProfileApiService.clearCache();
    await _secureStorage.delete(key: 'auth_user');
  }

  Future<bool> isLoggedIn() async {
    final token = await _apiClient.getToken();

    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getCurrentStoredUser() async {
    final userString = await _secureStorage.read(key: 'auth_user');

    if (userString == null || userString.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(userString);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final response = await _apiClient.post(
      '/auth/forgot-password',
      body: {'email': email.trim()},
      includeAuth: false,
    );

    final data = ApiClient.unwrap(response);

    return data is Map ? Map<String, dynamic>.from(data) : {'raw': data};
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _apiClient.post(
      '/auth/reset-password',
      body: {
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      includeAuth: false,
    );

    final data = ApiClient.unwrap(response);

    return data is Map ? Map<String, dynamic>.from(data) : {'raw': data};
  }
}
