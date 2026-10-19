ETAPRISE HRMS FLUTTER — BACKEND SERVICE LAYER
=============================================

API base URL
------------
https://hrms.etaprise.ai/api

This bundle contains the service layer for the frontend pages you shared.
It intentionally does not redesign or replace your UI widgets. These services
return decoded JSON maps/lists so each page can map the API data to its current
private UI model without coupling the service layer to widget implementation.

FILES
-----
services/api_client.dart
  Shared HTTP, JSON decoding, Bearer token, secure storage, response envelope
  handling and API exceptions.

services/auth_service.dart
  Login, register, forgot/reset password, refresh session, logout, session data.

services/dashboard_api_service.dart
  Dashboard stats, attendance trend, monthly attendance trend, department
  distribution and upcoming birthdays.

services/profile_api_service.dart
  GET /users/me, user details/update and change-password.

services/attendance_api_service.dart
  Today's attendance, date/history, check-in/out, break start/end, attendance
  correction requests, summary and attendance rules.

services/leave_api_service.dart
  My leave requests, leave balances, holidays, apply/cancel leave, list/pending
  requests.

services/announcements_api_service.dart
  List/detail/create/update/delete announcements.

services/notifications_api_service.dart
  Notifications list, unread count, mark read/all read and delete.

services/training_api_service.dart
  My courses, courses, enroll, training progress/history, certificates and
  lecture progress.

services/courses_api_service.dart
  Convenient wrapper for MyCoursesPage.

services/certifications_api_service.dart
  Convenient wrapper for MyCertificationsPage.

services/hrms_services.dart
  Barrel export for the service classes.

DEPENDENCIES
------------
Run in the Flutter project root:

  flutter pub add http flutter_secure_storage

Then:

  flutter pub get

IMPORTANT AUTH STORAGE DETAIL
-----------------------------
The service client stores the access token under `auth_token`, the refresh
token under `refresh_token`, and the current user under `auth_user`.
All authenticated requests automatically send:
  Authorization: Bearer <access-token>

The AuthService methods and storage keys are compatible with the login page and
shell code you shared. If you already have a different auth_service.dart, back
it up and replace it with the version in this bundle so token storage matches
the shared ApiClient.

HOW TO IMPORT
-------------
  import '../services/attendance_api_service.dart';

Example:
  final service = AttendanceApiService();
  final today = await service.getToday();

For My Leave:
  final service = LeaveApiService();
  final requests = await service.getMyLeaveRequests();
  final balances = await service.getLeaveBalances();

For profile:
  final profile = await ProfileApiService().getMyProfile();

For notifications:
  final service = NotificationsApiService();
  final unread = await service.getUnreadCount();

For training:
  final courses = await CoursesApiService().getMyCourses();
  final certificates =
      await CertificationsApiService().getMyCertificates();

API CONTRACT / LIMITATIONS
--------------------------
- Endpoints were taken from the Swagger/OpenAPI file you shared.
- GET /leave/holidays has no response schema documented in that file; the
  service parses common list/envelope shapes, but actual response needs runtime
  verification.
- Profile editing uses PUT /users/{id}; the caller must supply the authenticated
  user's actual id, available from GET /users/me.
- Check-in/out payload fields follow CheckInOutDto in Swagger. Location, face
  verification and work-mode values must follow your backend's validation rules.
- Course enrollment endpoint is /trainings/{id}/enroll in the provided Swagger.
- These files have not been run through `flutter analyze` against your complete
  local project because the full Flutter project folder was not uploaded.
- API success, response field casing, authorization and endpoint validation
  still need to be tested against the running backend.

NEXT INTEGRATION STEP
---------------------
Copy the `services` directory into `lib/services/` (merge carefully if the
folder already exists). Then connect each page's initState/load and submit
handlers to these service methods. Service files alone do not automatically
replace the sample lists inside the UI pages.
