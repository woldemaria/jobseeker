import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/admin_repository.dart';

class AdminVerificationsScreen extends StatefulWidget {
  final AdminRepository adminRepo;

  const AdminVerificationsScreen({super.key, required this.adminRepo});

  @override
  State<AdminVerificationsScreen> createState() =>
      _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  List<Map<String, dynamic>> _verifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVerifications();
  }

  Future<void> _loadVerifications() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.adminRepo.getVerifications();
      if (mounted) {
        setState(() {
          _verifications = data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reviewDialog(Map<String, dynamic> v) async {
    final notesController = TextEditingController(
      text: v['review_notes'] ?? '',
    );
    String decision = 'approved';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final org = v['employer']?['organization_name'] ?? 'Employer';

          return AlertDialog(
            title: Text('Review Verification for $org'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification Decision',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: decision,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approve (Verify Organization)'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Reject (Deny Verification)'),
                    ),
                    DropdownMenuItem(
                      value: 'requires_changes',
                      child: Text('Requires Changes / Resubmit'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => decision = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reviewer Feedback Notes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Provide feedback or reasons for the employer...',
                    border: OutlineInputBorder(),
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
                  backgroundColor: decision == 'approved'
                      ? AppTheme.primaryColor
                      : Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit Decision'),
              ),
            ],
          );
        },
      ),
    );

    if (submitted == true) {
      final success = await widget.adminRepo.reviewVerification(
        v['id'] as int,
        decision,
        notes: notesController.text.trim(),
      );
      if (mounted) {
        if (success) {
          _loadVerifications();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification marked as $decision')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit decision')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employer Verifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVerifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _verifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('No employer verification requests found.'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadVerifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _verifications.length,
                itemBuilder: (context, index) {
                  final v = _verifications[index];
                  final org =
                      v['employer']?['organization_name'] ?? 'Organization';
                  final email = v['employer']?['email'] ?? '';
                  final tin = v['tax_identification_number'] ?? 'N/A';
                  final license = v['license_number'] ?? 'N/A';
                  final status = (v['status'] ?? 'pending').toString();
                  final submittedAt = (v['submitted_at'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  org,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(status),
                                  ),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Email: $email',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'TIN Number: $tin • License: $license',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          if (submittedAt.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Submitted: ${submittedAt.split("T").first}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (v['review_notes'] != null &&
                              v['review_notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Review Notes: ${v['review_notes']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _reviewDialog(v),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.rule, size: 16),
                                label: const Text('Review Verification'),
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.amber.shade800;
      case 'rejected':
        return Colors.red;
      case 'requires_changes':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
