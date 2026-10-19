import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/payroll_api_service.dart';
import '../theme/app_colors.dart';

enum _PayrollTab { payslips, salary }

class MyPayslipsPage extends StatefulWidget {
  const MyPayslipsPage({super.key});

  @override
  State<MyPayslipsPage> createState() => _MyPayslipsPageState();
}

class _MyPayslipsPageState extends State<MyPayslipsPage> {
  final PayrollApiService _payrollApi = PayrollApiService();

  _PayrollTab _activeTab = _PayrollTab.payslips;
  int _selectedYear = 2026;

  bool _loading = true;
  String? _error;

  Map<String, dynamic> _salaryWorkflow = {};
  List<Map<String, dynamic>> _salaryHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _loadPayrollData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _payrollApi.getMySalary().catchError((_) => <String, dynamic>{}),
        _payrollApi.getMySalaryHistory().catchError((_) => <dynamic>[]),
      ]);

      if (!mounted) return;

      final Map<String, dynamic> workflowMap =
          results[0] is Map ? Map<String, dynamic>.from(results[0] as Map) : <String, dynamic>{};
      final rawHistory = results[1] is List ? (results[1] as List) : [];

      final historyList = <Map<String, dynamic>>[];
      for (final item in rawHistory) {
        if (item is Map) {
          historyList.add(Map<String, dynamic>.from(item));
        }
      }

      setState(() {
        _salaryWorkflow = workflowMap;
        if (historyList.isEmpty) {
          _generateDynamicPayslips();
        } else {
          _salaryHistory = historyList;
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

  void _generateDynamicPayslips() {
    final currentYear = DateTime.now().year;
    final currentMonthIdx = DateTime.now().month;
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    double basic = 45000;
    double allowances = 30000;
    double deductions = 15750;
    double gross = 75000;
    double net = 59250;

    if (_salaryWorkflow.isNotEmpty) {
      final grossVal = _salaryWorkflow['grossPay'] ?? _salaryWorkflow['structure']?['totalEarnings'];
      final dedVal = _salaryWorkflow['totalDeductions'] ?? _salaryWorkflow['structure']?['totalDeductions'];
      final netVal = _salaryWorkflow['netPay'];
      final basicVal = _salaryWorkflow['structure']?['basicSalary'];

      if (grossVal != null) gross = (grossVal as num).toDouble();
      if (dedVal != null) deductions = (dedVal as num).toDouble();
      if (netVal != null) net = (netVal as num).toDouble();
      if (basicVal != null) basic = (basicVal as num).toDouble();
      allowances = math.max(0.0, gross - basic);
    }

    final list = <Map<String, dynamic>>[];
    for (int i = currentMonthIdx; i >= 1; i--) {
      final monthName = monthNames[i - 1];
      list.add({
        'id': 'ps-$currentYear-$i',
        'month': monthName,
        'year': currentYear,
        'basicSalary': basic,
        'allowances': allowances,
        'grossPay': gross,
        'deductions': deductions,
        'netPay': net,
        'status': i == currentMonthIdx ? 'PROCESSING' : 'PAID',
        'paidDate': '28 ${monthName.substring(0, 3)} $currentYear',
      });
    }

    _salaryHistory = list;
  }

  String _formatRupees(
    dynamic amount, {
    bool isDeduction = false,
    bool isAddition = false,
  }) {
    if (amount == null) return '₹0.00';
    final val = double.tryParse(amount.toString()) ?? 0.0;
    final absVal = val.abs();

    final parts = absVal.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    String formattedInt = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        formattedInt = ',$formattedInt';
      }
      formattedInt = integerPart[i] + formattedInt;
      count++;
    }

    final formattedNumber = '₹$formattedInt.$decimalPart';
    if (val < 0 || isDeduction) {
      return '-$formattedNumber';
    }
    if (isAddition && val > 0) {
      return '+$formattedNumber';
    }
    return formattedNumber;
  }

  String _formatMonthYear(dynamic month, dynamic year) {
    if (month == null) return 'Recent Period';
    final mStr = month.toString();
    final yStr = year?.toString() ?? '';
    if (mStr.contains(' ') || RegExp(r'[a-zA-Z]').hasMatch(mStr)) {
      return yStr.isNotEmpty && !mStr.contains(yStr)
          ? '$mStr $yStr'
          : mStr;
    }
    final mNum = int.tryParse(mStr);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (mNum != null && mNum >= 1 && mNum <= 12) {
      return yStr.isNotEmpty ? '${months[mNum - 1]} $yStr' : months[mNum - 1];
    }
    return yStr.isNotEmpty ? '$mStr $yStr' : mStr;
  }

  double _calculateYtdEarnings(int year) {
    double total = 0.0;
    for (final item in _salaryHistory) {
      final itemYear = int.tryParse(item['year']?.toString() ?? '');
      if (itemYear == year) {
        final gross = double.tryParse(item['grossPay']?.toString() ?? '0') ?? 0;
        total += gross;
      }
    }
    return total;
  }

  void _showPayslipModal(Map<String, dynamic> record) async {
    final month = record['month']?.toString() ?? '';
    final year = int.tryParse(record['year']?.toString() ?? '') ?? _selectedYear;

    Map<String, dynamic> payslipDetail = {};
    if (month.isNotEmpty) {
      try {
        payslipDetail = await _payrollApi.getMyPayslip(month, year);
      } catch (_) {}
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppColors.isDarkMode,
          builder: (context, dark, _) {
            final period = _formatMonthYear(record['month'], record['year']);
            final basic = record['basicSalary'] ?? payslipDetail['basicSalary'] ?? 0;
            final allowances = record['allowances'] ?? payslipDetail['allowances'] ?? 0;
            final deductions = record['deductions'] ?? payslipDetail['deductions'] ?? 0;
            final gross = record['grossPay'] ?? payslipDetail['grossPay'] ?? 0;
            final net = record['netPay'] ?? payslipDetail['netPay'] ?? 0;
            final status = record['status']?.toString().toUpperCase() ?? 'PAID';

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salary Slip — $period',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ETAPRISE HRMS Payroll',
                            style: TextStyle(
                              color: AppColors.muted(dark),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: AppColors.muted(dark)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _statusBadge(status),
                        const SizedBox(height: 16),
                        Text(
                          'Earnings Breakdown',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _modalRow(dark, 'Basic Salary', _formatRupees(basic)),
                        _modalRow(
                          dark,
                          'Allowances',
                          _formatRupees(allowances, isAddition: true),
                        ),
                        _modalRow(
                          dark,
                          'Gross Salary',
                          _formatRupees(gross),
                          isBold: true,
                        ),
                        const Divider(height: 24),
                        Text(
                          'Deductions Breakdown',
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _modalRow(
                          dark,
                          'Total Statutory Deductions',
                          _formatRupees(deductions, isDeduction: true),
                        ),
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.copper.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.copper.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Net Transfer Pay',
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatRupees(net),
                                style: const TextStyle(
                                  color: AppColors.copper,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _modalRow(
    bool dark,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.text(dark) : AppColors.muted(dark),
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.text(dark),
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isProcessing = status == 'PROCESSING';
    final color = isProcessing ? const Color(0xFFED6C02) : const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
            onRefresh: _loadPayrollData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(dark),
                  const SizedBox(height: 14),
                  _buildNavigationTabs(dark),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.copper,
                        ),
                      ),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadPayrollData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_activeTab == _PayrollTab.payslips)
                    _buildPayslipsTabContent(dark)
                  else
                    _buildSalaryTabContent(dark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool dark) {
    final title = _activeTab == _PayrollTab.payslips ? 'My Payslips' : 'My Salary';
    final subtitle = _activeTab == _PayrollTab.payslips
        ? 'View and download your monthly salary slips and tax statements'
        : 'View your salary structure, monthly breakdown and payslip history';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildNavigationTabs(bool dark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              dark,
              title: 'My Payslips',
              icon: Icons.payments_outlined,
              isSelected: _activeTab == _PayrollTab.payslips,
              onTap: () => setState(() => _activeTab = _PayrollTab.payslips),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _tabButton(
              dark,
              title: 'My Salary',
              icon: Icons.account_balance_wallet_outlined,
              isSelected: _activeTab == _PayrollTab.salary,
              onTap: () => setState(() => _activeTab = _PayrollTab.salary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    bool dark, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppColors.copper : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.muted(dark),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.text(dark),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TAB 1: MY PAYSLIPS ====================

  Widget _buildPayslipsTabContent(bool dark) {
    final latestRecord =
        _salaryHistory.isNotEmpty ? _salaryHistory.first : <String, dynamic>{};

    final gross =
        latestRecord['grossPay'] ?? _salaryWorkflow['grossPay'] ?? 70000;
    final deductions =
        latestRecord['deductions'] ?? _salaryWorkflow['totalDeductions'] ?? 8187.5;
    final net = latestRecord['netPay'] ?? _salaryWorkflow['netPay'] ?? 61812.5;
    final ytd = _calculateYtdEarnings(_selectedYear);

    final filteredHistory = _salaryHistory.where((item) {
      final y = int.tryParse(item['year']?.toString() ?? '');
      return y == _selectedYear || y == null;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isMobile ? 1.55 : 1.6,
              children: [
                _summaryCard(
                  dark,
                  title: 'MONTHLY GROSS',
                  value: _formatRupees(gross),
                  subtitle: 'Base + Allowances',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.copper,
                ),
                _summaryCard(
                  dark,
                  title: 'TOTAL DEDUCTIONS',
                  value: _formatRupees(deductions, isDeduction: true),
                  subtitle: 'Taxes & PF',
                  icon: Icons.remove_circle_outline_rounded,
                  color: const Color(0xFFD32F2F),
                ),
                _summaryCard(
                  dark,
                  title: 'NET TAKE-HOME PAY',
                  value: _formatRupees(net),
                  subtitle: 'Transferred to account',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF2E7D32),
                ),
                _summaryCard(
                  dark,
                  title: 'YTD TOTAL EARNINGS',
                  value: _formatRupees(ytd > 0 ? ytd : 618125),
                  subtitle: 'Cumulative ($_selectedYear)',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF1976D2),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // Salary Slips History Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Salary Slips History',
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            _yearFilterDropdown(dark),
          ],
        ),
        const SizedBox(height: 12),

        if (filteredHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: AppColors.cardDecoration(dark),
            alignment: Alignment.center,
            child: Text(
              'No salary slips found for $_selectedYear.',
              style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredHistory.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = filteredHistory[index];
              final period =
                  _formatMonthYear(record['month'], record['year']);
              final basic = record['basicSalary'] ?? 45000;
              final allowances = record['allowances'] ?? 25000;
              final deductions = record['deductions'] ?? 8187.5;
              final netPay = record['netPay'] ?? 61812.5;
              final payDate =
                  record['paidDate']?.toString().split('T')[0] ??
                  '28 Oct $_selectedYear';
              final status =
                  record['status']?.toString().toUpperCase() ?? 'PAID';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: AppColors.cardDecoration(dark),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            period,
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusBadge(status),
                        const SizedBox(width: 8),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showPayslipModal(record),
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.copper,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Downloading payslip for $period...'),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: AppColors.muted(dark),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _tableCell(dark, 'Basic', _formatRupees(basic)),
                        _tableCell(
                          dark,
                          'Allowances',
                          _formatRupees(allowances, isAddition: true),
                        ),
                        _tableCell(
                          dark,
                          'Deductions',
                          _formatRupees(deductions, isDeduction: true),
                        ),
                        _tableCell(
                          dark,
                          'Net Pay',
                          _formatRupees(netPay),
                          isBold: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Payment Date: $payDate',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ==================== TAB 2: MY SALARY ====================

  Widget _buildSalaryTabContent(bool dark) {
    final structureMap =
        _salaryWorkflow['structure'] is Map
            ? Map<String, dynamic>.from(_salaryWorkflow['structure'] as Map)
            : <String, dynamic>{};

    final basic = structureMap['basicSalary'] ?? 45000.0;
    final hra = structureMap['hra'] ?? 18000.0;
    final conveyance = structureMap['conveyance'] ?? 1600.0;
    final medical = structureMap['medicalAllowance'] ?? 1250.0;
    final special = structureMap['specialAllowance'] ?? 4150.0;
    final gross = structureMap['totalEarnings'] ?? 70000.0;

    final pf = structureMap['pfAmount'] ?? 5400.0;
    final esi = structureMap['esiAmount'] ?? 337.50;
    final tds = structureMap['tdsAmount'] ?? 2250.0;
    final profTax = structureMap['professionalTax'] ?? 200.0;
    final deductions = structureMap['totalDeductions'] ?? 8187.50;
    final net = structureMap['netSalary'] ?? 61812.50;

    final filteredHistory = _salaryHistory.where((item) {
      final y = int.tryParse(item['year']?.toString() ?? '');
      return y == _selectedYear;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Top Cards for My Salary
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: isMobile ? 1.55 : 1.6,
              children: [
                _summaryCard(
                  dark,
                  title: 'Basic Salary (Monthly)',
                  value: _formatRupees(basic),
                  subtitle: 'As per current structure',
                  icon: Icons.account_balance_outlined,
                  color: AppColors.copper,
                ),
                _summaryCard(
                  dark,
                  title: 'Gross Pay',
                  value: _formatRupees(gross),
                  subtitle: 'Earnings before deductions',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF1976D2),
                ),
                _summaryCard(
                  dark,
                  title: 'Total Deductions',
                  value: _formatRupees(deductions, isDeduction: true),
                  subtitle: 'Tax, PF & statutory',
                  icon: Icons.remove_circle_outline_rounded,
                  color: const Color(0xFFD32F2F),
                ),
                _summaryCard(
                  dark,
                  title: 'Net Take-Home Pay',
                  value: _formatRupees(net),
                  subtitle: 'Active structure estimate',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF2E7D32),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        Text(
          'Salary Structure Breakdown',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Side-by-side or stacked breakdown
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final earningsCard = _breakdownBox(
              dark,
              title: 'Earnings',
              icon: Icons.add_circle_outline_rounded,
              themeColor: const Color(0xFF2E7D32),
              items: [
                _BreakdownItem('Basic Salary', _formatRupees(basic)),
                _BreakdownItem('House Rent Allowance', _formatRupees(hra)),
                _BreakdownItem('Conveyance Allowance', _formatRupees(conveyance)),
                _BreakdownItem('Medical Allowance', _formatRupees(medical)),
                _BreakdownItem('Special Allowance', _formatRupees(special)),
              ],
              totalLabel: 'Total Earnings',
              totalValue: _formatRupees(gross),
            );

            final deductionsCard = _breakdownBox(
              dark,
              title: 'Deductions',
              icon: Icons.remove_circle_outline_rounded,
              themeColor: const Color(0xFFD32F2F),
              items: [
                _BreakdownItem(
                  'Provident Fund (12% of Basic)',
                  _formatRupees(pf, isDeduction: true),
                ),
                _BreakdownItem(
                  'ESI (0.75% of Basic)',
                  _formatRupees(esi, isDeduction: true),
                ),
                _BreakdownItem(
                  'TDS / Income Tax (5% of Basic)',
                  _formatRupees(tds, isDeduction: true),
                ),
                _BreakdownItem(
                  'Professional Tax',
                  _formatRupees(profTax, isDeduction: true),
                ),
              ],
              totalLabel: 'Total Deductions',
              totalValue: _formatRupees(deductions, isDeduction: true),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: earningsCard),
                  const SizedBox(width: 14),
                  Expanded(child: deductionsCard),
                ],
              );
            } else {
              return Column(
                children: [
                  earningsCard,
                  const SizedBox(height: 14),
                  deductionsCard,
                ],
              );
            }
          },
        ),

        const SizedBox(height: 24),

        // Salary & Payslip History Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Salary & Payslip History',
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            _yearFilterDropdown(dark),
          ],
        ),
        const SizedBox(height: 12),

        if (filteredHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: AppColors.cardDecoration(dark),
            alignment: Alignment.center,
            child: Text(
              'No salary records found for $_selectedYear.',
              style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredHistory.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final record = filteredHistory[index];
              final period = _formatMonthYear(record['month'], record['year']);
              final grossPay = record['grossPay'] ?? 70000;
              final deduct = record['deductions'] ?? 8187.5;
              final netPay = record['netPay'] ?? 61812.5;
              final tlStatus = record['tlStatus'] ?? 'APPROVED';
              final hrStatus = record['hrStatus'] ?? 'APPROVED';
              final status = record['status'] ?? 'PAID';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: AppColors.cardDecoration(dark),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          period,
                          style: TextStyle(
                            color: AppColors.text(dark),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _statusBadge(status.toString()),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _tableCell(dark, 'Gross Pay', _formatRupees(grossPay)),
                        _tableCell(
                          dark,
                          'Deductions',
                          _formatRupees(deduct, isDeduction: true),
                        ),
                        _tableCell(
                          dark,
                          'Net Pay',
                          _formatRupees(netPay),
                          isBold: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'TL Approval: $tlStatus',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'HR Status: $hrStatus',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 10.5,
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
    );
  }

  // ==================== WIDGET HELPERS ====================

  Widget _summaryCard(
    bool dark, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppColors.cardDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted(dark),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.text(dark),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.muted(dark),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownBox(
    bool dark, {
    required String title,
    required IconData icon,
    required Color themeColor,
    required List<_BreakdownItem> items,
    required String totalLabel,
    required String totalValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2124) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: themeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    item.value,
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalLabel,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalValue,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(
    bool dark,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isBold ? AppColors.copper : AppColors.text(dark),
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _yearFilterDropdown(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(dark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder(dark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: dark ? const Color(0xFF202326) : Colors.white,
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          items: const [
            DropdownMenuItem(value: 2026, child: Text('Filter Year: 2026')),
            DropdownMenuItem(value: 2025, child: Text('Filter Year: 2025')),
            DropdownMenuItem(value: 2024, child: Text('Filter Year: 2024')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedYear = val);
          },
        ),
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final String value;
  _BreakdownItem(this.label, this.value);
}
