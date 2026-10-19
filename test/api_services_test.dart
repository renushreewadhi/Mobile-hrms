import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_demo/services/api_client.dart';
import 'package:my_first_demo/services/profile_api_service.dart';

void main() {
  group('ApiClient Unwrap & Parsing Tests', () {
    test('unwrap returns inner data when map contains data key', () {
      final response = {
        'success': true,
        'data': {'id': '123', 'name': 'John'},
        'message': null,
      };

      final unwrapped = ApiClient.unwrap(response);
      expect(unwrapped, equals({'id': '123', 'name': 'John'}));
    });

    test('unwrap returns list when data is a list', () {
      final response = {
        'success': true,
        'data': [
          {'id': '1'},
          {'id': '2'},
        ],
      };

      final unwrapped = ApiClient.unwrap(response);
      expect(unwrapped, isA<List>());
      expect((unwrapped as List).length, equals(2));
    });

    test('unwrap returns original object if data key absent', () {
      final rawList = [1, 2, 3];
      expect(ApiClient.unwrap(rawList), equals(rawList));
    });
  });

  group('ProfileApiService Extract Employee ID Tests', () {
    test('extracts top-level employeeId', () {
      final data = {
        'employeeId': 'emp-101',
        'firstName': 'Ravi',
      };

      final empId = ProfileApiService.extractEmployeeId(data);
      expect(empId, equals('emp-101'));
    });

    test('extracts nested employeeId from user/profile', () {
      final data = {
        'id': 'user-999',
        'employee': {
          'employeeId': 'emp-nested-55',
        },
      };

      final empId = ProfileApiService.extractEmployeeId(data);
      expect(empId, equals('emp-nested-55'));
    });

    test('falls back to id if no employeeId present', () {
      final data = {
        'id': 'user-777',
        'name': 'Test User',
      };

      final empId = ProfileApiService.extractEmployeeId(data);
      expect(empId, equals('user-777'));
    });

    test('returns null if no valid ID found', () {
      final data = <String, dynamic>{};
      expect(ProfileApiService.extractEmployeeId(data), isNull);
    });
  });

  group('ApiException Tests', () {
    test('ApiException holds message, status code, and response body', () {
      const exception = ApiException(
        'Unauthorized access',
        statusCode: 401,
        responseBody: {'error': 'Invalid token'},
      );

      expect(exception.message, equals('Unauthorized access'));
      expect(exception.statusCode, equals(401));
      expect(exception.responseBody, equals({'error': 'Invalid token'}));
      expect(exception.toString(), contains('401'));
    });
  });
}
