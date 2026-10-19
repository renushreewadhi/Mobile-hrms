import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/training_api_service.dart';

/// My Certifications page for ETAPRISE HRMS integrated with backend API.
class MyCertificationsPage extends StatefulWidget {
  const MyCertificationsPage({super.key});

  @override
  State<MyCertificationsPage> createState() => _MyCertificationsPageState();
}

class _MyCertificationsPageState extends State<MyCertificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TrainingApiService _trainingApi = TrainingApiService();

  String _filter = 'All';
  String _query = '';
  List<_Certification> _certifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificates() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });

    try {
      final list = await _trainingApi.getCertificates();

      final loadedList = <_Certification>[];
      for (final item in list) {
        if (item is Map) {
          final title =
              item['title']?.toString() ??
              item['certificateTitle']?.toString() ??
              item['courseTitle']?.toString() ??
              item['courseName']?.toString() ??
              item['name']?.toString() ??
              'Certificate of Completion';
          final issuer =
              item['issuer']?.toString() ??
              item['issuedByName']?.toString() ??
              item['issuedBy']?.toString() ??
              item['organization']?.toString() ??
              'ETAPRISE HRMS';
          final category = item['categoryName']?.toString() ?? item['category']?.toString() ?? 'Professional';
          final issuedStr = item['issuedAt']?.toString() ?? item['issuedDate']?.toString() ?? item['issueDate']?.toString() ?? item['createdAt']?.toString();
          final issued = issuedStr != null
              ? DateTime.tryParse(issuedStr) ?? DateTime.now()
              : DateTime.now();
          final credentialId =
              item['certificateNumber']?.toString() ??
              item['credentialId']?.toString() ??
              item['code']?.toString() ??
              item['id']?.toString() ??
              'CERT-000';
          final statusStr =
              item['status']?.toString().toUpperCase() ?? 'COMPLETED';
          final status = statusStr.contains('REVOK')
              ? 'Revoked'
              : statusStr.contains('EXPIRE')
              ? 'Expired'
              : 'Completed';
          final description = item['verificationUrl'] != null
              ? 'Verified credential: ${item['verificationUrl']}'
              : 'Official verified certificate.';

          loadedList.add(
            _Certification(
              title: title,
              issuer: issuer,
              category: category,
              issued: issued,
              credentialId: credentialId,
              status: status,
              icon: Icons.verified_rounded,
              accent: const Color(0xFF149B70),
              description: description,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _certifications = loadedList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e
            .toString()
            .replaceFirst('ApiException: ', '')
            .replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<_Certification> get _visibleCertifications {
    return _certifications.where((cert) {
      final matchesFilter =
          _filter == 'All' ||
          (_filter == 'Completed' && cert.status == 'Completed') ||
          (_filter == 'Expired' && cert.status == 'Expired');
      final q = _query.trim().toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          cert.title.toLowerCase().contains(q) ||
          cert.issuer.toLowerCase().contains(q) ||
          cert.category.toLowerCase().contains(q) ||
          cert.credentialId.toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, dark, _) => Scaffold(
        backgroundColor: dark ? AppColors.graphite : AppColors.cream,
        body: RefreshIndicator(
          onRefresh: _loadCertificates,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    Text(
                      'My Certifications',
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Official credentials, training certificates and achievements',
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _hero(dark),
                    const SizedBox(height: 14),
                    _stats(dark),
                    const SizedBox(height: 18),
                    _search(dark),
                    const SizedBox(height: 12),
                    _filters(dark),
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Certificates',
                            style: TextStyle(
                              color: AppColors.text(dark),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${_visibleCertifications.length} total',
                          style: TextStyle(
                            color: AppColors.muted(dark),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.copper,
                          ),
                        ),
                      )
                    else if (_error != null && _certifications.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadCertificates,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.copper,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_visibleCertifications.isEmpty)
                      _surface(
                        dark,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Icon(
                                Icons.workspace_premium_outlined,
                                size: 38,
                                color: AppColors.muted(dark),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No certificates found',
                                style: TextStyle(
                                  color: AppColors.text(dark),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No certificates have been issued or matched your filter.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted(dark),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._visibleCertifications.map(
                        (cert) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _certCard(dark, cert),
                        ),
                      ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        'ETAPRISE  •  HRMS',
                        style: TextStyle(
                          color: AppColors.muted(dark),
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(bool dark) => _surface(
    dark,
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.copper.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.verified_rounded,
            color: AppColors.accentText(dark),
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verified Credentials',
                style: TextStyle(
                  color: AppColors.text(dark),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Official completion credentials recorded in your company profile.',
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stats(bool dark) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            dark,
            '${_certifications.length}',
            'Active certificates',
            Icons.workspace_premium_rounded,
            const Color(0xFF149B70),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _statCard(
            dark,
            '${_certifications.where((c) => c.status == 'Completed').length}',
            'Completed',
            Icons.task_alt_rounded,
            AppColors.copper,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    bool dark,
    String val,
    String label,
    IconData icon,
    Color tint,
  ) => _surface(
    dark,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(height: 10),
        Text(
          val,
          style: TextStyle(
            color: AppColors.text(dark),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.muted(dark),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _search(bool dark) => TextField(
    controller: _searchController,
    onChanged: (val) => setState(() => _query = val),
    style: TextStyle(color: AppColors.text(dark), fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Search title, issuer, or ID...',
      hintStyle: TextStyle(color: AppColors.muted(dark), fontSize: 11),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: AppColors.muted(dark),
        size: 19,
      ),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.muted(dark),
                size: 18,
              ),
            ),
      filled: true,
      fillColor: AppColors.fieldFill(dark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.glassBorder(dark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.glassBorder(dark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.copper),
      ),
    ),
  );

  Widget _filters(bool dark) {
    final list = ['All', 'Completed', 'Expired'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((item) {
          final selected = _filter == item;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item),
              selected: selected,
              onSelected: (_) => setState(() => _filter = item),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.text(dark),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppColors.copper,
              backgroundColor: AppColors.fieldFill(dark),
              side: BorderSide(
                color: selected
                    ? AppColors.copper
                    : AppColors.glassBorder(dark),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _certCard(bool dark, _Certification cert) {
    return _surface(
      dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cert.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cert.icon, color: cert.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.title,
                      style: TextStyle(
                        color: AppColors.text(dark),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cert.issuer,
                      style: TextStyle(
                        color: AppColors.muted(dark),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF149B70).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cert.status.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF149B70),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cert.description,
            style: TextStyle(
              color: AppColors.text(dark),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.glassBorder(dark)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'ID: ${cert.credentialId}',
                style: TextStyle(
                  color: AppColors.muted(dark),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Issued: ${_dateLabel(cert.issued)}',
                style: TextStyle(color: AppColors.muted(dark), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _surface(bool dark, {required Widget child}) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: AppColors.cardDecoration(dark, radius: 18),
        child: child,
      ),
    ),
  );
}

class _Certification {
  const _Certification({
    required this.title,
    required this.issuer,
    required this.category,
    required this.issued,
    required this.credentialId,
    required this.status,
    required this.icon,
    required this.accent,
    required this.description,
  });

  final String title;
  final String issuer;
  final String category;
  final DateTime issued;
  final String credentialId;
  final String status;
  final IconData icon;
  final Color accent;
  final String description;
}
