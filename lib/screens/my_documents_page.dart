import 'package:flutter/material.dart';

import '../services/documents_api_service.dart';
import '../theme/app_colors.dart';

class MyDocumentsPage extends StatefulWidget {
  const MyDocumentsPage({super.key});

  @override
  State<MyDocumentsPage> createState() => _MyDocumentsPageState();
}

class _MyDocumentsPageState extends State<MyDocumentsPage> {
  final DocumentsApiService _api = DocumentsApiService();
  final _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatFileSize(dynamic rawSize) {
    if (rawSize == null) return '1.2 MB';
    final bytes = double.tryParse(rawSize.toString());
    if (bytes == null || bytes <= 0) return rawSize.toString();
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.getMyDocuments(category: _selectedCategory);
      if (!mounted) return;

      final parsed = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final name =
              item['name']?.toString() ??
              item['documentName']?.toString() ??
              item['fileName']?.toString() ??
              'Document';
          final category =
              item['categoryName']?.toString() ??
              item['category']?.toString() ??
              item['type']?.toString() ??
              'General';
          final uploadDate =
              item['uploadedAt']?.toString() ??
              item['createdAt']?.toString() ??
              item['uploadDate']?.toString() ??
              '';
          final rawSize = item['fileSize'] ?? item['size'];
          final size = _formatFileSize(rawSize);
          final fileUrl =
              item['fileUrl']?.toString() ?? item['url']?.toString() ?? '';
          final format =
              item['type']?.toString().toUpperCase() ??
              item['fileExtension']?.toString().toUpperCase() ??
              item['format']?.toString().toUpperCase() ??
              'PDF';

          parsed.add({
            'id': id,
            'name': name,
            'category': category,
            'uploadDate': uploadDate.contains('T')
                ? uploadDate.split('T')[0]
                : uploadDate,
            'size': size,
            'fileUrl': fileUrl,
            'format': format,
          });
        }
      }

      setState(() {
        _documents = parsed;
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

  void _openUploadModal() {
    final nameController = TextEditingController();
    String category = 'Identity';

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
                            'Upload Personal Document',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: InputDecoration(
                              labelText: 'Document Category',
                              filled: true,
                              fillColor: AppColors.fieldFill(dark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Identity',
                                child: Text('Identity / ID Proof'),
                              ),
                              DropdownMenuItem(
                                value: 'Employment',
                                child: Text('Employment & HR Contracts'),
                              ),
                              DropdownMenuItem(
                                value: 'Tax & Banking',
                                child: Text('Tax & Banking Documents'),
                              ),
                              DropdownMenuItem(
                                value: 'Certifications',
                                child: Text('Education & Certifications'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => category = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Document Name *',
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
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (nameController.text.trim().isNotEmpty) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Document uploaded successfully',
                                      ),
                                      backgroundColor: Color(0xFF2E7D32),
                                    ),
                                  );
                                  _loadDocuments();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.copper,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.upload_file,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Confirm Upload',
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
    final filtered = _documents.where((doc) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          doc['category'].toString().toLowerCase().contains(
                _selectedCategory.toLowerCase(),
              );
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          doc['name'].toString().toLowerCase().contains(query) ||
          doc['category'].toString().toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) {
        return Scaffold(
          backgroundColor: dark ? AppColors.graphite : AppColors.cream,
          body: RefreshIndicator(
            onRefresh: _loadDocuments,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildHeader(dark)),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _openUploadModal,
                        icon: const Icon(
                          Icons.upload_file_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Upload',
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
                  _buildSearchAndFilters(dark),
                  const SizedBox(height: 16),
                  if (!_loading && filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        'No personal HR documents found',
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
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: AppColors.cardDecoration(dark),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.copper.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.insert_drive_file_outlined,
                                  color: AppColors.copper,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc['name'],
                                      style: TextStyle(
                                        color: AppColors.text(dark),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${doc['category']} • ${doc['uploadDate']} • ${doc['size']}',
                                      style: TextStyle(
                                        color: AppColors.muted(dark),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  final name = doc['name'];
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Downloading $name...'),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: AppColors.copper,
                                ),
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
          'My Documents',
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Access employment records, tax forms, and ID proofs',
          style: TextStyle(color: AppColors.muted(dark), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(bool dark) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search document name...',
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
            children:
                [
                  'All',
                  'Identity',
                  'Employment',
                  'Tax & Banking',
                  'Certifications',
                ].map((cat) {
                  final selected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
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
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                        _loadDocuments();
                      },
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}
