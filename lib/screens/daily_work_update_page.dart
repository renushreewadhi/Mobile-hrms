import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/work_updates_api_service.dart';
import '../services/projects_api_service.dart';

class DailyWorkUpdatePage extends StatefulWidget {
  const DailyWorkUpdatePage({super.key});

  @override
  State<DailyWorkUpdatePage> createState() => _DailyWorkUpdatePageState();
}

class _DailyWorkUpdatePageState extends State<DailyWorkUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final WorkUpdatesApiService _workUpdatesApi = WorkUpdatesApiService();
  final ProjectsApiService _projectsApi = ProjectsApiService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedProjectId;
  String _selectedProjectName = 'General Project';
  double _hoursWorked = 8.0;
  final _tasksController = TextEditingController();
  final _summaryController = TextEditingController();
  final _blockersController = TextEditingController();

  List<Map<String, dynamic>> _projectsList = [];
  List<Map<String, dynamic>> _updatesList = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tasksController.dispose();
    _summaryController.dispose();
    _blockersController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _workUpdatesApi.getMine(),
        _projectsApi.getMyProjects(),
      ]);

      if (!mounted) return;

      final rawUpdates = results[0];
      final rawProjects = results[1];

      final updates = <Map<String, dynamic>>[];
      for (final item in rawUpdates) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final dateStr =
              item['date']?.toString() ?? item['updateDate']?.toString() ?? '';
          final project =
              item['projectName']?.toString() ??
              item['project']?.toString() ??
              'Project';
          final hours = item['hoursWorked'] != null
              ? '${item['hoursWorked']} hrs'
              : '8.0 hrs';
          final tasks =
              item['tasksCompleted']?.toString() ??
              item['tasks']?.toString() ??
              '';
          final summary =
              item['summary']?.toString() ??
              item['description']?.toString() ??
              '';
          final blockers = item['blockers']?.toString() ?? 'None';
          final status = item['status']?.toString() ?? 'Submitted';

          updates.add({
            'id': id,
            'date': dateStr.contains('T') ? dateStr.split('T')[0] : dateStr,
            'project': project,
            'hours': hours,
            'tasks': tasks,
            'summary': summary,
            'blockers': blockers.isEmpty ? 'None' : blockers,
            'status': status,
          });
        }
      }

      final projects = <Map<String, dynamic>>[];
      for (final p in rawProjects) {
        if (p is Map) {
          final pId = p['id']?.toString() ?? '';
          final pName =
              p['name']?.toString() ?? p['title']?.toString() ?? 'Project';
          projects.add({'id': pId, 'name': pName});
        }
      }

      setState(() {
        _updatesList = updates;
        _projectsList = projects;
        if (projects.isNotEmpty) {
          _selectedProjectId = projects.first['id'];
          _selectedProjectName = projects.first['name'];
        }
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

  Future<void> _submitEOD() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      'date': dateStr,
      'projectId': _selectedProjectId,
      'projectName': _selectedProjectName,
      'hoursWorked': _hoursWorked,
      'tasksCompleted': _tasksController.text.trim(),
      'summary': _summaryController.text.trim(),
      'blockers': _blockersController.text.trim(),
    };

    try {
      await _workUpdatesApi.submit(payload);

      if (!mounted) return;

      setState(() {
        _tasksController.clear();
        _summaryController.clear();
        _blockersController.clear();
        _hoursWorked = 8.0;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EOD Work Update submitted successfully'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );

      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Failed to submit work update')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadData,
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
                  _buildEodForm(dark),
                  const SizedBox(height: 24),
                  _buildHistoryHeader(dark),
                  const SizedBox(height: 12),
                  _buildHistoryList(dark),
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
          'Daily Work Update (EOD)',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Submit your daily progress summary to team lead and manager',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEodForm(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(dark),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit Today\'s Report',
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill(dark),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.fieldBorder(dark)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppColors.accentText(dark),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: AppColors.text(dark),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Project',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.fieldFill(dark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.fieldBorder(dark),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    items: _projectsList.isNotEmpty
                        ? _projectsList.map((p) {
                            return DropdownMenuItem<String>(
                              value: p['id'].toString(),
                              child: Text(
                                p['name'].toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList()
                        : const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('General Project'),
                            ),
                          ],
                    onChanged: (val) {
                      setState(() {
                        _selectedProjectId = val;
                        final found = _projectsList.firstWhere(
                          (p) => p['id'] == val,
                          orElse: () => {'name': 'General Project'},
                        );
                        _selectedProjectName = found['name'].toString();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Hours Worked: ${_hoursWorked.toStringAsFixed(1)} hrs',
                  style: TextStyle(
                    color: AppColors.text(dark),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _hoursWorked,
              min: 1.0,
              max: 12.0,
              divisions: 22,
              activeColor: AppColors.copper,
              label: '${_hoursWorked.toStringAsFixed(1)} hrs',
              onChanged: (val) => setState(() => _hoursWorked = val),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tasksController,
              decoration: InputDecoration(
                labelText: 'Tasks Completed Today *',
                hintText: 'List key modules, features, or tickets closed...',
                filled: true,
                fillColor: AppColors.fieldFill(dark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please list completed tasks'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Work Summary & Notes',
                hintText: 'Describe details of implementation...',
                filled: true,
                fillColor: AppColors.fieldFill(dark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _blockersController,
              decoration: InputDecoration(
                labelText: 'Blockers / Issues (If Any)',
                hintText: 'Any pending approvals, API gaps, or dependencies...',
                filled: true,
                fillColor: AppColors.fieldFill(dark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitEOD,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                label: const Text(
                  'Submit Daily Work Update',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.copper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Submitted EOD Updates',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${_updatesList.length} History Items',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHistoryList(bool dark) {
    if (_updatesList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: AppColors.cardDecoration(dark),
        child: Center(
          child: Text(
            'No work updates submitted yet',
            style: TextStyle(color: AppColors.muted(dark)),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _updatesList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final update = _updatesList[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.cardDecoration(dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    update['date'],
                    style: TextStyle(
                      color: AppColors.accentText(dark),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      update['status'],
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${update['project']} • ${update['hours']}',
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (update['tasks'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Tasks: ${update['tasks']}',
                  style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
                ),
              ],
              if (update['summary'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Summary: ${update['summary']}',
                  style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
                ),
              ],
              if (update['blockers'].toString().isNotEmpty &&
                  update['blockers'] != 'None') ...[
                const SizedBox(height: 4),
                Text(
                  'Blockers: ${update['blockers']}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
