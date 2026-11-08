import 'package:flutter/material.dart';

import '../../models/job_alert_model.dart';
import '../../models/job_model.dart';
import '../../repositories/career_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../shared/widgets/job_card.dart';
import '../jobs/job_details_screen.dart';
import '../../repositories/job_repository.dart';

import 'package:provider/provider.dart';

class JobAlertsScreen extends StatefulWidget {
  final CareerRepository? careerRepo;

  const JobAlertsScreen({super.key, this.careerRepo});

  @override
  State<JobAlertsScreen> createState() => _JobAlertsScreenState();
}

class _JobAlertsScreenState extends State<JobAlertsScreen> {
  List<JobAlertModel> _alerts = [];
  bool _isLoading = true;

  CareerRepository get _careerRepo =>
      widget.careerRepo ??
      Provider.of<CareerRepository>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final data = await _careerRepo.getJobAlerts();
      if (mounted) {
        setState(() {
          _alerts = data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAlert(JobAlertModel alert) async {
    final success = await _careerRepo.toggleJobAlert(alert.id);
    if (success && mounted) {
      setState(() {
        final index = _alerts.indexWhere((a) => a.id == alert.id);
        if (index != -1) {
          _alerts[index] = _alerts[index].copyWith(
            isActive: !_alerts[index].isActive,
          );
        }
      });
    }
  }

  Future<void> _deleteAlert(int alertId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job Alert?'),
        content: const Text(
          'Are you sure you want to stop receiving vacancy notifications for this alert?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _careerRepo.deleteJobAlert(alertId);
      if (success && mounted) {
        setState(() => _alerts.removeWhere((a) => a.id == alertId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job alert deleted successfully.')),
        );
      }
    }
  }

  void _showCreateAlertDialog() {
    final titleCtrl = TextEditingController();
    final keywordCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    String frequency = 'daily';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_alert, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text('Create Job Alert', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alert Name *',
                    hintText: 'e.g. Flutter Jobs in Addis',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keywordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Keyword / Job Title',
                    hintText: 'e.g. Software Engineer, Accountant',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Location / City',
                    hintText: 'e.g. Addis Ababa, Hawassa, Remote',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: salaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Salary (ETB)',
                    hintText: 'e.g. 35000',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Notification Frequency',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'instant',
                      child: Text('Instant (As soon as posted)'),
                    ),
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily Digest'),
                    ),
                    DropdownMenuItem(
                      value: 'weekly',
                      child: Text('Weekly Summary'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => frequency = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter an alert title.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final newAlert = await _careerRepo.createJobAlert({
                        'title': titleCtrl.text.trim(),
                        if (keywordCtrl.text.trim().isNotEmpty)
                          'keyword': keywordCtrl.text.trim(),
                        if (locationCtrl.text.trim().isNotEmpty)
                          'location': locationCtrl.text.trim(),
                        if (salaryCtrl.text.trim().isNotEmpty)
                          'min_salary': double.tryParse(salaryCtrl.text.trim()),
                        'frequency': frequency,
                      });

                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        if (newAlert != null) {
                          _loadAlerts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF0D6B4F),
                              content: Text(
                                'Job alert created! You will receive notifications for matching jobs.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Create Alert'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchesModal(JobAlertModel alert) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => FutureBuilder<List<JobModel>>(
          future: _careerRepo.getJobAlertMatches(alert.id),
          builder: (context, snapshot) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Color(0xFF0D6B4F),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Matching Vacancies for "${alert.title}"',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : (snapshot.data == null || snapshot.data!.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.work_off_outlined,
                                size: 54,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No active vacancies currently match "${alert.title}".',
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'We will notify you immediately when a new matching job is posted.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, i) {
                            final job = snapshot.data![i];
                            return JobCard(
                              job: job,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailsScreen(
                                      jobId: job.id,
                                      jobRepo: Provider.of<JobRepository>(
                                        context,
                                        listen: false,
                                      ),
                                      appRepo:
                                          Provider.of<ApplicationRepository>(
                                            context,
                                            listen: false,
                                          ),
                                      profRepo: Provider.of<ProfileRepository>(
                                        context,
                                        listen: false,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Job Alerts'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAlerts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D6B4F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert),
        label: const Text('New Job Alert'),
        onPressed: _showCreateAlertDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Job Alerts Set',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create custom alerts by job title, location, or salary to get instant notifications when relevant vacancies are published.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6B4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.add_alert),
                      label: const Text('Create Your First Alert'),
                      onPressed: _showCreateAlertDialog,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _alerts.length,
                itemBuilder: (context, index) {
                  final a = _alerts[index];
                  final hasMatches = a.matchingJobsCount > 0;

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      a.isActive
                                          ? Icons.notifications_active
                                          : Icons.notifications_off,
                                      color: a.isActive
                                          ? const Color(0xFF0D6B4F)
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: a.isActive
                                              ? Colors.black87
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: a.isActive,
                                activeColor: const Color(0xFF0D6B4F),
                                onChanged: (_) => _toggleAlert(a),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Filter details
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (a.keyword != null && a.keyword!.isNotEmpty)
                                _buildFilterTag(
                                  Icons.search,
                                  'Keyword: ${a.keyword}',
                                ),
                              if (a.location != null && a.location!.isNotEmpty)
                                _buildFilterTag(Icons.location_on, a.location!),
                              if (a.minSalary != null)
                                _buildFilterTag(
                                  Icons.payments_outlined,
                                  'Min ${a.minSalary!.toStringAsFixed(0)} ETB',
                                ),
                              _buildFilterTag(
                                Icons.schedule,
                                a.frequency.toUpperCase(),
                              ),
                            ],
                          ),
                          const Divider(height: 18),

                          // Bottom Row: Matches Button & Delete Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _showMatchesModal(a),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasMatches
                                        ? const Color(0xFFDCFCE7)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.work_outline,
                                        size: 14,
                                        color: hasMatches
                                            ? const Color(0xFF0D6B4F)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${a.matchingJobsCount} Matching Vacancies',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: hasMatches
                                              ? const Color(0xFF0D6B4F)
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 14),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Alert',
                                onPressed: () => _deleteAlert(a.id),
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

  Widget _buildFilterTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
