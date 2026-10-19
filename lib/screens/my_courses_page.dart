import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/training_api_service.dart';
import '../theme/app_colors.dart';
import 'course_player_page.dart';

/// My Courses page for the ETAPRISE HRMS mobile application.
/// Connects directly to backend training services for assigned courses.
class MyCoursesPage extends StatefulWidget {
  const MyCoursesPage({super.key});

  @override
  State<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends State<MyCoursesPage> {
  final TextEditingController _searchController = TextEditingController();
  final TrainingApiService _trainingApi = TrainingApiService();

  String _filter = 'All';
  String _query = '';
  List<_Course> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await _trainingApi.getMyCourses();

      final loadedCourses = <_Course>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final title = item['title']?.toString() ??
              item['courseTitle']?.toString() ??
              item['courseName']?.toString() ??
              item['name']?.toString() ??
              'Untitled Course';
          final provider = item['createdByName']?.toString() ??
              item['instructor']?.toString() ??
              item['provider']?.toString() ??
              item['categoryName']?.toString() ??
              'ETAPRISE Learning';
          final category = item['categoryName']?.toString() ??
              item['category']?.toString() ??
              'General';
          final duration = item['duration']?.toString() ??
              item['totalDuration']?.toString() ??
              'Self-paced';
          final description = item['description']?.toString() ??
              item['summary']?.toString() ??
              'No course description available.';
          final lessons = item['totalLectures'] != null
              ? int.tryParse(item['totalLectures'].toString()) ?? 0
              : (item['lecturesCount'] != null
                  ? int.tryParse(item['lecturesCount'].toString()) ?? 0
                  : 0);

          final rawStatus =
              item['status']?.toString().toUpperCase() ?? 'IN_PROGRESS';
          final status = rawStatus.contains('COMPLET')
              ? 'Completed'
              : (rawStatus.contains('NOT') || rawStatus.contains('DRAFT')
                  ? 'Not Started'
                  : 'In Progress');

          double progress = 0.0;
          if (item['progressPercentage'] != null) {
            progress = (double.tryParse(item['progressPercentage'].toString()) ??
                    0.0) /
                100.0;
          } else if (item['progress'] != null) {
            final rawP = double.tryParse(item['progress'].toString()) ?? 0.0;
            progress = rawP > 1.0 ? rawP / 100.0 : rawP;
          } else {
            progress = status == 'Completed'
                ? 1.0
                : (status == 'In Progress' ? 0.5 : 0.0);
          }

          final updated = item['updatedAt'] != null
              ? 'Updated ${_formatDate(item['updatedAt'].toString())}'
              : 'Assigned recently';

          loadedCourses.add(
            _Course(
              id: id,
              title: title,
              provider: provider,
              category: category,
              duration: duration,
              progress: progress.clamp(0.0, 1.0),
              status: status,
              updated: updated,
              description: description,
              lessons: lessons,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _courses = loadedCourses;
        _loading = false;
      });
    } on ApiException catch (e) {
      debugPrint('[MyCoursesPage] API Error status=${e.statusCode}: ${e.message}');
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 401 || e.statusCode == 403) {
          _error = 'Session expired or unauthorized (${e.statusCode}). Please log in again.';
        } else if (e.statusCode == 404) {
          _error = 'Course service endpoint not found (404).';
        } else {
          _error = 'API error (${e.statusCode ?? 'network'}): ${e.message}';
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MyCoursesPage] Unexpected Error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load courses: ${e.toString().replaceFirst('Exception: ', '')}';
        _loading = false;
      });
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  int get _completed => _courses.where((c) => c.status == 'Completed').length;
  int get _inProgress =>
      _courses.where((c) => c.status == 'In Progress').length;
  double get _overallProgress => _courses.isEmpty
      ? 0
      : _courses.fold<double>(0, (sum, c) => sum + c.progress) /
          _courses.length;

  List<_Course> get _visibleCourses {
    return _courses.where((course) {
      final matchesFilter = _filter == 'All' ||
          (_filter == 'In Progress' && course.status == 'In Progress') ||
          (_filter == 'Completed' && course.status == 'Completed') ||
          (_filter == 'Not Started' && course.status == 'Not Started');
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          course.title.toLowerCase().contains(q) ||
          course.provider.toLowerCase().contains(q) ||
          course.category.toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _openCoursePlayer(_Course course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePlayerPage(
          courseId: course.id,
          courseTitle: course.title,
          instructor: course.provider,
          description: course.description,
          initialProgress: course.progress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) => Scaffold(
        backgroundColor: dark ? AppColors.graphite : AppColors.cream,
        body: RefreshIndicator(
          onRefresh: _loadCourses,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    Text(
                      'My Courses',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Continue learning, track your progress, and complete assigned training.',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _hero(dark),
                    const SizedBox(height: 14),
                    _stats(dark),
                    const SizedBox(height: 18),
                    _search(dark),
                    const SizedBox(height: 12),
                    _filters(dark),
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your learning',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${_visibleCourses.length} ${_visibleCourses.length == 1 ? 'course' : 'courses'}',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.copper,
                          ),
                        ),
                      )
                    else if (_error != null && _courses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 36,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _loadCourses,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.copper,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_visibleCourses.isEmpty)
                      _surface(
                        dark,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 38,
                                color: AppColors.muted(dark),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No courses found',
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'There are no courses matching your query or assigned to your account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._visibleCourses.map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _courseCard(dark, course),
                        ),
                      ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        'ETAPRISE  •  HRMS',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(bool dark) => _surface(
        dark,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.copper.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.school_rounded,
                color: AppColors.accentText(dark),
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning Dashboard',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Overall course completion progress across assigned modules.',
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _stats(bool dark) {
    final pct = (_overallProgress * 100).round();
    return Row(
      children: [
        Expanded(
          child: _statCard(
            dark,
            '$pct%',
            'Completion',
            Icons.pie_chart_outline_rounded,
            AppColors.copper,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _statCard(
            dark,
            '$_inProgress',
            'In progress',
            Icons.timelapse_rounded,
            const Color(0xFF4285C5),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _statCard(
            dark,
            '$_completed',
            'Completed',
            Icons.task_alt_rounded,
            const Color(0xFF149B70),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    bool dark,
    String val,
    String label,
    IconData icon,
    Color tint,
  ) =>
      _surface(
        dark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(height: 10),
            Text(
              val,
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted(dark),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _search(bool dark) => TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _query = val),
        style: TextStyle(color: AppColors.text(dark), fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search courses, provider or category...',
          hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 11),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.muted(dark),
            size: 19,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.muted(dark),
                    size: 18,
                  ),
                ),
          filled: true,
          fillColor: AppColors.fieldFill(dark),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.glassBorder(dark)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.glassBorder(dark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.copper),
          ),
        ),
      );

  Widget _filters(bool dark) {
    final list = ['All', 'In Progress', 'Completed', 'Not Started'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((item) {
          final selected = _filter == item;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => setState(() => _filter = item),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.text(dark),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppColors.copper,
              backgroundColor: AppColors.fieldFill(dark),
              side: BorderSide(
                color: selected
                    ? AppColors.copper
                    : AppColors.glassBorder(dark),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _courseCard(bool dark, _Course course) {
    final statusColor = course.status == 'Completed'
        ? const Color(0xFF149B70)
        : course.status == 'In Progress'
            ? const Color(0xFF4285C5)
            : AppColors.muted(dark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openCoursePlayer(course),
        borderRadius: BorderRadius.circular(18),
        child: _surface(
          dark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.copper.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.category.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.copper,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                course.title,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${course.provider} • ${course.duration}${course.lessons > 0 ? ' • ${course.lessons} lessons' : ''}',
                style: TextStyle(color: AppColors.muted(dark), fontSize: 11),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: course.progress,
                  minHeight: 6,
                  backgroundColor: AppColors.glassBorder(dark),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${(course.progress * 100).round()}% complete',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _openCoursePlayer(course),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.copper,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      course.status == 'Completed' ? 'Review Course' : 'Continue',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surface(bool dark, {required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: AppColors.cardDecoration(dark, radius: 18),
            child: child,
          ),
        ),
      );
}

class _Course {
  const _Course({
    required this.id,
    required this.title,
    required this.provider,
    required this.category,
    required this.duration,
    required this.progress,
    required this.status,
    required this.updated,
    required this.description,
    required this.lessons,
  });

  final String id;
  final String title;
  final String provider;
  final String category;
  final String duration;
  final double progress;
  final String status;
  final String updated;
  final String description;
  final int lessons;
}
