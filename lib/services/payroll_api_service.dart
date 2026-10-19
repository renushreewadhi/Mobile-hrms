import 'api_client.dart';
import 'profile_api_service.dart';

class PayrollApiService {
  final ApiClient _apiClient = ApiClient();
  final ProfileApiService _profileApi = ProfileApiService();

  /// Fetches the logged-in employee's active salary workflow and structure
  /// Endpoint: GET /api/salary/my
  Future<Map<String, dynamic>> getMySalary() async {
    for (final endpoint in [
      '/salary/my',
      '/payroll/my-structure',
      '/payroll/salary-structures/my',
      '/salary/structure/my',
    ]) {
      try {
        final response = await _apiClient.get(endpoint);
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is Map && unwrapped.isNotEmpty) {
          return Map<String, dynamic>.from(unwrapped);
        }
      } catch (_) {}
    }
    return {};
  }

  /// Fetches the logged-in employee's salary and payslip history
  /// Endpoint: GET /api/salary/my/history
  Future<List<dynamic>> getMySalaryHistory() async {
    for (final endpoint in [
      '/salary/my/history',
      '/salary/history',
      '/payroll/my',
      '/payroll/my-history',
      '/payslips/my',
      '/payroll/payslips',
    ]) {
      try {
        final response = await _apiClient.get(endpoint);
        final unwrapped = ApiClient.unwrap(response);
        if (unwrapped is List && unwrapped.isNotEmpty) return unwrapped;
        if (unwrapped is Map) {
          final list = unwrapped['data'] ?? unwrapped['items'] ?? unwrapped['history'];
          if (list is List && list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Fetches a specific monthly payslip for the logged-in employee
  /// Endpoint: GET /api/salary/my/payslip?month={month}&year={year}
  Future<Map<String, dynamic>> getMyPayslip(String month, int year) async {
    try {
      final response = await _apiClient.get(
        '/salary/my/payslip',
        queryParams: {'month': month, 'year': year.toString()},
      );
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is Map) {
        return Map<String, dynamic>.from(unwrapped);
      }
    } catch (_) {}

    // Fallback to GET /api/payroll/payslip/my
    try {
      final response = await _apiClient.get(
        '/payroll/payslip/my',
        queryParams: {'month': month, 'year': year.toString()},
      );
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is Map) {
        return Map<String, dynamic>.from(unwrapped);
      }
    } catch (_) {}

    return {};
  }

  /// Fetches salary structure details for an employee
  /// Endpoint: GET /api/payroll/salary-structures/employee/{employeeId}
  Future<Map<String, dynamic>> getEmployeeSalaryStructure(
    String employeeId,
  ) async {
    if (employeeId.isEmpty) return {};
    try {
      final response = await _apiClient.get(
        '/payroll/salary-structures/employee/$employeeId',
      );
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is Map) {
        return Map<String, dynamic>.from(unwrapped);
      }
    } catch (_) {}
    return {};
  }
}
