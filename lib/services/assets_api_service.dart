import 'api_client.dart';

class AssetsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMyAssets() async {
    for (final endpoint in ['/assets/my', '/assets/my-assets', '/assets/assigned', '/assets/employee', '/assets']) {
      try {
        final response = await _apiClient.get(endpoint);
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
        if (unwrapped is Map) {
          final list = unwrapped['data'] ?? unwrapped['assets'] ?? unwrapped['items'];
          if (list is List && list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return [];
  }

  Future<List<dynamic>> getMyRequests() async {
    final response = await _apiClient.get('/assets/my/requests');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  Future<dynamic> requestAsset(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/assets/requests', body: payload);
    return ApiClient.unwrap(response);
  }
}
