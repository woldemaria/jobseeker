import 'package:flutter/material.dart';

import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import 'job_seeker_dashboard_screen.dart';
import '../jobs/job_search_screen.dart';
import '../matching/recommendations_screen.dart';
import '../applications/my_applications_screen.dart';
import '../profile/profile_screen.dart';

class JobSeekerMainScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final AuthService authService;

  const JobSeekerMainScreen({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.authService,
  });

  @override
  State<JobSeekerMainScreen> createState() => _JobSeekerMainScreenState();
}

class _JobSeekerMainScreenState extends State<JobSeekerMainScreen> {
  int _currentIndex = 0;

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final screens = [
      JobSeekerDashboardScreen(
        jobRepo: widget.jobRepo,
        appRepo: widget.appRepo,
        profRepo: widget.profRepo,
        authService: widget.authService,
        onTabChange: _onTabChange,
      ),
      JobSearchScreen(
        jobRepo: widget.jobRepo,
        appRepo: widget.appRepo,
        profRepo: widget.profRepo,
      ),
      RecommendationsScreen(
        jobRepo: widget.jobRepo,
        appRepo: widget.appRepo,
        profRepo: widget.profRepo,
      ),
      MyApplicationsScreen(appRepo: widget.appRepo),
      ProfileScreen(profRepo: widget.profRepo, authService: widget.authService),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: const Color(0xFF0D6B4F).withOpacity(0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home, color: Color(0xFF0D6B4F)),
            label: loc.t('dashboard'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search, color: Color(0xFF0D6B4F)),
            label: loc.t('search_jobs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF0D6B4F),
            ),
            label: loc.t('recommendations'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(
              Icons.assignment,
              color: Color(0xFF0D6B4F),
            ),
            label: loc.t('applications'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: Color(0xFF0D6B4F)),
            label: loc.t('profile'),
          ),
        ],
      ),
    );
  }
}
