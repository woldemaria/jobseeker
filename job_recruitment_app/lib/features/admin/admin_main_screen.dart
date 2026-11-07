import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/advertisement_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../authentication/login_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';
import 'admin_verifications_screen.dart';
import 'advertisement_management_screen.dart';
import 'advertisement_analytics_screen.dart';

class AdminMainScreen extends StatefulWidget {
  final AdminRepository adminRepo;
  final AdvertisementRepository adRepo;
  final AuthService authService;

  const AdminMainScreen({
    super.key,
    required this.adminRepo,
    required this.adRepo,
    required this.authService,
  });

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({bool isRefresh = false}) async {
    if (!isRefresh && _stats == null) {
      setState(() => _isLoadingStats = true);
    }
    try {
      final data = await widget.adminRepo.getStatistics();
      if (mounted) {
        setState(() {
          _stats = data;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Admin'),
        content: const Text('Are you sure you want to log out from administrator session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.authService.logout();
      if (mounted) {
        final jobRepo = Provider.of<JobRepository>(context, listen: false);
        final appRepo = Provider.of<ApplicationRepository>(context, listen: false);
        final profRepo = Provider.of<ProfileRepository>(context, listen: false);
        final apiService = Provider.of<ApiService>(context, listen: false);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              authService: widget.authService,
              jobRepo: jobRepo,
              appRepo: appRepo,
              profRepo: profRepo,
              apiService: apiService,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  Widget _buildOverviewTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalUsers = _stats?['total_users'] ?? 0;
    final activeJobSeekers = _stats?['active_job_seekers'] ?? 0;
    final totalEmployers = _stats?['total_employers'] ?? 0;
    final pendingVerifications = _stats?['pending_verifications'] ?? 0;
    final totalJobs = _stats?['total_jobs'] ?? 0;
    final publishedJobs = _stats?['published_jobs'] ?? 0;
    final totalApplications = _stats?['total_applications'] ?? 0;
    final pendingReports = _stats?['pending_reports'] ?? 0;

    return RefreshIndicator(
      onRefresh: () => _loadStats(isRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF0D6B4F),
                  child: Icon(Icons.admin_panel_settings, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Administrator Portal',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'System Operations, Moderation & Advertising Control',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'System Activity & KPIs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // KPI Grid
          Row(
            children: [
              Expanded(child: _kpiCard('Total Users', '$totalUsers', Icons.people_outline, Colors.blue, onTap: () => setState(() => _currentIndex = 1))),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Job Seekers', '$activeJobSeekers', Icons.person_search, Colors.teal, onTap: () => setState(() => _currentIndex = 1))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiCard('Employers', '$totalEmployers', Icons.business_outlined, Colors.indigo, onTap: () => setState(() => _currentIndex = 2))),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Pending Verifications', '$pendingVerifications', Icons.verified_user_outlined, Colors.amber.shade900, onTap: () => setState(() => _currentIndex = 2))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiCard('Total Vacancies', '$totalJobs', Icons.work_outline, Colors.purple, onTap: () => setState(() => _currentIndex = 3))),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Published Live', '$publishedJobs', Icons.check_circle_outline, Colors.green, onTap: () => setState(() => _currentIndex = 3))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiCard('Total Applications', '$totalApplications', Icons.assignment_outlined, Colors.cyan.shade700, onTap: () => setState(() => _currentIndex = 4))),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('Pending Reports', '$pendingReports', Icons.report_problem_outlined, Colors.red, onTap: () => setState(() => _currentIndex = 4))),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Navigation Actions
          const Text(
            'Quick Operations',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE0F2FE),
              child: Icon(Icons.people, color: Colors.blue),
            ),
            title: const Text('Manage User Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('View roles, activate, or suspend accounts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _currentIndex = 1),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFEF3C7),
              child: Icon(Icons.verified, color: Colors.amber),
            ),
            title: const Text('Review Employer Verifications', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Verify business licenses and TIN registration'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _currentIndex = 2),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.campaign, color: Colors.green),
            ),
            title: const Text('Advertisement Campaigns & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Manage banners, schedule dates, and monitor CTR'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _currentIndex = 3),
          ),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFEE2E2),
              child: Icon(Icons.analytics, color: Colors.red),
            ),
            title: const Text('View Detailed Advertising Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('CTR breakdown by category and placement'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvertisementAnalyticsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildOverviewTab(),
      AdminUsersScreen(adminRepo: widget.adminRepo),
      AdminVerificationsScreen(adminRepo: widget.adminRepo),
      const AdvertisementManagementScreen(),
      AdminReportsScreen(adminRepo: widget.adminRepo),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified), label: 'Verify'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Ads'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Reports'),
        ],
      ),
    );
  }
}
