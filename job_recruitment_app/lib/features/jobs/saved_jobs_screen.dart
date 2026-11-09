import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/job_card.dart';
import '../applications/apply_job_sheet.dart';
import 'job_details_screen.dart';

class SavedJobsScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;

  const SavedJobsScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
  });

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<JobModel> _savedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSaved();
    });
  }

  Future<void> _loadSaved() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await widget.jobRepo.getSavedJobs();
      if (mounted) {
        setState(() {
          _savedJobs = results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleApply(JobModel job) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in or create an account to apply.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    ApplyJobSheet.show(
      context,
      job,
      widget.appRepo,
      widget.profRepo,
      () => _loadSaved(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('saved_jobs')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSaved),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedJobs.isEmpty
          ? EmptyStateWidget(
              icon: Icons.bookmark_border,
              title: 'No Saved Vacancies',
              subtitle: 'Save vacancies you are interested in to review and apply later.',
            )
          : RefreshIndicator(
              onRefresh: _loadSaved,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _savedJobs.length,
                itemBuilder: (context, index) {
                  final job = _savedJobs[index];
                  return JobCard(
                    job: job,
                    onApply: () => _handleApply(job),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(
                            jobId: job.id,
                            jobRepo: widget.jobRepo,
                            appRepo: widget.appRepo,
                            profRepo: widget.profRepo,
                          ),
                        ),
                      ).then((_) => _loadSaved());
                    },
                    onSaveToggle: () async {
                      setState(() {
                        _savedJobs.removeWhere((j) => j.id == job.id);
                      });
                      await widget.jobRepo.unsaveJob(job.id);
                    },
                  );
                },
              ),
            ),
    );
  }
}
