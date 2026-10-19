import 'api_client.dart';

class PerformanceApiService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _apiClient.get('/performance/dashboard/employee');
    final unwrapped = ApiClient.unwrap(response);
    return unwrapped is Map ? Map<String, dynamic>.from(unwrapped) : {};
  }

  Future<List<dynamic>> getMyGoals() async {
    final response = await _apiClient.get('/performance/goals/my');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list =
          unwrapped['data'] ??
          unwrapped['goals'] ??
          unwrapped['kpis'] ??
          unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<List<dynamic>> getMyReviews() async {
    final response = await _apiClient.get('/performance/reviews/my');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  Future<List<dynamic>> getCycles() async {
    final response = await _apiClient.get('/performance/cycles');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  Future<dynamic> submitSelfReview(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/performance/goals/self-review',
      body: payload,
    );
    return ApiClient.unwrap(response);
  }
}
