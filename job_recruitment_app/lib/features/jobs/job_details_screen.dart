import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/map_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/match_score_badge.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/location_map_modal.dart';
import '../../shared/widgets/share_with_friends_modal.dart';
import '../matching/match_detail_dialog.dart';
import '../applications/apply_job_sheet.dart';
import '../applications/my_applications_screen.dart';
import '../authentication/login_screen.dart';
import '../employer/create_job_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final int jobId;
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;

  const JobDetailsScreen({
    super.key,
    required this.jobId,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  JobModel? _job;
  Map<String, dynamic>? _matchAnalysis;
  List<JobModel> _similarJobs = [];
  MapLocationResult? _mapLocation;
  PlaceProfile? _placeProfile;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    setState(() => _isLoading = true);
    final job = await widget.jobRepo.getJobDetails(widget.jobId);
    Map<String, dynamic>? match;
    try {
      match = await widget.jobRepo.getMatchDetails(widget.jobId);
    } catch (_) {}

    MapLocationResult? locResult;
    PlaceProfile? placeProf;
    if (job != null) {
      locResult = job.latitude != null && job.longitude != null
          ? MapLocationResult(latitude: job.latitude!, longitude: job.longitude!, displayName: job.location)
          : await MapService.geocode(job.location, organizationName: job.employer?.organizationName);
      placeProf = await MapService.getPlaceProfile(job.location, organizationName: job.employer?.organizationName);
    }

    List<JobModel> similar = [];
    if (job != null) {
      try {
        final results = await widget.jobRepo.getJobs(location: job.location);
        similar = results.where((j) => j.id != job.id).take(3).toList();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _job = job;
        _matchAnalysis = match;
        _mapLocation = locResult;
        _placeProfile = placeProf;
        _similarJobs = similar;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_job == null || _isSaving) return;
    setState(() => _isSaving = true);
    final success = _job!.isSaved
        ? await widget.jobRepo.unsaveJob(_job!.id)
        : await widget.jobRepo.saveJob(_job!.id);

    if (mounted && success) {
      setState(() {
        _job = JobModel(
          id: _job!.id,
          employerId: _job!.employerId,
          category: _job!.category,
          categoryId: _job!.categoryId,
          jobTitleId: _job!.jobTitleId,
          title: _job!.title,
          description: _job!.description,
          responsibilities: _job!.responsibilities,
          requirements: _job!.requirements,
          location: _job!.location,
          latitude: _job!.latitude,
          longitude: _job!.longitude,
          employmentType: _job!.employmentType,
          experienceRequired: _job!.experienceRequired,
          salaryMin: _job!.salaryMin,
          salaryMax: _job!.salaryMax,
          currency: _job!.currency,
          deadline: _job!.deadline,
          status: _job!.status,
          publishedAt: _job!.publishedAt,
          employer: _job!.employer,
          skills: _job!.skills,
          isSaved: !_job!.isSaved,
          hasApplied: _job!.hasApplied,
          applicationStatus: _job!.applicationStatus,
          matchScore: _job!.matchScore,
          matchDetails: _job!.matchDetails,
          applicantsCount: _job!.applicantsCount,
        );
        _isSaving = false;
      });
    } else if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _editVacancyFromDetails() {
    if (_job == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateJobScreen(
          jobRepo: widget.jobRepo,
          profRepo: widget.profRepo,
          initialJob: _job,
          onSuccess: _loadJob,
        ),
      ),
    ).then((_) {
      _loadJob();
    });
  }

  Future<void> _deleteVacancyFromDetails() async {
    if (_job == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vacancy'),
        content: Text('Are you sure you want to delete / archive "${_job!.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final resp = await widget.jobRepo.archiveJob(_job!.id);
      if (mounted) {
        if (resp.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vacancy deleted successfully.'),
              backgroundColor: Color(0xFF0D6B4F),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp.message.isNotEmpty ? resp.message : 'Failed to delete vacancy.')),
          );
        }
      }
    }
  }

  int _calculateDaysRemaining(String deadline) {
    try {
      final d = DateTime.parse(deadline);
      final today = DateTime.now();
      return DateTime(d.year, d.month, d.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
    } catch (_) {
      return 0;
    }
  }

  String _getOsmTileUrl(double lat, double lon, int zoom) {
    final n = pow(2, zoom).toInt();
    final x = (((lon + 180) / 360) * n).floor();
    final latRad = lat * pi / 180;
    final y = (((1 - (log(tan(latRad) + (1 / cos(latRad))) / pi)) / 2) * n).floor();
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  void _showShareDialog() {
    if (_job == null) return;
    ShareWithFriendsModal.show(context, _job!);
  }

  void _showReportDialog() {
    if (_job == null) return;
    String selectedReason = 'Fraudulent / Scam Listing';
    final descController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Report Vacancy', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Help us keep the recruitment platform secure by reporting suspicious activity:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(labelText: 'Reason for Report'),
                  items: const [
                    DropdownMenuItem(value: 'Fraudulent / Scam Listing', child: Text('Fraudulent / Scam Listing')),
                    DropdownMenuItem(value: 'Inaccurate Salary or Details', child: Text('Inaccurate Salary or Details')),
                    DropdownMenuItem(value: 'Expired or Closed Vacancy', child: Text('Expired or Closed Vacancy')),
                    DropdownMenuItem(value: 'Discriminatory Requirements', child: Text('Discriminatory Requirements')),
                    DropdownMenuItem(value: 'Other Policy Violation', child: Text('Other Policy Violation')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedReason = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional Details (Optional)',
                    hintText: 'Describe the issue...',
                  ),
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final resp = await widget.jobRepo.reportJob(
                        _job!.id,
                        selectedReason,
                        descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                      );
                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(resp.success ? 'Report submitted for administrator review.' : resp.message),
                            backgroundColor: resp.success ? const Color(0xFF0D6B4F) : Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleApplyNow() {
    if (_job == null) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Authentication Required'),
          content: const Text('Please sign in or create an account to apply for this vacancy.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final api = Provider.of<ApiService>(context, listen: false);
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      authService: auth,
                      jobRepo: widget.jobRepo,
                      appRepo: widget.appRepo,
                      profRepo: widget.profRepo,
                      apiService: api,
                    ),
                  ),
                );
                if (mounted) {
                  _loadJob();
                }
              },
              child: const Text('Sign In / Register'),
            ),
          ],
        ),
      );
      return;
    }

    ApplyJobSheet.show(
      context,
      _job!,
      widget.appRepo,
      widget.profRepo,
      _loadJob,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('jobs'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_job == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.t('jobs'))),
        body: const Center(child: Text('Vacancy not found.')),
      );
    }

    final double? matchScore = _matchAnalysis != null
        ? double.tryParse(_matchAnalysis!['match_score'].toString())
        : _job!.matchScore;

    final daysRemaining = _calculateDaysRemaining(_job!.deadline);
    final double? lat = _mapLocation?.latitude;
    final double? lon = _mapLocation?.longitude;

    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final bool isJobOwner = currentUser != null && (
      currentUser.isAdmin ||
      (currentUser.isEmployer && currentUser.employers != null && currentUser.employers!.any((e) => e.id == _job!.employerId))
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_job!.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Vacancy',
            onPressed: _showShareDialog,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on OpenStreetMap / Google Maps',
            onPressed: () {
              LocationMapModal.show(
                context,
                title: _job!.title,
                address: _job!.location,
                organizationName: _job!.employer?.organizationName,
                latitude: _job!.latitude,
                longitude: _job!.longitude,
              );
            },
          ),
          IconButton(
            icon: Icon(
              _job!.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: _job!.isSaved ? const Color(0xFF0D6B4F) : null,
            ),
            onPressed: _toggleSave,
          ),
          PopupMenuButton<String>(
            tooltip: 'More Options',
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'share') _showShareDialog();
              if (val == 'save') _toggleSave();
              if (val == 'map') {
                LocationMapModal.show(
                  context,
                  title: _job!.title,
                  address: _job!.location,
                  organizationName: _job!.employer?.organizationName,
                  latitude: _job!.latitude,
                  longitude: _job!.longitude,
                );
              }
              if (val == 'report') _showReportDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18, color: Color(0xFF0D6B4F)),
                    SizedBox(width: 8),
                    Text('Share Vacancy'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(
                      _job!.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: const Color(0xFF0D6B4F),
                    ),
                    const SizedBox(width: 8),
                    Text(_job!.isSaved ? 'Remove from Saved' : 'Save / Bookmark Job'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'map',
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 18, color: Color(0xFF0D6B4F)),
                    SizedBox(width: 8),
                    Text('View Location Map'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 8),
                    Text('Report Vacancy', style: TextStyle(color: Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: _job!.hasApplied
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF0D6B4F), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${loc.t('applied')}:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (_job!.applicationStatus != null)
                            StatusBadge(status: _job!.applicationStatus!),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyApplicationsScreen(appRepo: widget.appRepo),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_outlined, size: 16),
                      label: const Text('My Applications'),
                    ),
                  ],
                )
              : isJobOwner
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _deleteVacancyFromDetails,
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                            label: const Text('Delete Vacancy', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _editVacancyFromDetails,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Vacancy Details', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D6B4F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    )
                  : (_job!.status != 'published' || daysRemaining < 0)
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_clock, color: Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Text(
                                daysRemaining < 0
                                    ? 'Application Deadline Has Passed'
                                    : 'Vacancy is ${_job!.status.toUpperCase()} (Not accepting applications)',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleApplyNow,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              loc.t('apply_now'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D6B4F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                          ),
                        ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Deadline Countdown Urgency Banner
          _buildDeadlineBanner(daysRemaining),
          const SizedBox(height: 12),

          // Header Card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _job!.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (matchScore != null)
                        MatchScoreBadge(
                          score: matchScore,
                          onTap: _matchAnalysis != null
                              ? () => MatchDetailDialog.show(
                                    context,
                                    _job!.title,
                                    _matchAnalysis!,
                                  )
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: Color(0xFF0D6B4F)),
                      const SizedBox(width: 6),
                      Text(
                        _job!.employer?.organizationName ?? 'Enterprise Organization',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 16, color: Color(0xFF0D6B4F)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.location_on,
                        '${_job!.location} (Map)',
                        color: const Color(0xFF0D6B4F).withOpacity(0.08),
                        iconColor: const Color(0xFF0D6B4F),
                        textColor: const Color(0xFF0D6B4F),
                        onTap: () {
                          LocationMapModal.show(
                            context,
                            title: _job!.title,
                            address: _job!.location,
                            organizationName: _job!.employer?.organizationName,
                            latitude: _job!.latitude,
                            longitude: _job!.longitude,
                          );
                        },
                      ),
                      _buildInfoChip(Icons.work_outline, _job!.employmentType),
                      _buildInfoChip(Icons.payments_outlined, _job!.salaryText),
                      _buildInfoChip(
                        Icons.event_outlined,
                        'Deadline: ${_job!.deadline}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Workplace & Directions OpenStreetMap Mini-Card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map, color: Color(0xFF0D6B4F), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Workplace Location & Directions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          LocationMapModal.show(
                            context,
                            title: _job!.title,
                            address: _job!.location,
                            organizationName: _job!.employer?.organizationName,
                            latitude: _job!.latitude,
                            longitude: _job!.longitude,
                          );
                        },
                        icon: const Icon(Icons.open_in_full, size: 14),
                        label: const Text('Open Map', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_placeProfile?.imageUrl != null) ...[
                    Container(
                      height: 110,
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF0F172A),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              _placeProfile!.imageUrl!,
                              fit: BoxFit.cover,
                              headers: const {'User-Agent': 'JobSeekerEthiopiaRecruitmentApp/1.0'},
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF1E293B),
                                child: const Center(child: Icon(Icons.image, color: Colors.white54)),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.photo_camera, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Place Profile Image',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 10,
                            right: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _placeProfile!.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (_placeProfile!.description != null)
                                  Text(
                                    _placeProfile!.description!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFE2E8F0),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: lat != null && lon != null
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  _getOsmTileUrl(lat, lon, 14),
                                  fit: BoxFit.cover,
                                  headers: const {'User-Agent': 'JobSeekerEthiopiaRecruitmentApp/1.0'},
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(child: Icon(Icons.map, color: Colors.grey)),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                                        ],
                                      ),
                                      child: Text(
                                        _job!.location,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Icon(Icons.location_pin, color: Color(0xFFDC2626), size: 30),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            MapService.openGoogleMaps(
                              _job!.location,
                              organizationName: _job!.employer?.organizationName,
                              lat: lat,
                              lon: lon,
                            );
                          },
                          icon: const Icon(Icons.public, size: 15, color: Colors.white),
                          label: const Text('Google Maps', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            MapService.openDirections(
                              _job!.location,
                              organizationName: _job!.employer?.organizationName,
                              lat: lat,
                              lon: lon,
                            );
                          },
                          icon: const Icon(Icons.directions, size: 15, color: Color(0xFF0284C7)),
                          label: const Text('Directions', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            MapService.openOpenStreetMap(_job!.location, lat: lat, lon: lon);
                          },
                          icon: const Icon(Icons.map_outlined, size: 15, color: Color(0xFF0D6B4F)),
                          label: const Text('OSM Web', style: TextStyle(fontSize: 12, color: Color(0xFF0D6B4F))),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Color(0xFF0D6B4F)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Skills Match Section
          if (_job!.skills.isNotEmpty) ...[
            Text(
              loc.t('skills_match'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _job!.skills.map((skill) {
                final isReq = skill.importance == 'required';
                return Chip(
                  avatar: Icon(
                    isReq ? Icons.check_circle_outline : Icons.star_border,
                    size: 16,
                    color: isReq ? const Color(0xFF0D6B4F) : const Color(0xFFD97706),
                  ),
                  label: Text('${skill.name} (${isReq ? "Required" : "Preferred"})'),
                  backgroundColor: isReq
                      ? const Color(0xFF0D6B4F).withOpacity(0.08)
                      : const Color(0xFFD97706).withOpacity(0.08),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Description
          Text(
            loc.t('job_description'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _job!.description,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
          ),
          const SizedBox(height: 16),

          // Responsibilities
          if (_job!.responsibilities != null && _job!.responsibilities!.isNotEmpty) ...[
            Text(
              loc.t('responsibilities'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _job!.responsibilities!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 16),
          ],

          // Requirements
          if (_job!.requirements != null && _job!.requirements!.isNotEmpty) ...[
            Text(
              loc.t('requirements'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _job!.requirements!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 20),
          ],

          // Employer Showcase Card
          if (_job!.employer != null) ...[
            Card(
              margin: EdgeInsets.zero,
              color: const Color(0xFFF8FAFC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apartment, color: Color(0xFF0D6B4F), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          _job!.employer!.organizationName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Verified Ethiopian Employer • Actively hiring on JobSeeker',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_job!.employer!.website != null && _job!.employer!.website!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton.icon(
                              onPressed: () => MapService.launchExternal(_job!.employer!.website!),
                              icon: const Icon(Icons.language, size: 14),
                              label: const Text('Website', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        if (_job!.employer!.phone != null && _job!.employer!.phone!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton.icon(
                              onPressed: () => MapService.launchExternal('tel:${_job!.employer!.phone}'),
                              icon: const Icon(Icons.phone, size: 14),
                              label: const Text('Contact', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Similar Vacancies Section
          if (_similarJobs.isNotEmpty) ...[
            const Text(
              'Similar Vacancies in this Area',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._similarJobs.map((sim) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE2E8F0),
                      child: Icon(Icons.work, color: Color(0xFF0D6B4F), size: 18),
                    ),
                    title: Text(sim.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${sim.location} • ${sim.employmentType}', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailsScreen(
                            jobId: sim.id,
                            jobRepo: widget.jobRepo,
                            appRepo: widget.appRepo,
                            profRepo: widget.profRepo,
                          ),
                        ),
                      );
                    },
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildDeadlineBanner(int daysRemaining) {
    Color bg;
    Color fg;
    IconData icon;
    String text;

    if (daysRemaining < 0) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      icon = Icons.event_busy;
      text = 'Application deadline passed on ${_job!.deadline}';
    } else if (daysRemaining <= 3) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      icon = Icons.timer;
      text = daysRemaining == 0
          ? '⏳ Closes Today! Submit your application promptly.'
          : '⏳ Urgent: Closes in $daysRemaining ${daysRemaining == 1 ? "day" : "days"} (${_job!.deadline})';
    } else if (daysRemaining <= 7) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      icon = Icons.bolt;
      text = '⚡ Closes this week ($daysRemaining days remaining)';
    } else {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF065F46);
      icon = Icons.check_circle_outline;
      text = '📅 Active recruitment: $daysRemaining days until deadline (${_job!.deadline})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text, {
    Color? color,
    Color? iconColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: onTap != null ? Border.all(color: const Color(0xFF0D6B4F).withOpacity(0.3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor ?? const Color(0xFF475569),
              fontWeight: onTap != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: chip,
      );
    }
    return chip;
  }
}
