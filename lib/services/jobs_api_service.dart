import 'api_client.dart';

class JobsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getJobs() async {
    final response = await _apiClient.get('/recruitment/jobs/public');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list = unwrapped['data'] ?? unwrapped['jobs'] ?? unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<dynamic> applyForJob(
    String jobId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/recruitment/jobs/$jobId/apply',
      body: payload,
    );
    return ApiClient.unwrap(response);
  }
}
