import 'api_client.dart';

class DashboardApiService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getStats() async {
    final response = await _apiClient.get('/dashboard/stats');
    final data = ApiClient.unwrap(response);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> getAttendanceTrend({int days = 7}) async {
    final response = await _apiClient.get(
      '/dashboard/attendance-trend',
      queryParams: {'days': days.toString()},
    );
    final data = ApiClient.unwrap(response);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> getDepartmentDistribution() async {
    final response = await _apiClient.get('/dashboard/department-distribution');
    final data = ApiClient.unwrap(response);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<List<Map<String, dynamic>>> getUpcomingBirthdays({
    int days = 7,
  }) async {
    final response = await _apiClient.get(
      '/dashboard/upcoming-birthdays',
      queryParams: {'days': days.toString()},
    );
    final data = ApiClient.unwrap(response);
    if (data is List) {
      return data
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
          )
          .toList();
    }
    return [];
  }
}
