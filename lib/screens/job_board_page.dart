import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/jobs_api_service.dart';

class JobBoardPage extends StatefulWidget {
  const JobBoardPage({super.key});

  @override
  State<JobBoardPage> createState() => _JobBoardPageState();
}

class _JobBoardPageState extends State<JobBoardPage> {
  final JobsApiService _api = JobsApiService();
  final _searchController = TextEditingController();

  String _selectedDept = 'All';
  String _searchQuery = '';
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getJobs();
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id =
              item['id']?.toString() ??
              item['jobCode']?.toString() ??
              'JOB-101';
          final title =
              item['title']?.toString() ??
              item['jobTitle']?.toString() ??
              'Position Opening';
          final department =
              item['departmentName']?.toString() ??
              item['department']?.toString() ??
              'Engineering';
          final location = item['location']?.toString() ?? 'Remote / Hybrid';
          final type =
              item['jobType']?.toString() ??
              item['type']?.toString() ??
              'Full-Time';
          final posted =
              item['postedDate']?.toString() ??
              item['createdAt']?.toString() ??
              'Recently';
          final experience =
              item['experienceLevel']?.toString() ??
              item['experience']?.toString() ??
              '2+ Years';
          final description =
              item['description']?.toString() ??
              item['summary']?.toString() ??
              'No position details provided.';

          final rawReqs = item['requirements'] ?? item['qualifications'];
          final List<String> reqs = rawReqs is List
              ? rawReqs.map((e) => e.toString()).toList()
              : (rawReqs is String
                    ? rawReqs.split(',')
                    : ['Relevant technical experience required']);

          parsed.add({
            'id': id,
            'title': title,
            'department': department,
            'location': location,
            'type': type,
            'posted': posted.contains('T') ? posted.split('T')[0] : posted,
            'experience': experience,
            'description': description,
            'requirements': reqs,
          });
        }
      }

      setState(() {
        _jobs = parsed;
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

  void _showJobDetails(Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppColors.isDarkMode,
          builder: (context, dark, _) {
            final reqs = (job['requirements'] as List<String>?) ?? [];
            final coverController = TextEditingController();
            bool submitting = false;

            return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.graphite : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                job['title'],
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: AppColors.muted(dark),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${job['department']} • ${job['location']} • ${job['type']}',
                          style: TextStyle(
                            color: AppColors.copper,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Divider(height: 20),

                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Job Overview:',
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  job['description'],
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Key Requirements:',
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Column(
                                  children: reqs.map((req) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(
                                              color: AppColors.copper,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              req,
                                              style: TextStyle(
                                                color: AppColors.muted(dark),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: coverController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Internal Transfer Note / Cover Note',
                                    hintText: 'Why are you interested in this position...',
                                    filled: true,
                                    fillColor: AppColors.fieldFill(dark),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: submitting
                                ? null
                                : () async {
                                    setModalState(() => submitting = true);

                                    final payload = {
                                      'coverNote': coverController.text.trim(),
                                    };

                                    try {
                                      await _api.applyForJob(
                                        job['id'].toString(),
                                        payload,
                                      );
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Internal job application submitted successfully',
                                            ),
                                            backgroundColor: Color(0xFF2E7D32),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() => submitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to submit application: $e',
                                            ),
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
                                    'Apply for Internal Role',
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
    final filtered = _jobs.where((job) {
      final matchesDept =
          _selectedDept == 'All' || job['department'] == _selectedDept;
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          job['title'].toString().toLowerCase().contains(query) ||
          job['department'].toString().toLowerCase().contains(query) ||
          job['description'].toString().toLowerCase().contains(query);
      return matchesDept && matchesQuery;
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadJobs,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(dark),
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
                  _buildSearchAndFilter(dark),
                  const SizedBox(height: 16),
                  if (!_loading && filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No job openings found',
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
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final job = filtered[index];

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
                                      job['title'],
                                      style: TextStyle(
                                        color: AppColors.text(dark),
                                        fontSize: 16,
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
                                      job['type'],
                                      style: const TextStyle(
                                        color: AppColors.copper,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${job['department']} • ${job['location']} • ${job['experience']}',
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                job['description'],
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Posted: ${job['posted']}',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11,
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _showJobDetails(job),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.copper,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'View & Apply',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
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
          'Internal Job Board',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Explore internal career growth and open positions across departments',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter(bool dark) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search job title or keywords...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: AppColors.fieldFill(dark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.fieldBorder(dark)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Engineering', 'Design', 'Product', 'HR'].map((
              dept,
            ) {
              final selected = _selectedDept == dept;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(dept),
                  selected: selected,
                  selectedColor: AppColors.copper,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.text(dark),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  backgroundColor: AppColors.fieldFill(dark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (_) => setState(() => _selectedDept = dept),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
