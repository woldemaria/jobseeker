import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'repositories/admin_repository.dart';
import 'repositories/ads_consent_repository.dart';
import 'repositories/advertisement_repository.dart';
import 'repositories/application_repository.dart';
import 'repositories/career_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/job_repository.dart';
import 'repositories/profile_repository.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'features/authentication/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom ErrorWidget builder to eliminate white/blank screen crashes
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 54,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to display this content',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Initialize storage
  final storageService = await StorageService.init();
  final apiService = ApiService(storageService);
  final authService = AuthService(apiService, storageService);

  // Initialize repositories
  final jobRepository = JobRepository(apiService);
  final applicationRepository = ApplicationRepository(apiService);
  final profileRepository = ProfileRepository(apiService);
  final advertisementRepository = AdvertisementRepository(apiService);
  final adminRepository = AdminRepository(apiService);
  final chatRepository = ChatRepository(apiService);
  final careerRepository = CareerRepository(apiService);
  final adsConsentRepository = AdsConsentRepository(apiService, storageService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: storageService),
        Provider.value(value: apiService),
        Provider.value(value: jobRepository),
        Provider.value(value: applicationRepository),
        Provider.value(value: profileRepository),
        Provider.value(value: advertisementRepository),
        Provider.value(value: adsConsentRepository),
        Provider.value(value: adminRepository),
        Provider.value(value: chatRepository),
        Provider.value(value: careerRepository),
      ],
      child: const JobRecruitmentApp(),
    ),
  );
}

class JobRecruitmentApp extends StatelessWidget {
  const JobRecruitmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final jobRepo = Provider.of<JobRepository>(context, listen: false);
    final appRepo = Provider.of<ApplicationRepository>(context, listen: false);
    final profRepo = Provider.of<ProfileRepository>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    return MaterialApp(
      title: 'JobSeeker Ethiopia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: authService.currentLocale,
      supportedLocales: const [Locale('en', ''), Locale('am', '')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(
        authService: authService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        apiService: apiService,
      ),
    );
  }
}
