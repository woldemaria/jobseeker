import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/advertisement_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';
import '../job_seeker/job_seeker_main_screen.dart';
import '../employer/employer_main_screen.dart';
import '../admin/admin_main_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final ApiService apiService;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.apiService,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'jobseeker@example.com');
  final _passwordController = TextEditingController(text: 'Seeker@123456');
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final resp = await widget.authService.login(email, password);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (resp.success && widget.authService.currentUser != null) {
        final user = widget.authService.currentUser!;
        if (user.isAdmin) {
          final adminRepo = Provider.of<AdminRepository>(
            context,
            listen: false,
          );
          final adRepo = Provider.of<AdvertisementRepository>(
            context,
            listen: false,
          );
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
        }
      } else {
        setState(() => _errorMessage = resp.message);
      }
    }
  }

  void _fillDemo(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _errorMessage = null;
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('login')),
        actions: [
          TextButton.icon(
            onPressed: _showLanguageDialog,
            icon: const Icon(Icons.language, size: 18),
            label: Text(
              widget.authService.currentLocale.languageCode == 'am'
                  ? 'አማ'
                  : 'EN',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6B4F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.work,
                  size: 48,
                  color: Color(0xFF0D6B4F),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.t('welcome'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              loc.t('welcome_subtitle'),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFF991B1B)),
                ),
              ),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: loc.t('email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: loc.t('password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ForgotPasswordScreen(apiService: widget.apiService),
                    ),
                  );
                },
                child: Text(loc.t('forgot_password')),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _login,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(loc.t('login')),
            ),
            const SizedBox(height: 20),

            // Demo Accounts Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Demo Accounts:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(36),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                          onPressed: () => _fillDemo(
                            'jobseeker@example.com',
                            'Seeker@123456',
                          ),
                          child: const Text(
                            'Job Seeker',
                            style: TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(36),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                          onPressed: () => _fillDemo(
                            'recruitment@example.com',
                            'Employer@123456',
                          ),
                          child: const Text(
                            'Employer',
                            style: TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(36),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          ),
                          onPressed: () => _fillDemo(
                            'admin@jobrecruitment.et',
                            'Admin@123456',
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(loc.t('dont_have_account')),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          authService: widget.authService,
                          jobRepo: widget.jobRepo,
                          appRepo: widget.appRepo,
                          profRepo: widget.profRepo,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                  child: Text(loc.t('register')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
