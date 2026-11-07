import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/advertisement_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../job_seeker/job_seeker_main_screen.dart';
import '../employer/employer_main_screen.dart';
import '../admin/admin_main_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final AuthService authService;
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final ApiService apiService;

  const SplashScreen({
    super.key,
    required this.authService,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.apiService,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final loggedIn = await widget.authService.checkAuthStatus();

    if (!mounted) return;

    if (loggedIn && widget.authService.currentUser != null) {
      final user = widget.authService.currentUser!;
      if (user.isAdmin) {
        final adminRepo = Provider.of<AdminRepository>(context, listen: false);
        final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminMainScreen(
              adminRepo: adminRepo,
              adRepo: adRepo,
              authService: widget.authService,
            ),
          ),
        );
        return;
      } else if (user.isEmployer) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmployerMainScreen(
              jobRepo: widget.jobRepo,
              appRepo: widget.appRepo,
              profRepo: widget.profRepo,
              apiService: widget.apiService,
              authService: widget.authService,
            ),
          ),
        );
        return;
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => JobSeekerMainScreen(
              jobRepo: widget.jobRepo,
              appRepo: widget.appRepo,
              profRepo: widget.profRepo,
              authService: widget.authService,
            ),
          ),
        );
        return;
      }
    }

    Navigator.pushReplacement(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D6B4F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.work, size: 54, color: Color(0xFF0D6B4F)),
            ),
            const SizedBox(height: 24),
            const Text(
              'JobSeeker Ethiopia',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart Skills-Based Recruitment Platform',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
