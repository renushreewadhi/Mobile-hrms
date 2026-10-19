import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_demo/services/attendance_api_service.dart';

void main() {
  group('AttendanceApiService Initializer Tests', () {
    test('AttendanceApiService can be instantiated cleanly', () {
      final service = AttendanceApiService();
      expect(service, isNotNull);
    });
  });
}
