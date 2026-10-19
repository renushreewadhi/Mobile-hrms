import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/performance_api_service.dart';

class MyPerformancePage extends StatefulWidget {
  const MyPerformancePage({super.key});

  @override
  State<MyPerformancePage> createState() => _MyPerformancePageState();
}

class _MyPerformancePageState extends State<MyPerformancePage> {
  final PerformanceApiService _api = PerformanceApiService();

  String _selectedCycle = 'Current Cycle';
  List<String> _cycles = ['Current Cycle'];
  List<Map<String, dynamic>> _kpis = [];
  Map<String, dynamic> _dashboard = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getDashboard(),
        _api.getMyGoals(),
        _api.getCycles(),
      ]);

      if (!mounted) return;

      final rawDashboard = results[0];
      final rawGoals = results[1] is List ? (results[1] as List) : [];
      final rawCycles = results[2] is List ? (results[2] as List) : [];

      if (rawCycles.isNotEmpty) {
        final cList = rawCycles
            .map(
              (c) => c is Map
                  ? (c['name']?.toString() ?? c['title']?.toString() ?? '')
                  : c.toString(),
            )
            .where((s) => s.isNotEmpty)
            .toList();
        if (cList.isNotEmpty) {
          _cycles = cList;
          _selectedCycle = cList.first;
        }
      }

      final parsed = <Map<String, dynamic>>[];
      for (final item in rawGoals) {
        if (item is Map) {
          final title =
              item['title']?.toString() ??
              item['goalName']?.toString() ??
              item['kpiName']?.toString() ??
              'KPI Goal';
          final weightage = item['weightage'] != null
              ? '${item['weightage']}%'
              : '25%';
          final target =
              item['targetDescription']?.toString() ??
              item['target']?.toString() ??
              'Meet performance standards';
          final achieved =
              item['achievedDescription']?.toString() ??
              item['actual']?.toString() ??
              'In Progress';
          final selfRating = item['selfRating']?.toString() ?? '4.5';
          final managerRating =
              item['managerRating']?.toString() ??
              item['tlRating']?.toString() ??
              '4.5';
          final status = item['status']?.toString() ?? 'Active';

          parsed.add({
            'title': title,
            'weightage': weightage,
            'target': target,
            'achieved': achieved,
            'selfRating': selfRating,
            'managerRating': managerRating,
            'status': status,
          });
        }
      }

      setState(() {
        _dashboard = rawDashboard is Map
            ? Map<String, dynamic>.from(rawDashboard)
            : {};
        _kpis = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  void _openSelfAssessmentModal() {
    final selfRatingController = TextEditingController(text: '4.8');
    final commentsController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ValueListenableBuilder<bool>(
              valueListenable: AppColors.isDarkMode,
              builder: (context, dark, _) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.graphite : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.muted(dark)
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Submit Self-Assessment Notes',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: selfRatingController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Overall Self Rating (1.0 to 5.0)',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: commentsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText:
                                  'Achievements & Performance Comments *',
                              hintText: 'Summarize key contributions during this review cycle...',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      if (commentsController.text
                                          .trim()
                                          .isEmpty)
                                        return;
                                      setModalState(() => submitting = true);

                                      final double rating =
                                          double.tryParse(
                                            selfRatingController.text.trim(),
                                          ) ??
                                          4.5;
                                      final payload = {
                                        'selfRating': rating,
                                        'comments': commentsController.text
                                            .trim(),
                                        'cycleName': _selectedCycle,
                                      };

                                      try {
                                        await _api.submitSelfReview(payload);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Self-assessment submitted successfully',
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFF2E7D32,
                                                  ),
                                                ),
                                              );
                                          _loadPerformance();
                                        }
                                      } catch (e) {
                                        setModalState(() => submitting = false);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed: $e'),
                                                ),
                                              );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.copper,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Submit Assessment',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final overallScore =
        _dashboard['overallScore']?.toString() ??
        _dashboard['rating']?.toString() ??
        '4.7';

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadPerformance,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeader(dark),
                      ElevatedButton.icon(
                        onPressed: _openSelfAssessmentModal,
                        icon: const Icon(
                          Icons.rate_review_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Self-Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.copper,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildCycleSelector(dark),
                  const SizedBox(height: 16),
                  _buildOverallScoreCard(dark, overallScore),
                  const SizedBox(height: 20),
                  Text(
                    'Assigned KPIs & Deliverable Goals',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_loading && _kpis.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No KPI goals recorded for this cycle',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _kpis.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final kpi = _kpis[index];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: AppColors.cardDecoration(dark),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      kpi['title'],
                                      style: TextStyle(
                                        color: AppColors.text(dark),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.copper.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Weight: ${kpi['weightage']}',
                                      style: const TextStyle(
                                        color: AppColors.copper,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Target: ${kpi['target']}',
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Achieved: ${kpi['achieved']}',
                                style: TextStyle(
                                  color: AppColors.accentText(dark),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Self Rating: ${kpi['selfRating']} / 5.0',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  Text(
                                    'Manager Rating: ${kpi['managerRating']} / 5.0',
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Performance',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Performance review ratings, KPI tracking, and appraisals',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildCycleSelector(bool dark) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCycle,
      decoration: InputDecoration(
        labelText: 'Review Cycle',
        filled: true,
        fillColor: AppColors.fieldFill(dark),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _cycles
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedCycle = val);
      },
    );
  }

  Widget _buildOverallScoreCard(bool dark, String score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B211B), Color(0xFF1E1713)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PERFORMANCE RATING',
                style: TextStyle(
                  color: AppColors.copper,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$score / 5.0',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Exceeds Expectations',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.copper.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppColors.copper,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
