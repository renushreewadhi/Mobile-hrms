import 'api_client.dart';

class AttendanceApiService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch today's attendance record for current user or given employee
  Future<dynamic> getTodayAttendance({String? employeeId}) async {
    final nowStr = DateTime.now().toIso8601String().split('T')[0];
    
    // First try GET /attendance/my-date/{date} if no employeeId or if it's current user
    try {
      final response = await _apiClient.get('/attendance/my-date/$nowStr');
      final unwrapped = ApiClient.unwrap(response);
      if (unwrapped is Map && unwrapped.isNotEmpty) {
        return unwrapped;
      }
    } catch (_) {}

    final endpoint = (employeeId != null && employeeId.isNotEmpty)
        ? '/attendance/employee/$employeeId?startDate=$nowStr&endDate=$nowStr'
        : '/attendance/today';

    final response = await _apiClient.get(endpoint);
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is Map && unwrapped.isNotEmpty) {
      return unwrapped;
    }
    if (unwrapped is List && unwrapped.isNotEmpty) {
      for (final item in unwrapped) {
        if (item is Map) {
          final d = item['date']?.toString();
          if (d != null && d.contains(nowStr)) {
            return item;
          }
        }
      }
      return unwrapped.first;
    }
    return {};
  }

  /// Fetch attendance for specific date
  Future<dynamic> getMyAttendanceByDate(String dateStr) async {
    final response = await _apiClient.get('/attendance/my-date/$dateStr');
    return ApiClient.unwrap(response);
  }

  /// Fetch employee attendance history for a date range
  Future<List<dynamic>> getEmployeeAttendance(
    String employeeId, {
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      query['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      query['endDate'] = endDate;
    }
    final response = await _apiClient.get(
      '/attendance/employee/$employeeId',
      queryParams: query.isNotEmpty ? query : null,
    );
    final data = ApiClient.unwrap(response);
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'];
    if (data is Map) return [data];
    return [];
  }

  /// Fetch overall attendance history
  Future<dynamic> getAttendanceHistory({
    String? startDate,
    String? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      query['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      query['endDate'] = endDate;
    }
    final response = await _apiClient.get(
      '/attendance',
      queryParams: query.isNotEmpty ? query : null,
    );
    return ApiClient.unwrap(response);
  }

  /// Get office location & geofence settings
  Future<dynamic> getOfficeLocation() async {
    final response = await _apiClient.get('/attendance/office-location');
    return ApiClient.unwrap(response);
  }

  /// Validate current GPS position against office geofence
  Future<dynamic> validateGeofence({
    required double latitude,
    required double longitude,
    String? location,
  }) async {
    final body = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (location != null) 'location': location,
    };
    final response = await _apiClient.post(
      '/attendance/validate-geofence',
      body: body,
    );
    return ApiClient.unwrap(response);
  }

  /// Verify face selfie independently
  Future<dynamic> verifyFace({
    double? latitude,
    double? longitude,
    String? location,
    String? capturedFaceBase64,
    String? verificationType,
  }) async {
    final body = <String, dynamic>{
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (location != null) 'location': location,
      if (capturedFaceBase64 != null) 'capturedFaceBase64': capturedFaceBase64,
      'verificationType': verificationType ?? 'CLOCK_IN',
    };
    final response = await _apiClient.post(
      '/attendance/verify-face',
      body: body,
    );
    return ApiClient.unwrap(response);
  }

  /// Punch In / Clock In endpoint matching exact CheckInOutDto schema
  Future<dynamic> punchIn({
    double? latitude,
    double? longitude,
    String? notes,
    String? location,
    String? capturedFaceBase64,
    String? verificationType,
    String? workMode,
    String? wfhReason,
    bool? isGalleryUpload,
  }) async {
    final body = <String, dynamic>{
      'workMode': workMode ?? 'OFFICE',
      'isGalleryUpload': isGalleryUpload ?? false,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
      if (location != null) 'location': location,
      if (capturedFaceBase64 != null) 'capturedFaceBase64': capturedFaceBase64,
      if (verificationType != null) 'verificationType': verificationType,
      if (wfhReason != null) 'wfhReason': wfhReason,
    };

    final response = await _apiClient.post(
      '/attendance/check-in',
      body: body,
    );
    return ApiClient.unwrap(response);
  }

  /// Punch Out / Clock Out endpoint matching exact CheckInOutDto schema
  Future<dynamic> punchOut({
    double? latitude,
    double? longitude,
    String? notes,
    String? location,
    String? capturedFaceBase64,
    String? verificationType,
    String? workMode,
    String? wfhReason,
    bool? isGalleryUpload,
  }) async {
    final body = <String, dynamic>{
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
      if (location != null) 'location': location,
      if (capturedFaceBase64 != null) 'capturedFaceBase64': capturedFaceBase64,
      if (verificationType != null) 'verificationType': verificationType,
      if (workMode != null) 'workMode': workMode,
      if (wfhReason != null) 'wfhReason': wfhReason,
      if (isGalleryUpload != null) 'isGalleryUpload': isGalleryUpload,
    };

    final response = await _apiClient.post(
      '/attendance/check-out',
      body: body,
    );
    return ApiClient.unwrap(response);
  }

  /// Start Break endpoint
  Future<dynamic> startBreak({String? breakType, String? reason}) async {
    final body = <String, dynamic>{
      'breakType': breakType ?? 'SHORT',
      if (reason != null) 'reason': reason,
    };

    final response = await _apiClient.post(
      '/attendance/break/start',
      body: body,
    );
    return ApiClient.unwrap(response);
  }

  /// End Break endpoint
  Future<dynamic> endBreak() async {
    final response = await _apiClient.post(
      '/attendance/break/end',
      body: <String, dynamic>{},
    );
    return ApiClient.unwrap(response);
  }

  /// Get current employee shift
  Future<dynamic> getMyShift() async {
    final response = await _apiClient.get('/shifts/my-shift');
    return ApiClient.unwrap(response);
  }

  /// Fetch correction requests
  Future<dynamic> getCorrections({String? status, String? employeeId}) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (employeeId != null && employeeId.isNotEmpty) {
      query['employeeId'] = employeeId;
    }
    final response = await _apiClient.get(
      '/attendance/corrections',
      queryParams: query.isNotEmpty ? query : null,
    );
    return ApiClient.unwrap(response);
  }

  /// Submit correction / regularization request
  Future<dynamic> requestCorrection(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/attendance/correction-request',
      body: payload,
    );
    return ApiClient.unwrap(response);
  }

  /// Fetch attendance rules
  Future<dynamic> getRules({bool? activeOnly}) async {
    final query = <String, String>{};
    if (activeOnly != null) query['activeOnly'] = activeOnly.toString();
    final response = await _apiClient.get(
      '/attendance/rules',
      queryParams: query.isNotEmpty ? query : null,
    );
    return ApiClient.unwrap(response);
  }

  /// Get attendance summary for statistics
  Future<dynamic> getSummary({String? startDate, String? endDate}) async {
    final query = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) query['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) query['endDate'] = endDate;
    final response = await _apiClient.get(
      '/attendance/summary',
      queryParams: query.isNotEmpty ? query : null,
    );
    return ApiClient.unwrap(response);
  }
}
