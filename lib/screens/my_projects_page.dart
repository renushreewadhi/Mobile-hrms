import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/projects_api_service.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key});

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  final ProjectsApiService _projectsApi = ProjectsApiService();

  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _projectsApi.getMyProjects();
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final title =
              item['title']?.toString() ??
              item['name']?.toString() ??
              item['projectName']?.toString() ??
              'Project';
          final client =
              item['clientName']?.toString() ??
              item['client']?.toString() ??
              'Enterprise Client';
          final role =
              item['myRole']?.toString() ??
              item['role']?.toString() ??
              'Team Member';
          final status = item['status']?.toString() ?? 'Active';
          final description =
              item['description']?.toString() ?? 'No description provided.';
          final progress = item['progress'] != null
              ? (double.tryParse(item['progress'].toString()) ?? 0.5)
              : 0.5;
          final startDate = item['startDate']?.toString() ?? '';
          final endDate = item['endDate']?.toString() ?? '';
          final teamCount = item['teamSize'] ?? item['teamCount'] ?? 1;

          final rawTech = item['techStack'] ?? item['technologies'];
          final List<String> techStack = rawTech is List
              ? rawTech.map((e) => e.toString()).toList()
              : (rawTech is String
                    ? rawTech.split(',')
                    : ['Flutter', 'ASP.NET Core']);

          parsed.add({
            'id': id,
            'title': title,
            'client': client,
            'role': role,
            'progress': progress > 1.0 ? progress / 100.0 : progress,
            'status': status,
            'startDate': startDate.contains('T')
                ? startDate.split('T')[0]
                : startDate,
            'endDate': endDate.contains('T') ? endDate.split('T')[0] : endDate,
            'teamCount': teamCount,
            'description': description,
            'techStack': techStack,
          });
        }
      }

      setState(() {
        _projects = parsed;
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

  void _showProjectDetails(Map<String, dynamic> prj) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppColors.isDarkMode,
          builder: (context, dark, _) {
            final techStack = (prj['techStack'] as List<String>?) ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
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
                        color: AppColors.muted(dark).withValues(alpha: 0.3),
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
                          prj['title'],
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AppColors.muted(dark)),
                      ),
                    ],
                  ),
                  Text(
                    'Role: ${prj['role']}',
                    style: const TextStyle(
                      color: AppColors.copper,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Divider(height: 20),
                  Text(
                    'Project Overview:',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prj['description'],
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Technologies Used:',
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: techStack.map((tech) {
                      return Chip(
                        label: Text(tech, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.copper.withValues(
                          alpha: 0.12,
                        ),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Client: ${prj['client']}',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Team: ${prj['teamCount']} Members',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadProjects,
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
                  if (!_loading && _projects.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No project assignments found',
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
                      itemCount: _projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final prj = _projects[index];
                        final double progress = (prj['progress'] as num)
                            .toDouble();

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
                                      prj['title'],
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
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: prj['status'] == 'Active'
                                          ? const Color(0xFF2E7D32)
                                                .withValues(alpha: 0.15)
                                          : AppColors.fieldFill(dark),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      prj['status'],
                                      style: TextStyle(
                                        color: prj['status'] == 'Active'
                                            ? const Color(0xFF2E7D32)
                                            : AppColors.muted(dark),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Role: ${prj['role']} • Client: ${prj['client']}',
                                style: TextStyle(
                                  color: AppColors.copper,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                prj['description'],
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: AppColors.fieldFill(
                                          dark,
                                        ),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              AppColors.copper,
                                            ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      color: AppColors.text(dark),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Team: ${prj['teamCount']} members',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _showProjectDetails(prj),
                                    child: const Text(
                                      'View Project Info',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.copper,
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
          'My Projects',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Client projects and internal initiatives you are assigned to',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }
}
