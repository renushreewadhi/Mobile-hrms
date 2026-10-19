import 'api_client.dart';

class TasksApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMyTasks({String? employeeId}) async {
    final endpoint = (employeeId != null && employeeId.isNotEmpty)
        ? '/tasks/employee/$employeeId'
        : '/tasks/my';
    final response = await _apiClient.get(endpoint);
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list =
          unwrapped['data'] ?? unwrapped['tasks'] ?? unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<dynamic> getTaskDetail(String id) async {
    final response = await _apiClient.get('/tasks/$id');
    return ApiClient.unwrap(response);
  }

  Future<dynamic> updateTaskStatus(String id, String status) async {
    final response = await _apiClient.put(
      '/tasks/$id/status',
      body: {'status': status},
    );
    return ApiClient.unwrap(response);
  }

  Future<dynamic> createTask(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/tasks', body: payload);
    return ApiClient.unwrap(response);
  }
}
