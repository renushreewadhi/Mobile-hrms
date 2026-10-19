import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/assets_api_service.dart';

class MyAssetsPage extends StatefulWidget {
  const MyAssetsPage({super.key});

  @override
  State<MyAssetsPage> createState() => _MyAssetsPageState();
}

class _MyAssetsPageState extends State<MyAssetsPage> {
  final AssetsApiService _api = AssetsApiService();

  List<Map<String, dynamic>> _myAssets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getMyAssets();
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final tag =
              item['assetTag']?.toString() ??
              item['tagNumber']?.toString() ??
              item['id']?.toString() ??
              'AST-001';
          final name =
              item['name']?.toString() ??
              item['assetName']?.toString() ??
              'Company Equipment';
          final category =
              item['categoryName']?.toString() ??
              item['category']?.toString() ??
              'Hardware';
          final serial = item['serialNumber']?.toString() ?? 'N/A';
          final assignedDate =
              item['assignedDate']?.toString() ??
              item['assignedAt']?.toString() ??
              '';
          final condition = item['condition']?.toString() ?? 'Good';
          final status = item['status']?.toString() ?? 'Assigned';

          parsed.add({
            'tag': tag,
            'name': name,
            'category': category,
            'serial': serial,
            'assignedDate': assignedDate.contains('T')
                ? assignedDate.split('T')[0]
                : assignedDate,
            'condition': condition,
            'status': status,
          });
        }
      }

      setState(() {
        _myAssets = parsed;
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

  void _openRequestAssetModal() {
    String type = 'Hardware Equipment';
    final reasonController = TextEditingController();
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
                            'Request New Asset / Equipment',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: InputDecoration(
                              labelText: 'Asset Category',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Hardware Equipment',
                                child: Text(
                                  'Hardware Equipment (Laptop, Monitor)',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Mobile Device',
                                child: Text('Mobile Test Device'),
                              ),
                              DropdownMenuItem(
                                value: 'Software License',
                                child: Text('Software License / Tool'),
                              ),
                              DropdownMenuItem(
                                value: 'Office Accessory',
                                child: Text('Office Accessory'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => type = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: reasonController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Business Reason & Specification *',
                              hintText: 'Describe required specs or reason for request...',
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
                                      if (reasonController.text.trim().isEmpty)
                                        return;
                                      setModalState(() => submitting = true);

                                      final payload = {
                                        'category': type,
                                        'reason': reasonController.text.trim(),
                                      };

                                      try {
                                        await _api.requestAsset(payload);
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Asset request submitted successfully',
                                                  ),
                                                  backgroundColor: Color(
                                                    0xFF2E7D32,
                                                  ),
                                                ),
                                              );
                                          _loadAssets();
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
                                      'Submit Request',
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
            onRefresh: _loadAssets,
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
                        onPressed: _openRequestAssetModal,
                        icon: const Icon(
                          Icons.add,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Request Asset',
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
                  if (!_loading && _myAssets.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No company assets assigned',
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
                      itemCount: _myAssets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final asset = _myAssets[index];

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
                                    asset['tag'],
                                    style: TextStyle(
                                      color: AppColors.copper,
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
                                      color: const Color(0xFF2E7D32)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      asset['status'],
                                      style: const TextStyle(
                                        color: Color(0xFF2E7D32),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                asset['name'],
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: ${asset['category']} • Serial: ${asset['serial']}',
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Assigned: ${asset['assignedDate']}',
                                    style: TextStyle(
                                      color: AppColors.muted(dark),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Condition: ${asset['condition']}',
                                    style: TextStyle(
                                      color: AppColors.accentText(dark),
                                      fontSize: 11,
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
          'My Assets',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hardware devices and software subscriptions assigned to you',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }
}
