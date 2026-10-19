import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/expenses_api_service.dart';

class MyExpensesPage extends StatefulWidget {
  const MyExpensesPage({super.key});

  @override
  State<MyExpensesPage> createState() => _MyExpensesPageState();
}

class _MyExpensesPageState extends State<MyExpensesPage> {
  final ExpensesApiService _api = ExpensesApiService();
  final _formKey = GlobalKey<FormState>();

  String _activeFilter = 'All';
  String _selectedCategory = 'Travel';
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _expenses = [];
  List<String> _categories = [
    'Travel',
    'Meals',
    'Office Supplies',
    'Medical',
    'Client Entertainment',
    'Other',
  ];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getMyExpenses(),
        _api.getCategories(),
      ]);

      if (!mounted) return;

      final rawList = results[0];
      final rawCat = results[1];

      if (rawCat.isNotEmpty) {
        final catList = rawCat
            .map(
              (c) => c is Map
                  ? (c['name']?.toString() ??
                        c['categoryName']?.toString() ??
                        '')
                  : c.toString(),
            )
            .where((s) => s.isNotEmpty)
            .toList();
        if (catList.isNotEmpty) {
          _categories = catList;
          _selectedCategory = catList.first;
        }
      }

      final parsed = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is Map) {
          final id =
              item['id']?.toString() ?? item['claimNumber']?.toString() ?? '';
          final title =
              item['title']?.toString() ??
              item['expenseName']?.toString() ??
              item['category']?.toString() ??
              'Expense Claim';
          final category =
              item['categoryName']?.toString() ??
              item['category']?.toString() ??
              'General';
          final amt = item['amount'] ?? item['claimAmount'] ?? 0;
          final amountStr = amt is num
              ? '₹${amt.toStringAsFixed(2)}'
              : '₹$amt';
          final dateStr =
              item['expenseDate']?.toString() ??
              item['createdAt']?.toString() ??
              item['date']?.toString() ??
              '';
          final status = _parseExpenseStatus(item);
          final description =
              item['description']?.toString() ??
              item['notes']?.toString() ??
              '';

          parsed.add({
            'id': id,
            'title': title,
            'category': category,
            'amount': amountStr,
            'date': dateStr.contains('T') ? dateStr.split('T')[0] : dateStr,
            'status': status,
            'description': description,
          });
        }
      }

      setState(() {
        _expenses = parsed;
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

  void _openAddExpenseModal() {
    _titleController.clear();
    _amountController.clear();
    _descController.clear();
    _selectedDate = DateTime.now();
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
                      child: Form(
                        key: _formKey,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Submit Expense Claim',
                                  style: TextStyle(
                                    color: AppColors.text(dark),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Claim Title / Purpose *',
                                filled: true,
                                fillColor: AppColors.fieldFill(dark),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Please enter a title'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedCategory,
                                    decoration: InputDecoration(
                                      labelText: 'Category',
                                      filled: true,
                                      fillColor: AppColors.fieldFill(dark),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: _categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null)
                                        setModalState(
                                          () => _selectedCategory = val,
                                        );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Amount (₹) *',
                                      filled: true,
                                      fillColor: AppColors.fieldFill(dark),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                        ? 'Enter amount'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _descController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Business Justification',
                                hintText:
                                    'Detailed description of the expense...',
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
                                        if (!_formKey.currentState!.validate())
                                          return;
                                        setModalState(() => submitting = true);

                                        final double amt =
                                            double.tryParse(
                                              _amountController.text.trim(),
                                            ) ??
                                            0;
                                        final dateStr =
                                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

                                        final payload = {
                                          'title': _titleController.text.trim(),
                                          'categoryName': _selectedCategory,
                                          'category': _selectedCategory,
                                          'amount': amt,
                                          'expenseDate': dateStr,
                                          'description': _descController.text
                                              .trim(),
                                        };

                                        try {
                                          await _api.submitExpense(payload);
                                          if (mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Expense claim submitted successfully',
                                                    ),
                                                    backgroundColor: Color(
                                                      0xFF2E7D32,
                                                    ),
                                                  ),
                                                );
                                            _loadExpenses();
                                          }
                                        } catch (e) {
                                          setModalState(
                                            () => submitting = false,
                                          );
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
                                        'Submit Claim',
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _parseExpenseStatus(Map<dynamic, dynamic> item) {
    if (item['isApproved'] == true || item['approved'] == true) {
      return 'Approved';
    }
    if (item['isRejected'] == true || item['rejected'] == true) {
      return 'Rejected';
    }

    final raw = item['status'] ??
        item['claimStatus'] ??
        item['approvalStatus'] ??
        item['reviewStatus'] ??
        item['stage'] ??
        item['state'];

    if (raw == null) return 'Pending';

    final str = raw.toString().trim();
    final upper = str.toUpperCase();

    if (upper.contains('APPR') ||
        upper.contains('REIMBURS') ||
        upper.contains('PAID') ||
        upper.contains('ACCEPT') ||
        upper == 'APPROVED') {
      return 'Approved';
    }
    if (upper.contains('REJ') ||
        upper.contains('DECLIN') ||
        upper.contains('REFUS') ||
        upper.contains('DENI') ||
        upper == 'REJECTED') {
      return 'Rejected';
    }
    if (upper.contains('SUBMIT') ||
        upper.contains('PEND') ||
        upper.contains('PROCESS') ||
        upper == 'SUBMITTED') {
      return 'Pending';
    }

    return str;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _expenses.where((e) {
      if (_activeFilter == 'All') return true;
      return e['status'].toString().toLowerCase() ==
          _activeFilter.toLowerCase();
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadExpenses,
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
                      Expanded(child: _buildHeader(dark)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _openAddExpenseModal,
                        icon: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'New Claim',
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
                        'No expense claims found',
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
                        final exp = filtered[index];
                        final status = exp['status'].toString();

                        Color statusColor;
                        final stLower = status.toLowerCase();
                        if (stLower.contains('appr') ||
                            stLower.contains('reimburs') ||
                            stLower.contains('paid') ||
                            stLower.contains('accept')) {
                          statusColor = const Color(0xFF2E7D32);
                        } else if (stLower.contains('rej') ||
                            stLower.contains('declin') ||
                            stLower.contains('refus') ||
                            stLower.contains('deni')) {
                          statusColor = const Color(0xFFD32F2F);
                        } else {
                          statusColor = const Color(0xFFED6C02);
                        }

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
                                    exp['title'],
                                    style: TextStyle(
                                      color: AppColors.text(dark),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    exp['amount'],
                                    style: TextStyle(
                                      color: AppColors.copper,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${exp['category']} • ${exp['date']}',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (exp['description'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  exp['description'],
                                  style: TextStyle(
                                    color: AppColors.muted(dark),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
          'My Expenses',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Submit and track business expense reimbursements',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFilters(bool dark) {
    final filters = ['All', 'Pending', 'Approved', 'Rejected', 'Processing', 'Draft'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((st) {
          final selected = _activeFilter == st;
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
              onSelected: (_) => setState(() => _activeFilter = st),
            ),
          );
        }).toList(),
      ),
    );
  }
}
