import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/admin_repository.dart';

class AdminReportsScreen extends StatefulWidget {
  final AdminRepository adminRepo;

  const AdminReportsScreen({super.key, required this.adminRepo});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.adminRepo.getReports(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _reports = data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _moderateReport(
    int reportId,
    String action,
    String reason,
  ) async {
    final noteController = TextEditingController();
    String title = 'Resolve Report';
    Color confirmColor = const Color(0xFF0D6B4F);

    if (action == 'mark_fraudulent') {
      title = 'Take Down Job & Mark Fraudulent';
      confirmColor = const Color(0xFFDC2626);
    } else if (action == 'dismiss') {
      title = 'Dismiss Report';
      confirmColor = Colors.grey.shade700;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Action on report: "$reason"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Audit / Resolution Notes',
                hintText: 'Describe resolution...',
              ),
            ),
          ],
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await widget.adminRepo.moderateReport(
        reportId,
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
              content: Text('Report resolution "$action" applied.'),
            ),
          );
          _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Failed to update report.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Moderation'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Status Selector Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                _buildStatusChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildStatusChip('Resolved', 'resolved'),
                const SizedBox(width: 8),
                _buildStatusChip('Dismissed', 'dismissed'),
                const SizedBox(width: 8),
                _buildStatusChip('All', 'all'),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text('No $_selectedStatus abuse reports found.'),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final r = _reports[index];
                        final id = r['id'] ?? 0;
                        final reason = r['reason'] ?? 'Unspecified';
                        final desc =
                            r['description'] ?? 'No description provided';
                        final reporterName =
                            r['reporter']?['name'] ?? 'Anonymous';
                        final jobTitle = r['job']?['title'];
                        final reportedUser = r['reported_user']?['name'];
                        final status = (r['status'] ?? 'pending').toString();
                        final actionTaken = r['action_taken'];
                        final isPending = status == 'pending';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.report_problem_outlined,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              reason,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
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
                                        color: isPending
                                            ? Colors.amber.shade100
                                            : (status == 'resolved'
                                                  ? Colors.green.shade100
                                                  : Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isPending
                                              ? Colors.amber.shade900
                                              : (status == 'resolved'
                                                    ? Colors.green.shade900
                                                    : Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Submitted by: $reporterName',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (jobTitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Related Job: $jobTitle',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (reportedUser != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reported User: $reportedUser',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (actionTaken != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Action: $actionTaken',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isPending) ...[
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () => _moderateReport(
                                          id,
                                          'dismiss',
                                          reason,
                                        ),
                                        child: const Text('Dismiss'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFDC2626,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: () => _moderateReport(
                                          id,
                                          'mark_fraudulent',
                                          reason,
                                        ),
                                        child: const Text(
                                          'Takedown & Mark Fraud',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = value);
          _load();
        }
      },
    );
  }
}
