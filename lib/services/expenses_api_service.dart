import 'api_client.dart';

class ExpensesApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getMyExpenses() async {
    final response = await _apiClient.get('/Expense/my');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map) {
      final list =
          unwrapped['data'] ?? unwrapped['expenses'] ?? unwrapped['items'];
      if (list is List) return list;
    }
    return [];
  }

  Future<List<dynamic>> getCategories() async {
    final response = await _apiClient.get('/Expense/categories');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  Future<dynamic> submitExpense(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('/Expense', body: payload);
    return ApiClient.unwrap(response);
  }
}
