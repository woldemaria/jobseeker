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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await widget.adminRepo.getReports();
    if (mounted) {
      setState(() {
        _reports = data;
        _isLoading = false;
      });
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No user or vacancy abuse reports found.'),
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
                      final reason = r['reason'] ?? 'Unspecified';
                      final desc = r['description'] ?? 'No description provided';
                      final reporterName = r['reporter']?['name'] ?? 'Anonymous';
                      final jobTitle = r['job']?['title'];
                      final reportedUser = r['reported_user']?['name'];
                      final status = (r['status'] ?? 'pending').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.report_problem_outlined, color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        reason,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(desc, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text('Submitted by: $reporterName', style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5)),
                              if (jobTitle != null) ...[
                                const SizedBox(height: 4),
                                Text('Related Job: $jobTitle', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                              if (reportedUser != null) ...[
                                const SizedBox(height: 4),
                                Text('Reported User: $reportedUser', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
