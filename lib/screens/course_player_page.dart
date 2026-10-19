import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api_client.dart';
import '../services/training_api_service.dart';
import '../theme/app_colors.dart';

class CoursePlayerPage extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String instructor;
  final String description;
  final double initialProgress;

  const CoursePlayerPage({
    super.key,
    this.courseId = '',
    this.courseTitle = 'Course Player',
    this.instructor = 'Etaprise Technical Academy',
    this.description = '',
    this.initialProgress = 0.0,
  });

  @override
  State<CoursePlayerPage> createState() => _CoursePlayerPageState();
}

class _CoursePlayerPageState extends State<CoursePlayerPage> {
  final TrainingApiService _trainingApi = TrainingApiService();

  int _activeLessonIndex = 0;
  List<Map<String, dynamic>> _lessons = [];
  bool _loading = true;
  String? _error;

  WebViewController? _webViewController;
  bool _isVideoLoading = true;
  String? _videoError;
  String? _currentVideoUrl;

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  Future<void> _loadCourseData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // 1. Fetch lectures for course
      List<dynamic> lecturesData = [];
      if (widget.courseId.isNotEmpty) {
        lecturesData = await _trainingApi.getLectures(widget.courseId);
      }

      // 2. Fetch progress for course
      Set<String> completedIds = {};
      if (widget.courseId.isNotEmpty) {
        try {
          final progressList = await _trainingApi.getProgress(courseId: widget.courseId);
          if (progressList.isNotEmpty) {
            final progMap = progressList.first;
            if (progMap is Map && progMap['completedLectureIds'] is List) {
              completedIds = Set<String>.from(progMap['completedLectureIds']);
            }
          }
        } on ApiException catch (e) {
          debugPrint('[CoursePlayerPage] Progress API Notice ${e.statusCode}: ${e.message}');
        }
      }

      final parsedLessons = <Map<String, dynamic>>[];
      for (int i = 0; i < lecturesData.length; i++) {
        final item = lecturesData[i];
        if (item is Map) {
          final id = item['id']?.toString() ?? 'lec_$i';
          final title = item['title']?.toString() ?? 'Lesson ${i + 1}';
          final duration = item['duration']?.toString() ?? '15 mins';
          final contentUrl = item['contentUrl']?.toString() ??
              item['videoUrl']?.toString() ??
              item['url']?.toString() ??
              '';
          final content = item['description']?.toString() ??
              item['contentData']?.toString() ??
              'No summary provided for this lesson.';
          final isCompleted = completedIds.contains(id) || item['completed'] == true;

          parsedLessons.add({
            'id': id,
            'title': title,
            'duration': duration,
            'contentUrl': contentUrl,
            'content': content,
            'completed': isCompleted,
          });
        }
      }

      if (!mounted) return;

      setState(() {
        _lessons = parsedLessons;
        _loading = false;

        // Auto select first uncompleted lesson
        final firstUncompleted = _lessons.indexWhere((l) => l['completed'] == false);
        _activeLessonIndex = firstUncompleted != -1 ? firstUncompleted : 0;
      });

      if (_lessons.isNotEmpty) {
        _setupVideoPlayer(_lessons[_activeLessonIndex]['contentUrl']?.toString());
      }
    } on ApiException catch (e) {
      debugPrint('[CoursePlayerPage] ApiException status=${e.statusCode}: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load course lectures (Status ${e.statusCode}): ${e.message}';
        _loading = false;
      });
    } catch (e) {
      debugPrint('[CoursePlayerPage] Error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Error loading course details: ${e.toString().replaceFirst('Exception: ', '')}';
        _loading = false;
      });
    }
  }

  void _setupVideoPlayer(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      setState(() {
        _videoError = 'No video stream URL provided for this lesson.';
        _isVideoLoading = false;
        _webViewController = null;
      });
      return;
    }

    final url = rawUrl.trim();
    if (_currentVideoUrl == url && _webViewController != null) return;

    _currentVideoUrl = url;
    setState(() {
      _isVideoLoading = true;
      _videoError = null;
    });

    final embedUrl = _extractEmbedUrl(url);

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _isVideoLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isVideoLoading = false);
            },
            onWebResourceError: (error) {
              debugPrint('[CoursePlayerPage] WebView Error: ${error.description}');
              if (mounted) {
                setState(() {
                  _videoError = 'Unable to play video: ${error.description}';
                  _isVideoLoading = false;
                });
              }
            },
          ),
        );

      if (embedUrl.startsWith('http://') || embedUrl.startsWith('https://')) {
        controller.loadRequest(Uri.parse(embedUrl));
      } else {
        // Load custom responsive HTML player
        final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; background-color: #000; display: flex; justify-content: center; align-items: center; height: 100vh; color: #fff; font-family: sans-serif; }
    iframe, video { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  $embedUrl
</body>
</html>
''';
        controller.loadHtmlString(html);
      }

      setState(() {
        _webViewController = controller;
      });
    } catch (e) {
      debugPrint('[CoursePlayerPage] WebView init error: $e');
      setState(() {
        _videoError = 'Video player initialization error.';
        _isVideoLoading = false;
      });
    }
  }

  String _extractEmbedUrl(String rawUrl) {
    final url = rawUrl.trim();

    // YouTube regex pattern matching
    final ytMatch = RegExp(
      r'(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})',
      caseSensitive: false,
    ).firstMatch(url);

    if (ytMatch != null && ytMatch.groupCount >= 1) {
      final videoId = ytMatch.group(1);
      return 'https://www.youtube.com/embed/$videoId?autoplay=1&playsinline=1&enablejsapi=1';
    }

    if (url.startsWith('<iframe')) {
      return url;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    return '<p style="text-align:center;">Video unavailable</p>';
  }

  double get _progress {
    if (_lessons.isEmpty) return widget.initialProgress;
    final completedCount = _lessons.where((l) => l['completed'] == true).length;
    return completedCount / _lessons.length;
  }

  Future<void> _toggleLessonComplete(int idx) async {
    final lesson = _lessons[idx];
    final bool currentStatus = lesson['completed'] as bool;
    final String lessonId = lesson['id'].toString();

    setState(() {
      _lessons[idx]['completed'] = !currentStatus;
    });

    if (!currentStatus && widget.courseId.isNotEmpty) {
      try {
        await _trainingApi.markLectureComplete(widget.courseId, lessonId);
      } on ApiException catch (e) {
        debugPrint('[CoursePlayerPage] Complete lecture API error status=${e.statusCode}: ${e.message}');
      } catch (e) {
        debugPrint('[CoursePlayerPage] Mark lecture error: $e');
      }
    }
  }

  void _selectLesson(int index) {
    setState(() {
      _activeLessonIndex = index;
    });
    if (_lessons.isNotEmpty && index < _lessons.length) {
      _setupVideoPlayer(_lessons[index]['contentUrl']?.toString());
    }
  }

  void _showCertificate() {
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppColors.isDarkMode,
          builder: (context, dark, _) {
            return AlertDialog(
              backgroundColor: dark ? AppColors.graphite : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: AppColors.copper,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Course Certificate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.copper.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.copper),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CERTIFICATE OF COMPLETION',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.courseTitle,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Instructor: ${widget.instructor}',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloading Certificate PDF...'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.copper,
                  ),
                  icon: const Icon(
                    Icons.download,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Download PDF',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLesson = _lessons.isNotEmpty && _activeLessonIndex < _lessons.length
        ? _lessons[_activeLessonIndex]
        : null;

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          appBar: AppBar(
            backgroundColor: dark ? const Color(0xFF1E2124) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.text(dark),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              widget.courseTitle,
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Player Section
                Container(
                  height: 220,
                  width: double.infinity,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_webViewController != null && _videoError == null)
                        WebViewWidget(controller: _webViewController!)
                      else if (_videoError != null)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.video_camera_back_outlined,
                                color: Colors.white54,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _videoError!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              size: 56,
                              color: AppColors.copper.withValues(alpha: 0.9),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Select a lesson to play video',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      if (_isVideoLoading && _webViewController != null && _videoError == null)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.copper,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.courseTitle,
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Instructor: ${widget.instructor}',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 12.5,
                        ),
                      ),
                      if (widget.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Course Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Course Progress',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${(_progress * 100).toInt()}% Completed',
                            style: TextStyle(
                              color: AppColors.copper,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.fieldFill(dark),
                        color: _progress == 1.0
                            ? const Color(0xFF2E7D32)
                            : AppColors.copper,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),

                      if (_progress == 1.0) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showCertificate,
                            icon: const Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'View Certificate of Completion',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Active Lesson Summary
                      if (activeLesson != null)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppColors.cardDecoration(dark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      activeLesson['title'].toString(),
                                      style: TextStyle(
                                        color: AppColors.text(dark),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    activeLesson['duration'].toString(),
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeLesson['content'].toString(),
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      Text(
                        'Course Modules & Lessons',
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.copper,
                            ),
                          ),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadCourseData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.copper,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (_lessons.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: AppColors.cardDecoration(dark),
                          child: Column(
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 32,
                                color: AppColors.muted(dark),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No lectures available for this course.',
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lessons.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final lesson = _lessons[index];
                            final isSelected = _activeLessonIndex == index;
                            final isDone = lesson['completed'] as bool;

                            return InkWell(
                              onTap: () => _selectLesson(index),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.copper.withValues(alpha: 0.15)
                                      : AppColors.cardColor(dark),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.copper
                                        : AppColors.glassBorder(dark),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isDone,
                                      activeColor: AppColors.copper,
                                      onChanged: (_) => _toggleLessonComplete(index),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lesson['title'].toString(),
                                            style: TextStyle(
                                              color: AppColors.text(dark),
                                              fontSize: 12.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            lesson['duration'].toString(),
                                            style: TextStyle(
                                              color: AppColors.muted(dark),
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.play_circle_outline,
                                        color: AppColors.copper,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
