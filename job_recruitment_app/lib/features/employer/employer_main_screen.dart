import 'package:flutter/material.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import 'employer_dashboard_screen.dart';
import 'manage_jobs_screen.dart';
import 'create_job_screen.dart';
import 'organization_profile_screen.dart';

class EmployerMainScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final ApiService apiService;
  final AuthService authService;

  const EmployerMainScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.apiService,
    required this.authService,
  });

  @override
  State<EmployerMainScreen> createState() => _EmployerMainScreenState();
}

class _EmployerMainScreenState extends State<EmployerMainScreen> {
  int _currentIndex = 0;
  final GlobalKey<ManageJobsScreenState> _manageJobsKey = GlobalKey<ManageJobsScreenState>();

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      _manageJobsKey.currentState?.loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final screens = [
      EmployerDashboardScreen(
        jobRepo: widget.jobRepo,
        appRepo: widget.appRepo,
        profRepo: widget.profRepo,
        apiService: widget.apiService,
        authService: widget.authService,
        onTabChange: _onTabChange,
      ),
      ManageJobsScreen(
        key: _manageJobsKey,
        jobRepo: widget.jobRepo,
        appRepo: widget.appRepo,
        profRepo: widget.profRepo,
      ),
      CreateJobScreen(
        jobRepo: widget.jobRepo,
        profRepo: widget.profRepo,
        onSuccess: () {
          setState(() => _currentIndex = 1);
          _manageJobsKey.currentState?.loadJobs();
        },
      ),
      OrganizationProfileScreen(
        apiService: widget.apiService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            _manageJobsKey.currentState?.loadJobs();
          }
        },
        indicatorColor: const Color(0xFF0D6B4F).withOpacity(0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF0D6B4F)),
            label: loc.t('dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt, color: Color(0xFF0D6B4F)),
            label: loc.t('manage_jobs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle, color: Color(0xFF0D6B4F)),
            label: loc.t('create_job'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.business_outlined),
            selectedIcon: const Icon(Icons.business, color: Color(0xFF0D6B4F)),
            label: loc.t('organization_profile'),
          ),
        ],
      ),
    );
  }
}
