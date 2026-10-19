import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/it_tickets_api_service.dart';

class ItTicketsPage extends StatefulWidget {
  const ItTicketsPage({super.key});

  @override
  State<ItTicketsPage> createState() => _ItTicketsPageState();
}

class _ItTicketsPageState extends State<ItTicketsPage> {
  final ItTicketsApiService _api = ItTicketsApiService();

  String _activeStatus = 'All';
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getMyTickets();
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id =
              item['id']?.toString() ??
              item['ticketNumber']?.toString() ??
              'TICK-001';
          final subject =
              item['subject']?.toString() ??
              item['title']?.toString() ??
              'Support Request';
          final category =
              item['categoryName']?.toString() ??
              item['category']?.toString() ??
              'IT Support';
          final priority =
              item['priority']?.toString().toUpperCase() ?? 'MEDIUM';
          final status = item['status']?.toString() ?? 'Open';
          final createdDate =
              item['createdAt']?.toString() ??
              item['createdDate']?.toString() ??
              '';
          final description =
              item['description']?.toString() ??
              item['details']?.toString() ??
              '';

          final rawComments = item['comments'] ?? item['messages'];
          final List<Map<String, dynamic>> messages = rawComments is List
              ? rawComments.whereType<Map>().map((c) {
                  return <String, dynamic>{
                    'sender':
                        c['createdByName']?.toString() ??
                        c['sender']?.toString() ??
                        'Support',
                    'text':
                        c['comment']?.toString() ??
                        c['message']?.toString() ??
                        c['text']?.toString() ??
                        '',
                    'time':
                        c['createdAt']
                            ?.toString()
                            .split('T')
                            .last
                            .substring(0, 5) ??
                        'Recently',
                  };
                }).toList()
              : [
                  {
                    'sender': 'Employee',
                    'text': description,
                    'time': 'Created',
                  },
                ];

          parsed.add({
            'id': id,
            'subject': subject,
            'category': category,
            'priority': priority,
            'status': status,
            'createdDate': createdDate.contains('T')
                ? createdDate.split('T')[0]
                : createdDate,
            'description': description,
            'messages': messages,
          });
        }
      }

      setState(() {
        _tickets = parsed;
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

  void _openCreateTicketModal() {
    final subjectController = TextEditingController();
    final descController = TextEditingController();
    String category = 'Hardware';
    String priority = 'Medium';
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
                            'Raise IT Support Ticket',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: category,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    filled: true,
                                    fillColor: AppColors.fieldFill(dark),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Hardware',
                                      child: Text('Hardware'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Software',
                                      child: Text('Software'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Network',
                                      child: Text('Network / VPN'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Access',
                                      child: Text('Access & Auth'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null)
                                      setModalState(() => category = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: priority,
                                  decoration: InputDecoration(
                                    labelText: 'Priority',
                                    filled: true,
                                    fillColor: AppColors.fieldFill(dark),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Low',
                                      child: Text('Low'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Medium',
                                      child: Text('Medium'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'High',
                                      child: Text('High'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Urgent',
                                      child: Text('Urgent'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null)
                                      setModalState(() => priority = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: subjectController,
                            decoration: InputDecoration(
                              labelText: 'Issue Subject / Title *',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: descController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description & Details *',
                              hintText:
                                  'Describe the issue or error message...',
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
                            child: ElevatedButton(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      if (subjectController.text.trim().isEmpty)
                                        return;
                                      setModalState(() => submitting = true);

                                      final payload = {
                                        'subject': subjectController.text.trim(),
                                        'title': subjectController.text.trim(),
                                        'categoryName': category,
                                        'category': category,
                                        'priority': priority.toUpperCase(),
                                        'description': descController.text.trim(),
                                        'details': descController.text.trim(),
                                      };

                                      try {
                                        await _api.createTicket(payload);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'IT Ticket created successfully',
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFF2E7D32,
                                                  ),
                                                ),
                                              );
                                          _loadTickets();
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
                                      'Submit IT Ticket',
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

  void _showTicketChat(Map<String, dynamic> ticket) {
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List messages = ticket['messages'] as List;

            return ValueListenableBuilder<bool>(
              valueListenable: AppColors.isDarkMode,
              builder: (context, dark, _) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ticket['subject'],
                                    style: TextStyle(
                                      color: AppColors.text(dark),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${ticket['id']} • ${ticket['category']}',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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
                        const Divider(height: 20),

                        Expanded(
                          child: ListView.separated(
                            itemCount: messages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final msg = messages[idx] as Map;
                              final isEmployee =
                                  msg['sender']
                                      .toString()
                                      .toLowerCase()
                                      .contains('employee') ||
                                  msg['sender']
                                      .toString()
                                      .toLowerCase()
                                      .contains('me');

                              return Align(
                                alignment: isEmployee
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isEmployee
                                        ? AppColors.copper.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.fieldFill(dark),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isEmployee
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['sender'].toString(),
                                        style: TextStyle(
                                          color: isEmployee
                                              ? AppColors.copper
                                              : AppColors.accentText(dark),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg['text'].toString(),
                                        style: TextStyle(
                                          color: AppColors.text(dark),
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg['time'].toString(),
                                        style: TextStyle(
                                          color: AppColors.muted(dark),
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                decoration: InputDecoration(
                                  hintText: 'Add response or comment...',
                                  filled: true,
                                  fillColor: AppColors.fieldFill(dark),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                final txt = messageController.text.trim();
                                if (txt.isEmpty) return;

                                try {
                                  await _api.addComment(
                                    ticket['id'].toString(),
                                    txt,
                                  );
                                  setModalState(() {
                                    messages.add({
                                      'sender': 'Employee',
                                      'text': txt,
                                      'time': 'Just now',
                                    });
                                    messageController.clear();
                                  });
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to add comment: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.send_rounded,
                                color: AppColors.copper,
                              ),
                            ),
                          ],
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
    final filtered = _tickets.where((t) {
      if (_activeStatus == 'All') return true;
      return t['status'].toString().toLowerCase() ==
          _activeStatus.toLowerCase();
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadTickets,
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
                        onPressed: _openCreateTicketModal,
                        icon: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'New Ticket',
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
                  _buildFilters(dark),
                  const SizedBox(height: 16),
                  if (!_loading && filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No IT support tickets found',
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
                        final t = filtered[index];

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
                                  Text(
                                    t['id'],
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t['status'] == 'Resolved'
                                          ? const Color(0xFF2E7D32)
                                                .withValues(alpha: 0.15)
                                          : const Color(0xFFED6C02)
                                                .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      t['status'],
                                      style: TextStyle(
                                        color: t['status'] == 'Resolved'
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFED6C02),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t['subject'],
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: ${t['category']} • Priority: ${t['priority']}',
                                style: TextStyle(
                                  color: AppColors.accentText(dark),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                t['description'],
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
                                    'Created: ${t['createdDate']}',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showTicketChat(t),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16,
                                      color: AppColors.copper,
                                    ),
                                    label: const Text(
                                      'Discussion',
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
          'IT Support Tickets',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Request help for hardware, software, or network issues',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFilters(bool dark) {
    return Row(
      children: ['All', 'Open', 'In Progress', 'Resolved'].map((st) {
        final selected = _activeStatus == st;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(st),
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
            onSelected: (_) => setState(() => _activeStatus = st),
          ),
        );
      }).toList(),
    );
  }
}
