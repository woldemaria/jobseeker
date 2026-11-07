import 'package:flutter/material.dart';
import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/advertisement_banner_carousel.dart';
import '../authentication/login_screen.dart';
import 'employer_verification_screen.dart';
import 'job_applicants_screen.dart';
import '../jobs/job_details_screen.dart';
import '../admin/advertisement_management_screen.dart';

class EmployerDashboardScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final ApiService apiService;
  final AuthService authService;
  final Function(int) onTabChange;

  const EmployerDashboardScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.apiService,
    required this.authService,
    required this.onTabChange,
  });

  @override
  State<EmployerDashboardScreen> createState() => _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen> {
  List<JobModel> _jobs = [];
  Map<String, dynamic>? _employerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (!isRefresh && _jobs.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final jobs = await widget.jobRepo.getEmployerJobs();
      final profileResp = await widget.apiService.get('/employers/profile');

      if (mounted) {
        setState(() {
          _jobs = jobs;
          _employerData = profileResp.success ? profileResp.data : null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await widget.authService.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          jobRepo: widget.jobRepo,
          appRepo: widget.appRepo,
          profRepo: widget.profRepo,
          apiService: widget.apiService,
        ),
      ),
      (route) => false,
    );
  }

  void _showLanguageDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: const Icon(Icons.language),
              trailing: widget.authService.currentLocale.languageCode == 'en'
                  ? const Icon(Icons.check, color: Color(0xFF0D6B4F))
                  : null,
              onTap: () {
                widget.authService.setLanguage('en');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('አማርኛ (Amharic)'),
              leading: const Icon(Icons.language),
              trailing: widget.authService.currentLocale.languageCode == 'am'
                  ? const Icon(Icons.check, color: Color(0xFF0D6B4F))
                  : null,
              onTap: () {
                widget.authService.setLanguage('am');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final orgName = _employerData?['organization_name'] ?? 'Employer Organization';
    final verificationStatus = _employerData?['verification_status'] ?? 'pending';
    final totalApplicants = _jobs.fold<int>(0, (sum, j) => sum + (j.applicantsCount ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('employer_dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Advertising Campaigns',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvertisementManagementScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showLanguageDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(isRefresh: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Org banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      orgName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
                                    tooltip: 'Edit Organization Profile',
                                    onPressed: () => widget.onTabChange(3),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(left: 6),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmployerVerificationScreen(
                                      apiService: widget.apiService,
                                    ),
                                  ),
                                ).then((_) => _load());
                              },
                              child: StatusBadge(status: verificationStatus),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _employerData?['email'] ?? 'Verified Recruitment Account',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatCard('Active Jobs', '${_jobs.length}', onTap: () => widget.onTabChange(1)),
                            const SizedBox(width: 12),
                            _buildStatCard('Applicants', '$totalApplicants', onTap: () => widget.onTabChange(1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => widget.onTabChange(2), // Post Job
                          icon: const Icon(Icons.add),
                          label: Text(loc.t('create_job')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onTabChange(1), // Manage
                          icon: const Icon(Icons.list_alt),
                          label: Text(loc.t('manage_jobs')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdvertisementManagementScreen()),
                        );
                      },
                      icon: const Icon(Icons.campaign, color: Color(0xFF0D6B4F)),
                      label: const Text(
                        'Promotional Campaigns & Sponsored Ads',
                        style: TextStyle(color: Color(0xFF0D6B4F), fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF0D6B4F)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Promotional Campaigns Banner
                  const AdvertisementBannerCarousel(
                    placement: 'dashboard',
                    layoutType: BannerLayoutType.hero,
                    height: 180,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Vacancies',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => widget.onTabChange(1),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  if (_jobs.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.work_outline, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No vacancies posted yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Post your first vacancy to start receiving verified candidate applications across Ethiopia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => widget.onTabChange(2),
                            icon: const Icon(Icons.add),
                            label: const Text('Post Your First Vacancy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D6B4F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._jobs.take(5).map((job) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${job.location} • ${job.employmentType}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge(status: job.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${job.salaryText} • ${job.applicantsCount ?? 0} applied',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D6B4F)),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
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
                                          ).then((_) => _load(isRefresh: true));
                                        },
                                        icon: const Icon(Icons.people_outline, size: 14),
                                        label: Text('Applicants (${job.applicantsCount ?? 0})', style: const TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
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
                                          ).then((_) => _load(isRefresh: true));
                                        },
                                        icon: const Icon(Icons.visibility_outlined, size: 14),
                                        label: const Text('View', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D6B4F),
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
