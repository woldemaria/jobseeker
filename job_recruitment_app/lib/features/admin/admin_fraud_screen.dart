import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/admin_repository.dart';

class AdminFraudScreen extends StatefulWidget {
  final AdminRepository adminRepo;

  const AdminFraudScreen({super.key, required this.adminRepo});

  @override
  State<AdminFraudScreen> createState() => _AdminFraudScreenState();
}

class _AdminFraudScreenState extends State<AdminFraudScreen> {
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  bool _isScanning = false;
  String _selectedRisk = 'all';
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.adminRepo.getFraudJobs(
        riskLevel: _selectedRisk,
        moderationStatus: _selectedStatus,
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
      );
      if (mounted) {
        setState(() {
          _jobs = res['items'] ?? [];
          _summary = res['meta']?['summary'] ?? {};
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runFraudScan() async {
    setState(() => _isScanning = true);
    final res = await widget.adminRepo.runFraudScan();
    if (mounted) {
      setState(() => _isScanning = false);
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D6B4F),
            content: Text(
              'Scam Scan Complete: ${res['total_scanned']} scanned, ${res['flagged_count']} flagged, ${res['quarantined_count']} quarantined.',
            ),
          ),
        );
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to complete automated fraud scan.'),
          ),
        );
      }
    }
  }

  Future<void> _moderateJob(int jobId, String action, String jobTitle) async {
    final noteController = TextEditingController();
    String actionLabel = action;
    Color confirmColor = Colors.red;

    if (action == 'mark_fraudulent') {
      actionLabel = 'Mark as Fraudulent (Takedown)';
      confirmColor = Colors.red.shade700;
    } else if (action == 'mark_safe') {
      actionLabel = 'Mark as Safe & Restore';
      confirmColor = const Color(0xFF0D6B4F);
    } else if (action == 'suspend_employer') {
      actionLabel = 'Suspend Recruiter / Organization';
      confirmColor = Colors.black87;
    } else if (action == 'takedown') {
      actionLabel = 'Take Down Listing';
      confirmColor = Colors.orange.shade800;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              action == 'mark_safe'
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: confirmColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(actionLabel, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apply moderation action to "$jobTitle"?',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Moderation Reason / Audit Notes',
                  hintText: 'Enter justification for this decision...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Action'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await widget.adminRepo.moderateJob(
        jobId,
        action,
        notes: noteController.text.trim().isNotEmpty
            ? noteController.text.trim()
            : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0D6B4F),
              content: Text(
                'Moderation action "$action" successfully applied to listing.',
              ),
            ),
          );
          _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Failed to execute moderation action.'),
            ),
          );
        }
      }
    }
  }

  Color _getRiskColor(String level, int score) {
    if (level == 'critical' || score >= 80) return const Color(0xFFDC2626);
    if (level == 'high' || score >= 60) return const Color(0xFFEA580C);
    if (level == 'medium' || score >= 30) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final totalFlagged = _summary['total_flagged'] ?? _jobs.length;
    final criticalCount = _summary['critical_count'] ?? 0;
    final underReviewCount = _summary['under_review_count'] ?? 0;
    final fraudulentCount = _summary['fraudulent_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraudulent Job Ads Moderation'),
        actions: [
          IconButton(
            tooltip: 'Run Platform Scam Scan',
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.security_update_good),
            onPressed: _isScanning ? null : _runFraudScan,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Metric Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildKpiChip('Flagged', '$totalFlagged', Colors.orange),
                const SizedBox(width: 8),
                _buildKpiChip('Critical', '$criticalCount', Colors.red),
                const SizedBox(width: 8),
                _buildKpiChip(
                  'Under Review',
                  '$underReviewCount',
                  Colors.amber,
                ),
                const SizedBox(width: 8),
                _buildKpiChip('Takedowns', '$fraudulentCount', Colors.purple),
              ],
            ),
          ),

          // Search and Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search flagged vacancies or companies...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _load();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter Risk Level',
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('All Risks', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('Critical', 'critical'),
                const SizedBox(width: 6),
                _buildFilterChip('High', 'high'),
                const SizedBox(width: 6),
                _buildFilterChip('Medium', 'medium'),
              ],
            ),
          ),

          // Main List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_user,
                          size: 64,
                          color: Color(0xFF0D6B4F),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Fraudulent Job Advertisements Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Platform listings comply with recruitment safety rules.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        final title = job['title'] ?? 'Untitled Vacancy';
                        final org =
                            job['employer']?['organization_name'] ??
                            'Unknown Organization';
                        final isVerifiedOrg =
                            job['employer']?['verification_status'] ==
                            'approved';
                        final score = (job['fraud_score'] is int)
                            ? job['fraud_score'] as int
                            : (int.tryParse(
                                    job['fraud_score']?.toString() ?? '0',
                                  ) ??
                                  0);
                        final riskLevel = (job['fraud_risk_level'] ?? 'low')
                            .toString();
                        final modStatus = (job['moderation_status'] ?? 'clean')
                            .toString();
                        final indicators = (job['fraud_indicators'] is List)
                            ? (job['fraud_indicators'] as List)
                                  .map((e) => e.toString())
                                  .toList()
                            : <String>[];
                        final reportCount = job['reports_count'] ?? 0;
                        final riskColor = _getRiskColor(riskLevel, score);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: riskColor.withOpacity(0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row: Risk Score Badge & Moderation Status
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
                                        color: riskColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: riskColor),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 14,
                                            color: riskColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'RISK: $score/100 (${riskLevel.toUpperCase()})',
                                            style: TextStyle(
                                              color: riskColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        modStatus.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Job Title
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Employer Organization
                                Row(
                                  children: [
                                    Icon(
                                      isVerifiedOrg
                                          ? Icons.verified
                                          : Icons.warning_amber,
                                      size: 14,
                                      color: isVerifiedOrg
                                          ? const Color(0xFF0D6B4F)
                                          : Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      org,
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!isVerifiedOrg) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(Unverified)',
                                        style: TextStyle(
                                          color: Colors.amber.shade900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                // Reports Badge if any
                                if (reportCount > 0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.flag,
                                        size: 13,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$reportCount Community User Report(s)',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),

                                // Flagged Indicators
                                if (indicators.isNotEmpty) ...[
                                  const Text(
                                    'Detected Scam Indicators:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...indicators.map(
                                    (ind) => Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              ind,
                                              style: TextStyle(
                                                color: Colors.red.shade900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const Divider(height: 18),

                                // Moderation Action Buttons
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      icon: const Icon(Icons.block, size: 15),
                                      label: const Text('Mark Fraudulent'),
                                      onPressed: () => _moderateJob(
                                        job['id'],
                                        'mark_fraudulent',
                                        title,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0D6B4F,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 15,
                                      ),
                                      label: const Text('Mark Safe'),
                                      onPressed: () => _moderateJob(
                                        job['id'],
                                        'mark_safe',
                                        title,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade800,
                                        side: BorderSide(
                                          color: Colors.red.shade400,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.person_off_outlined,
                                        size: 15,
                                      ),
                                      label: const Text('Suspend Employer'),
                                      onPressed: () => _moderateJob(
                                        job['id'],
                                        'suspend_employer',
                                        title,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedRisk == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedRisk = value);
          _load();
        }
      },
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Moderation Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('All Vacancies (Flagged & High Risk)'),
              trailing: _selectedStatus == 'all'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                setState(() => _selectedStatus = 'all');
                Navigator.pop(ctx);
                _load();
              },
            ),
            ListTile(
              title: const Text('Under Review (Auto-Quarantined)'),
              trailing: _selectedStatus == 'under_review'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                setState(() => _selectedStatus = 'under_review');
                Navigator.pop(ctx);
                _load();
              },
            ),
            ListTile(
              title: const Text('Confirmed Fraudulent (Takedowns)'),
              trailing: _selectedStatus == 'fraudulent'
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                setState(() => _selectedStatus = 'fraudulent');
                Navigator.pop(ctx);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}
