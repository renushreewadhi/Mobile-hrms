import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/tasks_api_service.dart';

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  final TasksApiService _tasksApi = TasksApiService();
  final _searchController = TextEditingController();

  String _selectedStatus = 'All';
  String _searchQuery = '';
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _tasksApi.getMyTasks();
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final title =
              item['title']?.toString() ??
              item['taskName']?.toString() ??
              item['name']?.toString() ??
              'Task';
          final project =
              item['projectName']?.toString() ??
              item['project']?.toString() ??
              'General Project';
          final priority =
              item['priority']?.toString().toUpperCase() ?? 'MEDIUM';
          final status = _formatStatus(
            item['status']?.toString() ??
                item['taskStatus']?.toString() ??
                'To Do',
          );
          final dueDate =
              item['dueDate']?.toString() ??
              item['deadline']?.toString() ??
              'No due date';
          final description =
              item['description']?.toString() ??
              item['details']?.toString() ??
              'No details provided.';
          final progress = item['progress'] != null
              ? (double.tryParse(item['progress'].toString()) ?? 0.0)
              : (status == 'Completed'
                    ? 1.0
                    : status == 'In Progress'
                    ? 0.5
                    : 0.0);

          parsed.add({
            'id': id,
            'title': title,
            'project': project,
            'priority': priority,
            'status': status,
            'dueDate': dueDate.contains('T') ? dueDate.split('T')[0] : dueDate,
            'description': description,
            'progress': progress,
          });
        }
      }

      setState(() {
        _tasks = parsed;
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

  String _formatStatus(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('complete') || s == 'done' || s == 'closed') {
      return 'Completed';
    }
    if (s.contains('progress') || s == 'doing' || s == 'working') {
      return 'In Progress';
    }
    if (s.contains('review')) {
      return 'Review';
    }
    return 'To Do';
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await _tasksApi.updateTaskStatus(taskId, newStatus);
      if (!mounted) return;

      setState(() {
        final idx = _tasks.indexWhere((t) => t['id'] == taskId);
        if (idx != -1) {
          _tasks[idx]['status'] = newStatus;
          _tasks[idx]['progress'] = newStatus == 'Completed'
              ? 1.0
              : (newStatus == 'In Progress' ? 0.5 : 0.0);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task status updated to $newStatus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppColors.isDarkMode,
          builder: (context, dark, _) {
            String currentTaskStatus = task['status'];
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: dark ? AppColors.graphite : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        task['id'],
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 13,
                        ),
                      ),
                      _priorityBadge(task['priority']),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Project: ${task['project']} • Due: ${task['dueDate']}',
                        style: TextStyle(
                          color: AppColors.accentText(dark),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        task['description'],
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Update Status:',
                        style: TextStyle(
                          color: AppColors.text(dark),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: currentTaskStatus,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.fieldFill(dark),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'To Do',
                            child: Text('To Do'),
                          ),
                          DropdownMenuItem(
                            value: 'In Progress',
                            child: Text('In Progress'),
                          ),
                          DropdownMenuItem(
                            value: 'Review',
                            child: Text('Under Review'),
                          ),
                          DropdownMenuItem(
                            value: 'Completed',
                            child: Text('Completed'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => currentTaskStatus = val);
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (currentTaskStatus != task['status'] &&
                            task['id'].toString().isNotEmpty) {
                          _updateTaskStatus(
                            task['id'].toString(),
                            currentTaskStatus,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.copper,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _priorityBadge(String priority) {
    Color color;
    final p = priority.toUpperCase();
    if (p.contains('HIGH') || p.contains('URGENT')) {
      color = Colors.redAccent;
    } else if (p.contains('MED')) {
      color = Colors.orangeAccent;
    } else {
      color = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tasks.where((t) {
      final matchesStatus =
          _selectedStatus == 'All' || t['status'] == _selectedStatus;
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          t['title'].toString().toLowerCase().contains(query) ||
          t['project'].toString().toLowerCase().contains(query) ||
          t['description'].toString().toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadTasks,
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
                        'No tasks assigned or found matching filters',
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
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final task = filtered[index];
                        final double progress = (task['progress'] as num)
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
                                      task['title'],
                                      style: TextStyle(
                                        color: AppColors.text(dark),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _priorityBadge(task['priority']),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${task['project']} • Due: ${task['dueDate']}',
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                ),
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
                                            AlwaysStoppedAnimation<Color>(
                                              progress == 1.0
                                                  ? const Color(0xFF2E7D32)
                                                  : AppColors.copper,
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.fieldFill(dark),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      task['status'],
                                      style: TextStyle(
                                        color: AppColors.accentText(dark),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _showTaskDetail(task),
                                    child: const Text(
                                      'View Details',
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
          'My Tasks',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track and update your assigned work deliverables',
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
            hintText: 'Search tasks or projects...',
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
            children: ['All', 'To Do', 'In Progress', 'Completed'].map((
              status,
            ) {
              final selected = _selectedStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status),
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
                  onSelected: (_) => setState(() => _selectedStatus = status),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
