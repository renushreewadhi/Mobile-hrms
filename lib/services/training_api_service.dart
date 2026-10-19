import 'package:flutter/foundation.dart';
import 'api_client.dart';

class TrainingApiService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch user's enrolled/assigned courses from GET /training/my-courses.
  /// If empty, also attempts GET /training/courses as catalog fallback.
  Future<List<dynamic>> getMyCourses() async {
    final response = await _apiClient.get('/training/my-courses');
    final unwrapped = ApiClient.unwrap(response);

    if (unwrapped is List && unwrapped.isNotEmpty) {
      return unwrapped;
    }
    if (unwrapped is Map && unwrapped['data'] is List) {
      final list = unwrapped['data'] as List;
      if (list.isNotEmpty) return list;
    }

    // Check course catalog if user has no assigned courses in my-courses
    try {
      final catalogResponse = await _apiClient.get('/training/courses');
      final catalogUnwrapped = ApiClient.unwrap(catalogResponse);
      if (catalogUnwrapped is List && catalogUnwrapped.isNotEmpty) {
        return catalogUnwrapped;
      }
      if (catalogUnwrapped is Map && catalogUnwrapped['data'] is List) {
        return catalogUnwrapped['data'];
      }
    } on ApiException catch (e) {
      debugPrint('[TrainingApiService] Catalog fetch status ${e.statusCode}: ${e.message}');
    }

    if (unwrapped is List) return unwrapped;
    return [];
  }

  /// Fetch available courses from GET /training/courses.
  Future<List<dynamic>> getCourses() async {
    final response = await _apiClient.get('/training/courses');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  /// Fetch course details by ID from GET /training/courses/{id}.
  Future<Map<String, dynamic>?> getCourse(String courseId) async {
    if (courseId.isEmpty) return null;
    final response = await _apiClient.get('/training/courses/$courseId');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is Map) return Map<String, dynamic>.from(unwrapped);
    return null;
  }

  /// Fetch lectures for a course from GET /training/courses/{courseId}/lectures.
  Future<List<dynamic>> getLectures(String courseId) async {
    if (courseId.isEmpty) return [];
    final response = await _apiClient.get('/training/courses/$courseId/lectures');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  /// Fetch course progress from GET /training/progress.
  Future<List<dynamic>> getProgress({String? courseId}) async {
    final query = (courseId != null && courseId.isNotEmpty) ? {'courseId': courseId} : null;
    final response = await _apiClient.get('/training/progress', queryParams: query);
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  /// Mark lecture complete via POST /training/progress/{assignmentId}/lecture/{lectureId}/complete.
  Future<dynamic> markLectureComplete(String assignmentId, String lectureId) async {
    final response = await _apiClient.post(
      '/training/progress/$assignmentId/lecture/$lectureId/complete',
    );
    return ApiClient.unwrap(response);
  }

  /// Fetch certificates from GET /training/certificates.
  Future<List<dynamic>> getCertificates() async {
    final response = await _apiClient.get('/training/certificates');
    final unwrapped = ApiClient.unwrap(response);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map && unwrapped['data'] is List) return unwrapped['data'];
    return [];
  }

  /// Enroll in a training program.
  Future<dynamic> enroll(String trainingId) async {
    final response = await _apiClient.post(
      '/trainings/$trainingId/enroll',
      body: <String, dynamic>{},
    );
    return ApiClient.unwrap(response);
  }
}
