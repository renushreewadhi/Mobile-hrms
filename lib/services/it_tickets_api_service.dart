import 'api_client.dart';

class ItTicketsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMyTickets() async {
    for (final ep in ['/it/tickets/my', '/tickets/my', '/it/tickets', '/tickets', '/support/tickets']) {
      try {
        final response = await _apiClient.get(ep);
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
        if (unwrapped is Map) {
          final list = unwrapped['data'] ?? unwrapped['tickets'] ?? unwrapped['items'];
          if (list is List && list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return [];
  }

  Future<dynamic> createTicket(Map<String, dynamic> payload) async {
    for (final ep in ['/it/tickets', '/tickets', '/support/tickets']) {
      try {
        final response = await _apiClient.post(ep, body: payload);
        return ApiClient.unwrap(response);
      } catch (_) {}
    }
    final response = await _apiClient.post('/it/tickets', body: payload);
    return ApiClient.unwrap(response);
  }

  Future<dynamic> addComment(String ticketId, String comment) async {
    final response = await _apiClient.post(
      '/it/tickets/$ticketId/comments',
      body: {'comment': comment, 'message': comment},
    );
    return ApiClient.unwrap(response);
  }
}
