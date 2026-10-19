import 'api_client.dart';

class ProjectsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMyProjects() async {
    final response = await _apiClient.get('/projects/my');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list =
          unwrapped['data'] ?? unwrapped['projects'] ?? unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<dynamic> getProjectDetail(String id) async {
    final response = await _apiClient.get('/projects/$id');
    return ApiClient.unwrap(response);
  }
}
