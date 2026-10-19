import 'api_client.dart';

class WorkUpdatesApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMine({String? employeeId}) async {
    final endpoint = (employeeId != null && employeeId.isNotEmpty)
        ? '/work-updates/employee/$employeeId'
        : '/work-updates/my';
    final response = await _apiClient.get(endpoint);
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list =
          unwrapped['data'] ??
          unwrapped['workUpdates'] ??
          unwrapped['updates'] ??
          unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<List<dynamic>> getTeamToday() async {
    try {
      final response = await _apiClient.get('/work-updates/team/today');
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is List) return unwrapped;
      if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    } catch (_) {}
    return [];
  }

  Future<dynamic> submit(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/work-updates/submit',
      body: payload,
    );
    return ApiClient.unwrap(response);
  }

  Future<dynamic> review(String id, Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/work-updates/$id/review',
      body: payload,
    );
    return ApiClient.unwrap(response);
  }
}
