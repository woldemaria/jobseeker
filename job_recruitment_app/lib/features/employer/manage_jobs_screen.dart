import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';
import 'job_applicants_screen.dart';
import 'create_job_screen.dart';
import '../../repositories/advertisement_repository.dart';
import '../admin/advertisement_form_dialog.dart';
import '../admin/advertisement_management_screen.dart';

class ManageJobsScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository? profRepo;

  const ManageJobsScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    this.profRepo,
  });

  @override
  State<ManageJobsScreen> createState() => ManageJobsScreenState();
}

class ManageJobsScreenState extends State<ManageJobsScreen> {
  List<JobModel> _jobs = [];
  bool _isLoading = true;
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadJobs();
  }

  Future<void> loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.jobRepo.getEmployerJobs();
      if (mounted) {
        setState(() {
          _jobs = results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<JobModel> get _filteredJobs {
    if (_selectedStatusFilter == 'all') {
      return _jobs;
    }
    return _jobs
        .where((j) => j.status.toLowerCase() == _selectedStatusFilter)
        .toList();
  }

  Future<void> _updateJobStatus(JobModel job, String newStatus) async {
    final resp = await widget.jobRepo.updateJob(job.id, {'status': newStatus});
    if (mounted) {
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vacancy status updated to ${newStatus.toUpperCase()}.',
            ),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
        loadJobs();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resp.message)));
      }
    }
  }

  Future<void> _archiveJob(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Vacancy'),
        content: const Text(
          'Are you sure you want to close and archive this vacancy? It will no longer receive applications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final resp = await widget.jobRepo.archiveJob(id);
      if (resp.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vacancy archived successfully.')),
          );
        }
        loadJobs();
      }
    }
  }

  Future<void> _showNoticePoster(JobModel job) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final resp = await apiService.get('/jobs/${job.id}/poster');

    if (!mounted) return;

    if (resp.success && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.qr_code_2, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Physical Notice Board Poster',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOTICE CODE: ${data['notice_code'] ?? "ET-JOB"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0D6B4F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['title'] ?? job.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        data['employer_name'] ??
                            (job.employer?.organizationName ?? "Employer"),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                      const Divider(height: 16),
                      Text('• Location: ${data['location'] ?? job.location}'),
                      Text(
                        '• Employment: ${data['employment_type'] ?? job.employmentType}',
                      ),
                      Text(
                        '• Compensation: ${data['salary_text'] ?? job.salaryText}',
                      ),
                      Text(
                        '• Deadline: ${(data['deadline'] ?? job.deadline).toString().split('T').first}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'QR Scan Payload (Kebele / Campus Notice Boards):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  data['qr_payload'] ?? 'JOBSEEKER://VACANCY/${job.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFF0D6B4F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['instructions'] ?? 'Scan with JobSeeker Ethiopia app for instant 1-tap application.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp.message.isNotEmpty
                ? resp.message
                : 'Unable to generate notice poster.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final displayedJobs = _filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('manage_jobs')),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Ad Campaigns',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdvertisementManagementScreen(),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadJobs),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_jobs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'published',
                  'Published (${_jobs.where((j) => j.status == 'published').length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'closed',
                  'Closed (${_jobs.where((j) => j.status == 'closed').length})',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'draft',
                  'Draft (${_jobs.where((j) => j.status == 'draft').length})',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedJobs.isEmpty
                ? RefreshIndicator(
                    onRefresh: loadJobs,
                    child: ListView(
                      children: [
                        const SizedBox(height: 60),
                        EmptyStateWidget(
                          icon: Icons.post_add_outlined,
                          title: _selectedStatusFilter == 'all'
                              ? 'No Vacancies Found'
                              : 'No $_selectedStatusFilter vacancies',
                          subtitle: 'Create and publish job postings to receive skilled candidate applications.',
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: loadJobs,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayedJobs.length,
                      itemBuilder: (context, index) {
                        final job = displayedJobs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobApplicantsScreen(
                                    jobId: job.id,
                                    jobTitle: job.title,
                                    jobRepo: widget.jobRepo,
                                    appRepo: widget.appRepo,
                                  ),
                                ),
                              ).then((_) => loadJobs());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          job.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      StatusBadge(status: job.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        '${job.location} • ${job.employmentType}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Deadline: ${job.deadline}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  JobApplicantsScreen(
                                                    jobId: job.id,
                                                    jobTitle: job.title,
                                                    jobRepo: widget.jobRepo,
                                                    appRepo: widget.appRepo,
                                                  ),
                                            ),
                                          ).then((_) => loadJobs());
                                        },
                                        icon: const Icon(
                                          Icons.people,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '${loc.t('applicants')} (${job.applicantsCount ?? 0})',
                                        ),
                                      ),
                                      const Spacer(),
                                      // Edit Button
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          final prof =
                                              widget.profRepo ??
                                              ProfileRepository(
                                                Provider.of<ApiService>(
                                                  context,
                                                  listen: false,
                                                ),
                                              );
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreateJobScreen(
                                                jobRepo: widget.jobRepo,
                                                profRepo: prof,
                                                initialJob: job,
                                                onSuccess: loadJobs,
                                              ),
                                            ),
                                          ).then((_) => loadJobs());
                                        },
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 15,
                                          color: Color(0xFF0D6B4F),
                                        ),
                                        label: const Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0D6B4F),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          side: const BorderSide(
                                            color: Color(0xFF0D6B4F),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Delete Button
                                      OutlinedButton.icon(
                                        onPressed: () => _archiveJob(job.id),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 15,
                                          color: Color(0xFFDC2626),
                                        ),
                                        label: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          side: const BorderSide(
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Status Change Menu
                                      PopupMenuButton<String>(
                                        tooltip: 'Change Status',
                                        icon: const Icon(
                                          Icons.more_vert,
                                          color: Color(0xFF64748B),
                                        ),
                                        onSelected: (val) {
                                          if (val == 'archive') {
                                            _archiveJob(job.id);
                                          } else if (val == 'poster') {
                                            _showNoticePoster(job);
                                          } else if (val == 'edit') {
                                            final prof =
                                                widget.profRepo ??
                                                ProfileRepository(
                                                  Provider.of<ApiService>(
                                                    context,
                                                    listen: false,
                                                  ),
                                                );
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CreateJobScreen(
                                                  jobRepo: widget.jobRepo,
                                                  profRepo: prof,
                                                  initialJob: job,
                                                  onSuccess: loadJobs,
                                                ),
                                              ),
                                            ).then((_) => loadJobs());
                                          } else if (val == 'promote') {
                                            AdvertisementFormDialog.show(
                                              context,
                                              adRepo:
                                                  Provider.of<
                                                    AdvertisementRepository
                                                  >(context, listen: false),
                                              initialJob: job,
                                            );
                                          } else {
                                            _updateJobStatus(job, val);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'promote',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.campaign,
                                                  color: Color(0xFF0D6B4F),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Promote / Sponsor Campaign',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'poster',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.qr_code_2,
                                                  color: Color(0xFF0D6B4F),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Notice Board Poster & QR',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  color: Color(0xFF0D6B4F),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text('Edit Vacancy Details'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuDivider(),
                                          if (job.status != 'published')
                                            const PopupMenuItem(
                                              value: 'published',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_outline,
                                                    color: Color(0xFF0D6B4F),
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Publish Vacancy'),
                                                ],
                                              ),
                                            ),
                                          if (job.status != 'closed')
                                            const PopupMenuItem(
                                              value: 'closed',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.pause_circle_outline,
                                                    color: Color(0xFFD97706),
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Close Vacancy'),
                                                ],
                                              ),
                                            ),
                                          if (job.status != 'draft')
                                            const PopupMenuItem(
                                              value: 'draft',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_note,
                                                    color: Color(0xFF64748B),
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Set as Draft'),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: 'archive',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  color: Color(0xFFDC2626),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete / Archive Vacancy',
                                                  style: TextStyle(
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0D6B4F).withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0D6B4F) : const Color(0xFF475569),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatusFilter = value);
        }
      },
    );
  }
}
