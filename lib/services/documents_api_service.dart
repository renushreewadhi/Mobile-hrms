import 'api_client.dart';
import 'profile_api_service.dart';

class DocumentsApiService {
  final ApiClient _apiClient = ApiClient();
  final ProfileApiService _profileApi = ProfileApiService();

  Future<List<dynamic>> getMyDocuments({String? category}) async {
    // 1. Try /documents/mine
    try {
      final query = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        query['category'] = category;
      }
      final response = await _apiClient.get(
        '/documents/mine',
        queryParams: query.isNotEmpty ? query : null,
      );
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
      if (unwrapped is Map) {
        final list =
            unwrapped['data'] ?? unwrapped['documents'] ?? unwrapped['items'];
        if (list is List && list.isNotEmpty) return list;
      }
    } catch (_) {}

    // 2. Try fetching employee ID from profile, then /documents?employeeId={id}
    try {
      final cachedProfile = await _profileApi.getCachedProfile();
      final empId = cachedProfile != null
          ? ProfileApiService.extractEmployeeId(cachedProfile)
          : null;
      if (empId != null && empId.isNotEmpty) {
        final query = <String, String>{'employeeId': empId};
        if (category != null && category.isNotEmpty && category != 'All') {
          query['category'] = category;
        }
        final response = await _apiClient.get(
          '/documents',
          queryParams: query,
        );
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
        if (unwrapped is Map) {
          final list =
              unwrapped['data'] ?? unwrapped['documents'] ?? unwrapped['items'];
          if (list is List && list.isNotEmpty) return list;
        }
      }
    } catch (_) {}

    // 3. Fallback to /documents
    try {
      final query = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        query['category'] = category;
      }
      final response = await _apiClient.get(
        '/documents',
        queryParams: query.isNotEmpty ? query : null,
      );
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is List) return unwrapped;
      if (unwrapped is Map) {
        final list =
            unwrapped['data'] ?? unwrapped['documents'] ?? unwrapped['items'];
        if (list is List) return list;
      }
    } catch (_) {}

    return [];
  }

  Future<dynamic> deleteDocument(String id) async {
    final response = await _apiClient.delete('/documents/$id');
    return ApiClient.unwrap(response);
  }
}
