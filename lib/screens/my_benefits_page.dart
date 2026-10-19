import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/benefits_api_service.dart';

class MyBenefitsPage extends StatefulWidget {
  const MyBenefitsPage({super.key});

  @override
  State<MyBenefitsPage> createState() => _MyBenefitsPageState();
}

class _MyBenefitsPageState extends State<MyBenefitsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BenefitsApiService _api = BenefitsApiService();

  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _benefitClaims = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBenefits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBenefits() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getMyBenefits(),
        _api.getMyClaims(),
      ]);

      if (!mounted) return;

      final rawPlans = results[0];
      final rawClaims = results[1];

      final parsedPlans = <Map<String, dynamic>>[];
      for (final p in rawPlans) {
        if (p is Map) {
          final title =
              p['title']?.toString() ??
              p['benefitName']?.toString() ??
              p['name']?.toString() ??
              'Benefit Plan';
          final provider =
              p['provider']?.toString() ??
              p['providerName']?.toString() ??
              'Corporate HR';
          final policyNo =
              p['policyNumber']?.toString() ??
              p['policyNo']?.toString() ??
              p['id']?.toString() ??
              'POL-101';
          final coverage =
              p['coverage']?.toString() ??
              p['coverageAmount']?.toString() ??
              'Standard Coverage';
          final status = p['status']?.toString() ?? 'Active';
          final dependents = p['dependents']?.toString() ?? 'Employee Only';

          parsedPlans.add({
            'title': title,
            'provider': provider,
            'policyNo': policyNo,
            'coverage': coverage,
            'status': status,
            'dependents': dependents,
          });
        }
      }

      final parsedClaims = <Map<String, dynamic>>[];
      for (final c in rawClaims) {
        if (c is Map) {
          final id =
              c['id']?.toString() ?? c['claimNumber']?.toString() ?? 'CLM-001';
          final title =
              c['title']?.toString() ??
              c['claimType']?.toString() ??
              'Medical Claim';
          final plan =
              c['benefitTitle']?.toString() ??
              c['benefitName']?.toString() ??
              'Corporate Benefits';
          final amt = c['amount'] ?? c['claimAmount'] ?? 0;
          final amountStr = amt is num
              ? '\$${amt.toStringAsFixed(2)}'
              : '\$$amt';
          final dateStr =
              c['claimDate']?.toString() ?? c['createdAt']?.toString() ?? '';
          final status = c['status']?.toString() ?? 'Pending';

          parsedClaims.add({
            'id': id,
            'title': title,
            'plan': plan,
            'amount': amountStr,
            'date': dateStr.contains('T') ? dateStr.split('T')[0] : dateStr,
            'status': status,
          });
        }
      }

      setState(() {
        _plans = parsedPlans;
        _benefitClaims = parsedClaims;
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

  void _openClaimModal() {
    String plan = _plans.isNotEmpty
        ? _plans.first['title'].toString()
        : 'Corporate Health Insurance';
    final amountController = TextEditingController();
    final descController = TextEditingController();
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
                            'Submit Benefit Reimbursement Claim',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: plan,
                            decoration: InputDecoration(
                              labelText: 'Benefit Plan',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _plans.isNotEmpty
                                ? _plans
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p['title'].toString(),
                                          child: Text(p['title'].toString()),
                                        ),
                                      )
                                      .toList()
                                : const [
                                    DropdownMenuItem(
                                      value: 'Corporate Health Insurance',
                                      child: Text('Corporate Health Insurance'),
                                    ),
                                  ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => plan = val);
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Claim Amount (\$) *',
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
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Claim Title & Description *',
                              hintText: 'Medical checkup, dental invoice...',
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
                                      if (descController.text.trim().isEmpty)
                                        return;
                                      setModalState(() => submitting = true);

                                      final double amt =
                                          double.tryParse(
                                            amountController.text.trim(),
                                          ) ??
                                          0;
                                      final payload = {
                                        'title': descController.text.trim(),
                                        'benefitTitle': plan,
                                        'amount': amt,
                                        'claimDate': DateTime.now()
                                            .toIso8601String()
                                            .split('T')[0],
                                      };

                                      try {
                                        await _api.submitClaim(payload);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Benefit claim submitted successfully',
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFF2E7D32,
                                                  ),
                                                ),
                                              );
                                          _loadBenefits();
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
                                      'Submit Benefit Claim',
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
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadBenefits,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildHeader(dark),
                              ElevatedButton.icon(
                                onPressed: _openClaimModal,
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
                          TabBar(
                            controller: _tabController,
                            indicatorColor: AppColors.copper,
                            labelColor: AppColors.copper,
                            unselectedLabelColor: AppColors.muted(dark),
                            tabs: const [
                              Tab(text: 'Enrolled Plans'),
                              Tab(text: 'My Claims'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [_buildPlansTab(dark), _buildClaimsTab(dark)],
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
          'My Benefits',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Health insurance, allowances, and wellness perks',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPlansTab(bool dark) {
    if (!_loading && _plans.isEmpty) {
      return Center(
        child: Text(
          'No benefit plans enrolled',
          style: TextStyle(color: AppColors.muted(dark)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plan = _plans[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.cardDecoration(dark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      plan['title'],
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
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan['status'],
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Provider: ${plan['provider']} • Policy: ${plan['policyNo']}',
                style: TextStyle(color: AppColors.muted(dark), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coverage: ${plan['coverage']}',
                    style: TextStyle(
                      color: AppColors.copper,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Dependents: ${plan['dependents']}',
                    style: TextStyle(
                      color: AppColors.muted(dark),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClaimsTab(bool dark) {
    if (!_loading && _benefitClaims.isEmpty) {
      return Center(
        child: Text(
          'No benefit claims submitted',
          style: TextStyle(color: AppColors.muted(dark)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _benefitClaims.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final claim = _benefitClaims[index];

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
                    claim['title'],
                    style: TextStyle(
                      color: AppColors.text(dark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    claim['amount'],
                    style: TextStyle(
                      color: AppColors.copper,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${claim['plan']} • ${claim['date']}',
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
                      color: claim['status'] == 'Approved'
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                          : const Color(0xFFED6C02).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      claim['status'],
                      style: TextStyle(
                        color: claim['status'] == 'Approved'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFED6C02),
                        fontSize: 10.5,
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
    );
  }
}
