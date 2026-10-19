import 'api_client.dart';

class NotificationsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getNotifications({
    bool? isRead,
    String? category,
  }) async {
    final query = <String, String>{};
    if (isRead != null) query['isRead'] = isRead.toString();
    if (category != null && category.isNotEmpty) query['category'] = category;

    final response = await _apiClient.get(
      '/notifications',
      queryParams: query.isNotEmpty ? query : null,
    );
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/notifications/unread-count');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is num) return unwrapped.toInt();
    if (unwrapped is Map) {
      return (unwrapped['count'] ?? unwrapped['unreadCount'] ?? 0) as int;
    }
    return 0;
  }

  Future<dynamic> markRead(String id) async {
    final response = await _apiClient.put(
      '/notifications/$id/read',
      body: <String, dynamic>{},
    );
    return ApiClient.unwrap(response);
  }

  Future<dynamic> markAllRead() async {
    final response = await _apiClient.put(
      '/notifications/read-all',
      body: <String, dynamic>{},
    );
    return ApiClient.unwrap(response);
  }
}
