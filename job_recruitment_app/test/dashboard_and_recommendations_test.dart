import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_recruitment_app/core/theme/app_theme.dart';
import 'package:job_recruitment_app/features/job_seeker/job_seeker_dashboard_screen.dart';
import 'package:job_recruitment_app/features/matching/recommendations_screen.dart';
import 'package:job_recruitment_app/features/employer/employer_dashboard_screen.dart';
import 'package:job_recruitment_app/features/admin/admin_main_screen.dart';
import 'package:job_recruitment_app/l10n/app_localizations.dart';
import 'package:job_recruitment_app/repositories/admin_repository.dart';
import 'package:job_recruitment_app/repositories/advertisement_repository.dart';
import 'package:job_recruitment_app/repositories/application_repository.dart';
import 'package:job_recruitment_app/repositories/job_repository.dart';
import 'package:job_recruitment_app/repositories/profile_repository.dart';
import 'package:job_recruitment_app/services/api_service.dart';
import 'package:job_recruitment_app/services/auth_service.dart';
import 'package:job_recruitment_app/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required Widget child,
    required AuthService authService,
    required StorageService storage,
    required ApiService apiService,
    required JobRepository jobRepo,
    required ApplicationRepository appRepo,
    required ProfileRepository profRepo,
    required AdvertisementRepository adRepo,
    required AdminRepository adminRepo,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: storage),
        Provider.value(value: apiService),
        Provider.value(value: jobRepo),
        Provider.value(value: appRepo),
        Provider.value(value: profRepo),
        Provider.value(value: adRepo),
        Provider.value(value: adminRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        home: child,
      ),
    );
  }

  testWidgets('Test JobSeekerDashboardScreen rendering in Light Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: JobSeekerDashboardScreen(
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: profRepo,
          authService: authService,
          onTabChange: (_) {},
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.light,
      ),
    );

    await tester.pump();
    expect(find.byType(JobSeekerDashboardScreen), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(JobSeekerDashboardScreen), findsOneWidget);
  });

  testWidgets('Test JobSeekerDashboardScreen rendering in Dark Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: JobSeekerDashboardScreen(
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: profRepo,
          authService: authService,
          onTabChange: (_) {},
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.pump();
    expect(find.byType(JobSeekerDashboardScreen), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(JobSeekerDashboardScreen), findsOneWidget);
  });

  testWidgets('Test RecommendationsScreen rendering in Light Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: RecommendationsScreen(
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: profRepo,
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.light,
      ),
    );

    await tester.pump();
    expect(find.byType(RecommendationsScreen), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    expect(
      find.text('Sign In for Tailored Matches'),
      findsOneWidget,
    );
  });

  testWidgets('Test RecommendationsScreen rendering in Dark Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: RecommendationsScreen(
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: profRepo,
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.pump();
    expect(find.byType(RecommendationsScreen), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(RecommendationsScreen), findsOneWidget);
    expect(
      find.text('Sign In for Tailored Matches'),
      findsOneWidget,
    );
  });

  testWidgets('Test EmployerDashboardScreen rendering in Light Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: EmployerDashboardScreen(
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: profRepo,
          apiService: apiService,
          authService: authService,
          onTabChange: (_) {},
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.light,
      ),
    );

    await tester.pump();
    expect(find.byType(EmployerDashboardScreen), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(EmployerDashboardScreen), findsOneWidget);
  });

  testWidgets('Test EmployerDashboardScreen rendering in Dark Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: EmployerDashboardScreen(
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: profRepo,
          apiService: apiService,
          authService: authService,
          onTabChange: (_) {},
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.pump();
    expect(find.byType(EmployerDashboardScreen), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(EmployerDashboardScreen), findsOneWidget);
  });

  testWidgets('Test AdminMainScreen rendering in Light Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: AdminMainScreen(
          adminRepo: adminRepo,
          adRepo: adRepo,
          authService: authService,
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.light,
      ),
    );

    await tester.pump();
    expect(find.byType(AdminMainScreen), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(AdminMainScreen), findsOneWidget);
  });

  testWidgets('Test AdminMainScreen rendering in Dark Mode', (tester) async {
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final authService = AuthService(apiService, storage);
    final jobRepo = JobRepository(apiService);
    final appRepo = ApplicationRepository(apiService);
    final profRepo = ProfileRepository(apiService);
    final adRepo = AdvertisementRepository(apiService);
    final adminRepo = AdminRepository(apiService);

    await tester.pumpWidget(
      buildTestApp(
        child: AdminMainScreen(
          adminRepo: adminRepo,
          adRepo: adRepo,
          authService: authService,
        ),
        authService: authService,
        storage: storage,
        apiService: apiService,
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
        adRepo: adRepo,
        adminRepo: adminRepo,
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.pump();
    expect(find.byType(AdminMainScreen), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(AdminMainScreen), findsOneWidget);
  });
}
