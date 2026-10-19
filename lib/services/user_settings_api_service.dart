import 'api_client.dart';

class UserSettingsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<dynamic> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final body = {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
    final response = await _apiClient.post(
      '/user-settings/change-password',
      body: body,
    );
    return ApiClient.unwrap(response);
  }

  Future<Map<String, dynamic>> getSummary() async {
    final response = await _apiClient.get('/user-settings/summary');
    final unwrapped = ApiClient.unwrap(response);
    return unwrapped is Map ? Map<String, dynamic>.from(unwrapped) : {};
  }
}
