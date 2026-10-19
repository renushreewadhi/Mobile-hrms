import 'api_client.dart';

class AnnouncementsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<dynamic> getAnnouncements({String? role}) async {
    final query = <String, String>{};
    if (role != null) query['role'] = role;
    final response = await _apiClient.get('/announcements', queryParams: query);
    return ApiClient.unwrap(response);
  }

  Future<dynamic> getAnnouncementDetail(String id) async {
    final response = await _apiClient.get('/announcements/$id');
    return ApiClient.unwrap(response);
  }

  Future<dynamic> createAnnouncement(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/announcements', body: payload);
    return ApiClient.unwrap(response);
  }
}
