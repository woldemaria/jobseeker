import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/job_card.dart';
import '../../shared/widgets/advertisement_banner_carousel.dart';
import '../../shared/widgets/ad_consent_banner.dart';
import '../matching/match_detail_dialog.dart';
import '../jobs/job_details_screen.dart';
import '../jobs/saved_jobs_screen.dart';
import '../jobs/job_search_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../profile/skills_management_screen.dart';
import '../../data/ethiopian_job_titles_data.dart';
import '../../shared/utils/avatar_helper.dart';

class JobSeekerDashboardScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final AuthService authService;
  final Function(int) onTabChange;

  const JobSeekerDashboardScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.authService,
    required this.onTabChange,
  });

  @override
  State<JobSeekerDashboardScreen> createState() => _JobSeekerDashboardScreenState();
}

class _JobSeekerDashboardScreenState extends State<JobSeekerDashboardScreen> {
  final TextEditingController _dashboardSearchController = TextEditingController();
  List<JobModel> _recommendations = [];
  List<JobModel> _recentJobs = [];
  List<String> _quickSuggestions = [];
  int _applicationsCount = 0;
  int _savedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dashboardSearchController.addListener(_onSearchInputChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _dashboardSearchController.removeListener(_onSearchInputChanged);
    _dashboardSearchController.dispose();
    super.dispose();
  }

  void _onSearchInputChanged() {
    final text = _dashboardSearchController.text.trim();
    if (text.length >= 2) {
      final suggestions = EthiopianJobCatalogue.searchTitles(text, limit: 6);
      setState(() => _quickSuggestions = suggestions);
    } else {
      if (_quickSuggestions.isNotEmpty) {
        setState(() => _quickSuggestions = []);
      }
    }
  }

  void _submitSearch(String query) {
    final text = query.trim();
    if (_quickSuggestions.isNotEmpty) {
      setState(() => _quickSuggestions = []);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobSearchScreen(
          jobRepo: widget.jobRepo,
          appRepo: widget.appRepo,
          profRepo: widget.profRepo,
          initialKeyword: text.isNotEmpty ? text : null,
        ),
      ),
    ).then((_) => _loadDashboardData(silent: true));
  }

  Future<void> _loadDashboardData({bool silent = false, bool isRefresh = false}) async {
    if (!silent && !isRefresh && _recentJobs.isEmpty && _recommendations.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final recsFuture = widget.jobRepo.getRecommendations(limit: 5);
      final jobsFuture = widget.jobRepo.getJobs();
      final appsFuture = widget.appRepo.getMyApplications();
      final savedFuture = widget.jobRepo.getSavedJobs();

      final results = await Future.wait([recsFuture, jobsFuture, appsFuture, savedFuture]);

      if (mounted) {
        setState(() {
          _recommendations = results[0] as List<JobModel>;
          _recentJobs = (results[1] as List<JobModel>).take(6).toList();
          _applicationsCount = (results[2] as List).length;
          _savedCount = (results[3] as List).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSalaryBenchmarksModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.jobRepo.getSalaryBenchmarks(),
        builder: (context, snapshot) {
          final benchmarks = snapshot.data ?? [];
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.payments_outlined, color: Color(0xFF0D6B4F)),
                      SizedBox(width: 8),
                      Text('Ethiopian Salary Benchmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Market salary transparency across major Ethiopian sectors (in ETB/month):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Divider(height: 24),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : benchmarks.isEmpty
                            ? const Center(child: Text('No salary benchmark records found.'))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: benchmarks.length,
                                itemBuilder: (context, index) {
                                  final b = benchmarks[index];
                                  final median = b['median_etb'] ?? b['median'] ?? 0;
                                  final p25 = b['p25_etb'] ?? b['p25'] ?? 0;
                                  final p75 = b['p75_etb'] ?? b['p75'] ?? 0;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(b['role'] ?? 'Role', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const SizedBox(height: 4),
                                          Text(b['category'] ?? 'Category', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('25th Percentile', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  Text('$p25 ETB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  const Text('Median Salary', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F))),
                                                  Text('$median ETB', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F))),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  const Text('75th Percentile', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  Text('$p75 ETB', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showHyperlocalRadarModal() async {
    String selectedSubCity = 'Bole';
    final subCities = ['Bole', 'Kirkos', 'Yeka', 'Arada', 'Lideta', 'Nifas Silk', 'Akaki Kality', 'Hawassa', 'Bahir Dar', 'Adama'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => FutureBuilder<Map<String, dynamic>?>(
          future: widget.jobRepo.getHyperlocalRadar(subCity: selectedSubCity, radiusKm: 15.0),
          builder: (context, snapshot) {
            final radarData = snapshot.data;
            final nearbyJobs = (radarData?['nearby_jobs'] as List?) ?? [];
            final loading = snapshot.connectionState == ConnectionState.waiting;

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.radar, color: Color(0xFF0D6B4F)),
                            SizedBox(width: 8),
                            Text('Hyperlocal Job Radar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                          child: Text('${nearbyJobs.length} nearby', style: const TextStyle(color: Color(0xFF0D6B4F), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Discover vacancies within your subcity to minimize commute time & transport cost:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: subCities.map((sub) {
                          final isSelected = sub == selectedSubCity;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(sub, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0D6B4F),
                              checkmarkColor: Colors.white,
                              onSelected: (val) {
                                if (val) setModalState(() => selectedSubCity = sub);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : nearbyJobs.isEmpty
                              ? Center(child: Text('No active vacancies within $selectedSubCity radius.'))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: nearbyJobs.length,
                                  itemBuilder: (context, index) {
                                    final job = nearbyJobs[index];
                                    final dist = job['distance_km'] ?? 0.0;
                                    final estCost = job['commute_cost_etb'] ?? 15;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        title: Text(job['title'] ?? 'Job Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        subtitle: Text('${job['employer_name'] ?? "Employer"} • ${job['location']}\nMinibus commute: ~$estCost ETB', style: const TextStyle(fontSize: 11)),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('${dist.toStringAsFixed(1)} KM', style: const TextStyle(color: Color(0xFF0D6B4F), fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 2),
                                            const Text('Nearby', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => JobDetailsScreen(
                                                jobId: job['id'] as int,
                                                jobRepo: widget.jobRepo,
                                                appRepo: widget.appRepo,
                                                profRepo: widget.profRepo,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.t('app_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(profRepo: widget.profRepo),
                ),
              ).then((_) => _loadDashboardData(silent: true));
            },
          ),
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Friends & Community Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatGroupsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Saved Jobs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SavedJobsScreen(
                    jobRepo: widget.jobRepo,
                    appRepo: widget.appRepo,
                    profRepo: widget.profRepo,
                  ),
                ),
              ).then((_) => _loadDashboardData(silent: true));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadDashboardData(isRefresh: true),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  // Advertising & Cookie Consent Banner
                  Builder(
                    builder: (ctx) {
                      final storage = Provider.of<StorageService>(ctx, listen: false);
                      return AdConsentBanner(storageService: storage);
                    },
                  ),

                  // Greeting Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D6B4F), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D6B4F).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
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
                                    '${loc.t('welcome')}, ${user?.name ?? "Job Seeker"}!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    loc.t('welcome_subtitle'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final avatarProvider = getAvatarImageProvider(user?.profilePhoto);
                                return InkWell(
                                  onTap: () => widget.onTabChange(4),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Tooltip(
                                    message: 'View Profile',
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white.withOpacity(0.25),
                                      backgroundImage: avatarProvider,
                                      child: avatarProvider == null
                                          ? Text(
                                              (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildStatItem(loc.t('applications'), '$_applicationsCount', () => widget.onTabChange(3)),
                            const SizedBox(width: 16),
                            _buildStatItem(loc.t('saved_jobs'), '$_savedCount', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SavedJobsScreen(
                                    jobRepo: widget.jobRepo,
                                    appRepo: widget.appRepo,
                                    profRepo: widget.profRepo,
                                  ),
                                ),
                              ).then((_) => _loadDashboardData(silent: true));
                            }),
                            const SizedBox(width: 16),
                            _buildStatItem(loc.t('recommendations'), '${_recommendations.length}', () => widget.onTabChange(2)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hero Search Bar for Instant Job & Career Discovery
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _dashboardSearchController,
                            decoration: InputDecoration(
                              hintText: 'Search jobs, 475+ Ethiopian careers, companies...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              suffixIcon: _dashboardSearchController.text.isNotEmpty
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _dashboardSearchController.clear();
                                            setState(() => _quickSuggestions = []);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.arrow_forward, color: Color(0xFF0D6B4F)),
                                          onPressed: () => _submitSearch(_dashboardSearchController.text),
                                        ),
                                      ],
                                    )
                                  : Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      child: ElevatedButton(
                                        onPressed: () => _submitSearch(_dashboardSearchController.text),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D6B4F),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 0,
                                        ),
                                        child: const Text('Search', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF0D6B4F), width: 1.5),
                              ),
                            ),
                            onSubmitted: _submitSearch,
                          ),
                        ),
                        if (_quickSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _quickSuggestions.map((suggestion) {
                                return ActionChip(
                                  label: Text(suggestion, style: const TextStyle(fontSize: 11.5)),
                                  avatar: const Icon(Icons.work_outline, size: 14, color: Color(0xFF0D6B4F)),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  side: BorderSide.none,
                                  onPressed: () {
                                    _dashboardSearchController.text = suggestion;
                                    _submitSearch(suggestion);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Shortcuts
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => widget.onTabChange(2), // Recommendations
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: Text(loc.t('recommendations'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D6B4F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onTabChange(1), // All Categories / Search
                            icon: const Icon(Icons.category_outlined, size: 18),
                            label: const Text('475 Careers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0D6B4F),
                              side: const BorderSide(color: Color(0xFF0D6B4F)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showHyperlocalRadarModal,
                            icon: const Icon(Icons.radar, size: 16, color: Color(0xFF0D6B4F)),
                            label: const Text('Local Radar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0D6B4F)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showSalaryBenchmarksModal,
                            icon: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF0D6B4F)),
                            label: const Text('Salary Benchmarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0D6B4F)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Promotional Hero Banner Carousel
                  AdvertisementBannerCarousel(
                    placement: 'hero',
                    layoutType: BannerLayoutType.hero,
                    onNavigateTab: widget.onTabChange,
                  ),
                  const SizedBox(height: 24),

                  // Ethiopian Industry & Careers Carousel
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ethiopian Industries (475 Careers)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        TextButton(
                          onPressed: () => widget.onTabChange(1),
                          child: const Text('All Categories'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 115,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: EthiopianJobCatalogue.categories.length,
                      itemBuilder: (context, idx) {
                        final cat = EthiopianJobCatalogue.categories[idx];
                        return Container(
                          width: 140,
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobSearchScreen(
                                    jobRepo: widget.jobRepo,
                                    appRepo: widget.appRepo,
                                    profRepo: widget.profRepo,
                                    initialCategory: cat.name,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF0D6B4F).withOpacity(0.12),
                                    child: Icon(cat.icon, color: const Color(0xFF0D6B4F), size: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cat.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cat.titles.length} Standard Titles',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Top Recommendations Section
                  if (_recommendations.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.t('recommendations'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () => widget.onTabChange(2),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                    ..._recommendations.map((job) {
                      return JobCard(
                        job: job,
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
                          ).then((_) => _loadDashboardData(silent: true));
                        },
                        onSaveToggle: () async {
                          final newSaved = !job.isSaved;
                          setState(() {
                            final idx = _recommendations.indexWhere((j) => j.id == job.id);
                            if (idx != -1) {
                              _recommendations[idx] = job.copyWith(isSaved: newSaved);
                            }
                            _savedCount = newSaved ? _savedCount + 1 : (_savedCount > 0 ? _savedCount - 1 : 0);
                          });
                          if (newSaved) {
                            await widget.jobRepo.saveJob(job.id);
                          } else {
                            await widget.jobRepo.unsaveJob(job.id);
                          }
                          _loadDashboardData(silent: true);
                        },
                        onMatchTap: () async {
                          if (job.matchDetails != null) {
                            MatchDetailDialog.show(
                              context,
                              job.title,
                              job.matchDetails!,
                            );
                          } else {
                            final details = await widget.jobRepo.getMatchDetails(job.id);
                            if (details != null && mounted) {
                              MatchDetailDialog.show(
                                context,
                                job.title,
                                details,
                              );
                            }
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D6B4F).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome, color: Color(0xFF0D6B4F), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Personalized AI Match Recommendations',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF14532D)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add your verified skills and education to unlock multi-criteria match scoring.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SkillsManagementScreen(profRepo: widget.profRepo),
                                      ),
                                    ).then((_) => _loadDashboardData(silent: true));
                                  },
                                  icon: const Icon(Icons.add_task, size: 14),
                                  label: const Text('Add Skills to Match Jobs', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D6B4F),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Smart Dashboard Promotion Banner
                  AdvertisementBannerCarousel(
                    placement: 'dashboard',
                    layoutType: BannerLayoutType.compact,
                    height: 140,
                    onNavigateTab: widget.onTabChange,
                  ),
                  const SizedBox(height: 20),

                  // Recent Vacancies
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Vacancies',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => widget.onTabChange(1),
                          child: const Text('Browse All'),
                        ),
                      ],
                    ),
                  ),
                  if (_recentJobs.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.work_outline, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          const Text(
                            'No vacancies posted yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check back soon or explore 475+ career categories across Ethiopia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => widget.onTabChange(1),
                            icon: const Icon(Icons.explore_outlined, size: 16),
                            label: const Text('Browse All Categories'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D6B4F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._recentJobs.map((job) {
                      return JobCard(
                        job: job,
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
                          ).then((_) => _loadDashboardData(silent: true));
                        },
                        onSaveToggle: () async {
                          final newSaved = !job.isSaved;
                          setState(() {
                            final idx = _recentJobs.indexWhere((j) => j.id == job.id);
                            if (idx != -1) {
                              _recentJobs[idx] = job.copyWith(isSaved: newSaved);
                            }
                            _savedCount = newSaved ? _savedCount + 1 : (_savedCount > 0 ? _savedCount - 1 : 0);
                          });
                          if (newSaved) {
                            await widget.jobRepo.saveJob(job.id);
                          } else {
                            await widget.jobRepo.unsaveJob(job.id);
                          }
                          _loadDashboardData(silent: true);
                        },
                        onMatchTap: () async {
                          if (job.matchDetails != null) {
                            MatchDetailDialog.show(
                              context,
                              job.title,
                              job.matchDetails!,
                            );
                          } else {
                            final details = await widget.jobRepo.getMatchDetails(job.id);
                            if (details != null && mounted) {
                              MatchDetailDialog.show(
                                context,
                                job.title,
                                details,
                              );
                            }
                          }
                        },
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
