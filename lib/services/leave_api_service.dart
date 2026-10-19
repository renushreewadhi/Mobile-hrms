import 'api_client.dart';

class LeaveApiService {
  final ApiClient _apiClient = ApiClient();

  Future<dynamic> getMyLeaveRequests({String? employeeId}) async {
    final endpoints = <String>[];
    if (employeeId != null && employeeId.isNotEmpty) {
      endpoints.add('/leave/employee/$employeeId');
    }
    endpoints.addAll(['/leave/my', '/leave/requests', '/leave/my-requests', '/leave']);

    for (final ep in endpoints) {
      try {
        final response = await _apiClient.get(ep);
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
        if (unwrapped is Map) {
          final list = unwrapped['data'] ?? unwrapped['requests'] ?? unwrapped['items'];
          if (list is List && list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return [];
  }

  Future<dynamic> getLeaveBalances({String? employeeId}) async {
    final endpoints = <String>[];
    if (employeeId != null && employeeId.isNotEmpty) {
      endpoints.add('/leave/balances/employee/$employeeId');
    }
    endpoints.addAll(['/leave/balances', '/leave/my/balances', '/leave/balance']);

    for (final ep in endpoints) {
      try {
        final response = await _apiClient.get(ep);
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
        if (unwrapped is Map) {
          final list = unwrapped['data'] ?? unwrapped['balances'] ?? unwrapped['items'];
          if (list is List && list.isNotEmpty) return list;
          if (unwrapped.isNotEmpty && !unwrapped.containsKey('data')) return unwrapped;
        }
      } catch (_) {}
    }
    return [];
  }

  Future<dynamic> getHolidays() async {
    final response = await _apiClient.get('/leave/holidays');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) {
      return unwrapped['data'];
    }
    return [];
  }

  Future<dynamic> applyLeave(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/leave/apply', body: payload);
    return ApiClient.unwrap(response);
  }

  Future<dynamic> cancelLeave(String requestId) async {
    final response = await _apiClient.post('/leave/$requestId/cancel');
    return ApiClient.unwrap(response);
  }
}
