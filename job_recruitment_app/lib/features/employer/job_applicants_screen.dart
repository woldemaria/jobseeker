import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../services/storage_service.dart';
import '../../core/constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';

class JobApplicantsScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;

  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.jobRepo,
    required this.appRepo,
  });

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  List<dynamic> _applicants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await widget.jobRepo.getJobApplicants(widget.jobId);
    if (mounted) {
      setState(() {
        _applicants = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _viewCvDocument(Map<String, dynamic> cvDoc) async {
    final docId = cvDoc['id'];
    if (docId == null) return;

    final storage = Provider.of<StorageService>(context, listen: false);
    final token = storage.getToken();
    final url = Uri.parse('${ApiConstants.baseUrl}/documents/$docId/view?token=$token&inline=1');

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open document: $e')),
        );
      }
    }
  }

  void _showScheduleInterviewDialog(Map<String, dynamic> app) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    String interviewType = 'video';
    final locationController = TextEditingController(text: 'Google Meet: https://meet.google.com/new');
    final notesController = TextEditingController(text: 'Please prepare to present your previous portfolio and experience.');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.video_call, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text('Schedule Interview', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Candidate: ${app['profile']?['user']?['name'] ?? "Applicant"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, size: 20, color: Color(0xFF0D6B4F)),
                  title: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} at ${selectedTime.format(context)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        setDialogState(() {
                          selectedDate = pickedDate;
                          if (pickedTime != null) selectedTime = pickedTime;
                        });
                      }
                    },
                    child: const Text('Pick Date/Time'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: interviewType,
                  decoration: const InputDecoration(labelText: 'Interview Format'),
                  items: const [
                    DropdownMenuItem(value: 'video', child: Text('Online Video (Google Meet / Zoom)')),
                    DropdownMenuItem(value: 'in_person', child: Text('In-Person Workplace Meeting')),
                    DropdownMenuItem(value: 'phone', child: Text('Phone Screening Call')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        interviewType = val;
                        if (val == 'video') {
                          locationController.text = 'Google Meet: https://meet.google.com/new';
                        } else if (val == 'phone') {
                          locationController.text = 'Phone Call to ${app['profile']?['user']?['phone'] ?? "Candidate"}';
                        } else {
                          locationController.text = 'Company Headquarters Office';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Link or Physical Location',
                    hintText: 'e.g. https://meet.google.com/abc-xyz or Office Address',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Preparation Instructions & Notes',
                    hintText: 'Items candidate should prepare...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final formattedDate =
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}T${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00Z';

                      final resp = await widget.appRepo.scheduleInterview(
                        applicationId: app['id'],
                        interviewAt: formattedDate,
                        interviewType: interviewType,
                        interviewLocation: locationController.text.trim(),
                        interviewNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        if (resp.success) {
                          _load();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Interview invitation scheduled and dispatched to candidate!'),
                              backgroundColor: Color(0xFF0D6B4F),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(resp.message)),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6B4F), foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(Map<String, dynamic> app) {
    const allowedStatuses = ['submitted', 'under_review', 'shortlisted', 'interview', 'accepted', 'rejected', 'withdrawn'];
    String currentStatus = (app['status'] as String? ?? 'submitted').toLowerCase();
    if (!allowedStatuses.contains(currentStatus)) {
      currentStatus = 'submitted';
    }
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Update Recruitment Decision'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: currentStatus,
                decoration: const InputDecoration(labelText: 'Application Status'),
                items: const [
                  DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                  DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                  DropdownMenuItem(value: 'shortlisted', child: Text('Shortlisted')),
                  DropdownMenuItem(value: 'interview', child: Text('Interview Scheduled')),
                  DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(value: 'withdrawn', child: Text('Withdrawn by Applicant')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => currentStatus = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Feedback / Interview Notes',
                  hintText: 'Notes for applicant notification and internal tracking...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final resp = await widget.appRepo.updateStatus(
                  app['id'],
                  currentStatus,
                  notes: notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                );
                if (resp.success) {
                  _load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recruitment status updated!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(resp.message)),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCandidates() async {
    final resp = await widget.jobRepo.exportCandidatePack(widget.jobId);
    if (!mounted) return;

    if (resp.success && resp.data != null) {
      final data = resp.data as Map<String, dynamic>;
      final count = data['total_candidates'] ?? 0;
      final summary = data['dossier_summary'] ?? 'Candidate dossier exported successfully.';
      final candidates = (data['candidates'] as List?) ?? [];

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text('Candidate Dossier Pack', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vacancy: ${widget.jobTitle}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Total Shortlisted Profiles: $count candidate(s)', style: const TextStyle(color: Color(0xFF0D6B4F), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(summary, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Divider(height: 20),
                  if (candidates.isEmpty)
                    const Text('No shortlisted candidates yet to export.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ...candidates.map((c) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person, color: Color(0xFF0D6B4F)),
                          title: Text(c['candidate_name'] ?? 'Candidate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${c['email']} • ${c['status']}', style: const TextStyle(fontSize: 11)),
                        )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.message.isNotEmpty ? resp.message : 'Unable to export candidate pack.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.t('applicants')}: ${widget.jobTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Candidate Pack',
            onPressed: _exportCandidates,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Applicants Yet',
                  subtitle: 'Candidates who apply for this vacancy will appear here for review and recruitment decisions.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _applicants.length,
                    itemBuilder: (context, index) {
                      final app = _applicants[index];
                      final profile = app['profile'];
                      final user = profile?['user'];
                      final cvDoc = app['cv_document'];
                      final skills = (profile?['skills'] as List?) ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                      user?['name'] ?? 'Candidate',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  StatusBadge(status: app['status'] ?? 'submitted'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      final email = user?['email'];
                                      if (email != null && email.toString().isNotEmpty) {
                                        launchUrl(Uri.parse('mailto:$email'));
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.email_outlined, size: 14, color: Color(0xFF0D6B4F)),
                                        const SizedBox(width: 4),
                                        Text(
                                          user?['email'] ?? "",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF0D6B4F)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () {
                                      final phone = user?['phone'];
                                      if (phone != null && phone.toString().isNotEmpty) {
                                        launchUrl(Uri.parse('tel:$phone'));
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF0D6B4F)),
                                        const SizedBox(width: 4),
                                        Text(
                                          user?['phone'] ?? "No phone",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF0D6B4F)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Education: ${profile?['education_level'] ?? "Not specified"} (${profile?['field_of_study'] ?? ""})',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                              ),
                              Text(
                                'Experience: ${profile?['experience_years'] ?? 0} years',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                              ),
                              if (skills.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: skills.take(4).map((s) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 11)),
                                    );
                                  }).toList(),
                                ),
                              ],
                              if (app['cover_letter'] != null && app['cover_letter'].toString().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Cover Letter: "${app['cover_letter']}"',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                              if (app['interview_at'] != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_available, color: Color(0xFF1D4ED8), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Interview: ${(app['interview_at'] ?? "").toString().split('T').first} (${app['interview_type'] ?? "Meeting"})\nLocation: ${app['interview_location'] ?? "TBD"}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Divider(),
                              Row(
                                children: [
                                  if (cvDoc != null)
                                    OutlinedButton.icon(
                                      onPressed: () => _viewCvDocument(cvDoc),
                                      icon: const Icon(Icons.description, size: 15, color: Color(0xFF0D6B4F)),
                                      label: Text(
                                        'View CV (${cvDoc['original_name'] ?? 'PDF'})',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF0D6B4F)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF0D6B4F)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    )
                                  else
                                    const Text('No CV Document Attached', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.video_call_outlined, color: Color(0xFF0D6B4F)),
                                    tooltip: 'Schedule Interview',
                                    onPressed: () => _showScheduleInterviewDialog(app),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _showStatusDialog(app),
                                    icon: const Icon(Icons.edit, size: 15),
                                    label: Text(loc.t('update_status'), style: const TextStyle(fontSize: 12)),
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
}
