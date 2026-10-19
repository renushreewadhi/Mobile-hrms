import 'api_client.dart';

class BenefitsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMyBenefits() async {
    final response = await _apiClient.get('/benefits/my');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list =
          unwrapped['data'] ??
          unwrapped['benefits'] ??
          unwrapped['enrollments'] ??
          unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<List<dynamic>> getMyClaims() async {
    final response = await _apiClient.get('/benefits/my/claims');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  Future<dynamic> submitClaim(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/benefits/my/claims',
      body: payload,
    );
    return ApiClient.unwrap(response);
  }
}
