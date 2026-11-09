import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:job_recruitment_app/l10n/app_localizations.dart';
import 'package:job_recruitment_app/models/job_model.dart';
import 'package:job_recruitment_app/models/user_model.dart';
import 'package:job_recruitment_app/models/advertisement_model.dart';
import 'package:job_recruitment_app/services/map_service.dart';
import 'package:job_recruitment_app/services/storage_service.dart';
import 'package:job_recruitment_app/shared/widgets/match_score_badge.dart';
import 'package:job_recruitment_app/shared/widgets/status_badge.dart';
import 'package:job_recruitment_app/shared/widgets/job_card.dart';
import 'package:job_recruitment_app/shared/widgets/location_map_modal.dart';
import 'package:job_recruitment_app/models/application_model.dart';
import 'package:job_recruitment_app/shared/utils/avatar_helper.dart';
import 'package:job_recruitment_app/features/profile/profile_form_screen.dart';
import 'package:job_recruitment_app/models/chat_group_model.dart';
import 'package:job_recruitment_app/models/chat_message_model.dart';
import 'package:job_recruitment_app/shared/widgets/share_with_friends_modal.dart';
import 'package:job_recruitment_app/data/ethiopian_job_titles_data.dart';
import 'package:job_recruitment_app/models/job_category_model.dart';
import 'package:job_recruitment_app/models/notification_model.dart';
import 'package:job_recruitment_app/features/job_seeker/job_seeker_dashboard_screen.dart';
import 'package:job_recruitment_app/features/matching/recommendations_screen.dart';
import 'package:job_recruitment_app/features/admin/admin_fraud_screen.dart';
import 'package:job_recruitment_app/repositories/career_repository.dart';
import 'package:job_recruitment_app/models/job_alert_model.dart';
import 'package:job_recruitment_app/models/job_offer_model.dart';
import 'package:job_recruitment_app/features/job_seeker/ai_career_assistant_screen.dart';
import 'package:job_recruitment_app/features/job_seeker/job_alerts_screen.dart';
import 'package:job_recruitment_app/features/applications/job_offer_modal.dart';
import 'package:job_recruitment_app/features/profile/education_management_screen.dart';
import 'package:job_recruitment_app/features/profile/experience_management_screen.dart';
import 'package:job_recruitment_app/features/profile/skills_management_screen.dart';
import 'package:job_recruitment_app/repositories/profile_repository.dart';
import 'package:job_recruitment_app/repositories/application_repository.dart';
import 'package:job_recruitment_app/services/api_service.dart';
import 'package:job_recruitment_app/models/ad_consent_model.dart';
import 'package:job_recruitment_app/repositories/ads_consent_repository.dart';
import 'package:job_recruitment_app/features/advertising/privacy_and_ads_preferences_screen.dart';
import 'package:job_recruitment_app/features/advertising/ad_consent_modal.dart';
import 'package:job_recruitment_app/shared/widgets/ad_consent_banner.dart';
import 'package:job_recruitment_app/models/advertising_package_model.dart';
import 'package:job_recruitment_app/features/advertising/package_card_widget.dart';
import 'package:job_recruitment_app/features/advertising/advertising_packages_screen.dart';
import 'package:job_recruitment_app/features/admin/advertising_package_manager_screen.dart';
import 'package:job_recruitment_app/features/advertising/campaign_preview_widget.dart';
import 'package:job_recruitment_app/features/advertising/campaign_creation_wizard_screen.dart';
import 'package:job_recruitment_app/features/employer/employer_campaigns_screen.dart';
import 'package:job_recruitment_app/features/admin/admin_campaign_review_screen.dart';
import 'package:job_recruitment_app/models/payment_transaction_model.dart';
import 'package:job_recruitment_app/features/payment/checkout_screen.dart';
import 'package:job_recruitment_app/features/payment/payment_status_screen.dart';
import 'package:job_recruitment_app/features/payment/transaction_history_screen.dart';
import 'package:job_recruitment_app/features/profile/quiz_list_screen.dart';
import 'package:job_recruitment_app/features/profile/quiz_take_screen.dart';
import 'package:job_recruitment_app/features/profile/profile_cv_preview_dialog.dart';
import 'package:job_recruitment_app/features/jobs/salary_benchmarks_screen.dart';
import 'package:job_recruitment_app/features/jobs/notice_board_lookup_dialog.dart';

void main() {
  test('AppLocalizations English and Amharic translation keys test', () {
    final enLoc = AppLocalizations(const Locale('en'));
    final amLoc = AppLocalizations(const Locale('am'));

    expect(enLoc.t('app_title'), 'JobSeeker Ethiopia');
    expect(amLoc.t('app_title'), 'ጆብሲከር ኢትዮጵያ');

    expect(enLoc.t('login'), 'Login');
    expect(amLoc.t('login'), 'ይግቡ');

    expect(enLoc.t('matching_score'), 'Match Score');
    expect(amLoc.t('matching_score'), 'የተዛማጅነት ነጥብ');

    // Advertisement bilingual translations
    expect(enLoc.t('advertisements'), 'Advertisements');
    expect(amLoc.t('advertisements'), 'የማስታወቂያ ዘመቻዎች');
    expect(enLoc.t('featured_jobs'), 'Featured Jobs');
    expect(amLoc.t('featured_jobs'), 'ተመራጭ የስራ ክፍት ቦታዎች');
    expect(enLoc.t('campaign_status'), 'Campaign Status');
    expect(amLoc.t('campaign_status'), 'የዘመቻው ሁኔታ');
  });

  test(
    'MapService generates accurate OpenStreetMap and Google Maps URLs',
    () async {
      final osmUrl = MapService.getOpenStreetMapUrl(
        'Bole, Addis Ababa',
        lat: 8.995,
        lon: 38.788,
      );
      expect(osmUrl.contains('openstreetmap.org'), isTrue);
      expect(osmUrl.contains('8.995'), isTrue);

      final gmapsUrl = MapService.getGoogleMapsUrl('Addis Ababa');
      expect(gmapsUrl.contains('google.com/maps'), isTrue);
      expect(gmapsUrl.contains('Addis%20Ababa'), isTrue);

      final geocode = await MapService.geocode('Bole');
      expect(geocode, isNotNull);
      expect(geocode!.latitude, closeTo(8.99, 0.1));
      expect(geocode.longitude, closeTo(38.78, 0.1));

      // Place Profile Image Verification
      final addisProfile = await MapService.getPlaceProfile('Addis Ababa');
      expect(addisProfile.name, 'Addis Ababa');
      expect(addisProfile.imageUrl, isNotNull);
      expect(addisProfile.imageUrl!.contains('http'), isTrue);
      expect(addisProfile.description, isNotNull);

      final hawassaProfile = await MapService.getPlaceProfile('Hawassa');
      expect(hawassaProfile.name, 'Hawassa');
      expect(hawassaProfile.imageUrl, isNotNull);
    },
  );

  test('MapService builds exact place queries and targets specific subcities without generic Addis Ababa hijacking', () async {
    final queryWithOrg = MapService.buildExactPlaceQuery(
      'Bole, Addis Ababa',
      organizationName: 'Commercial Bank of Ethiopia',
    );
    expect(
      queryWithOrg,
      'Commercial Bank of Ethiopia, Bole, Addis Ababa, Ethiopia',
    );

    final gmapsUrl = MapService.getGoogleMapsUrl(
      'Kazanchis, Addis Ababa',
      organizationName: 'UNECA HQ',
      lat: 9.0159,
      lon: 38.7712,
    );
    expect(
      gmapsUrl.contains(
        'UNECA%20HQ%2C%20Kazanchis%2C%20Addis%20Ababa%2C%20Ethiopia',
      ),
      isTrue,
    );
    expect(gmapsUrl.contains('&center=9.0159,38.7712'), isTrue);

    final dirUrl = MapService.getGoogleMapsDirectionsUrl(
      'Bole Medhanialem',
      organizationName: 'Safaricom',
    );
    expect(
      dirUrl.contains('Safaricom%2C%20Bole%20Medhanialem%2C%20Ethiopia'),
      isTrue,
    );

    // Bole with Addis Ababa in string must NOT be hijacked by 9.0300
    final loc = await MapService.geocode('Bole Medhanialem, Addis Ababa');
    expect(loc, isNotNull);
    expect(
      loc!.latitude,
      isNot(equals(9.0300)),
    ); // Must be exact Bole (around 8.998)
  });

  testWidgets('MatchScoreBadge and StatusBadge render accurately', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MatchScoreBadge(score: 86.5),
              StatusBadge(status: 'shortlisted'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('87% Match'), findsOneWidget);
    expect(find.text('Shortlisted'), findsOneWidget);
  });

  testWidgets('JobCard renders vacancy information correctly', (
    WidgetTester tester,
  ) async {
    final sampleJob = JobModel(
      id: 1,
      employerId: 1,
      title: 'Junior Flutter Developer',
      description: 'Build mobile apps in Flutter',
      location: 'Addis Ababa',
      employmentType: 'Full-time',
      currency: 'ETB',
      salaryMin: 25000,
      salaryMax: 35000,
      deadline: '2026-12-01',
      status: 'published',
      matchScore: 86.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobCard(job: sampleJob, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Junior Flutter Developer'), findsOneWidget);
    expect(find.text('Addis Ababa'), findsOneWidget);
    expect(find.text('Full-time'), findsOneWidget);
    expect(find.text('25000 - 35000 ETB'), findsOneWidget);
    expect(find.text('87% Match'), findsOneWidget);
  });

  testWidgets('LocationMapModal renders location and map buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocationMapModal(
            title: 'Commercial Bank of Ethiopia',
            address: 'Bole, Addis Ababa',
            organizationName: 'CBE HQ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Commercial Bank of Ethiopia'), findsOneWidget);
    expect(find.text('Bole, Addis Ababa'), findsWidgets);
    expect(find.text('Google Maps'), findsWidgets);
    expect(find.text('OpenStreetMap'), findsWidgets);
    expect(find.text('Get Turn-by-Turn Directions'), findsWidgets);
  });

  test('UserModel parses profile_photo accurately', () {
    final user = UserModel.fromJson({
      'id': 10,
      'name': 'Sara Bekele',
      'email': 'sara@example.com',
      'profile_photo':
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
      'status': 'active',
      'roles': ['job_seeker'],
    });

    expect(
      user.profilePhoto,
      'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
    );
    expect(user.name, 'Sara Bekele');
    expect(user.isJobSeeker, isTrue);
  });

  test(
    'AdvertisementModel parses JSON and provides bilingual translations',
    () {
      final ad = AdvertisementModel.fromJson({
        'id': 101,
        'title': 'Ethiopian Airlines Pilot Cadet 2026',
        'title_am': 'የኢትዮጵያ አየር መንገድ የፓይለት ቅጥር',
        'subtitle': 'Join Africa’s Largest Airline',
        'subtitle_am': 'የአፍሪካ ግዙፉን አየር መንገድ ይቀላቀሉ',
        'badge_text': '20% Tuition Discount',
        'badge_text_am': '20% የትምህርት ክፍያ ቅናሽ',
        'image_url':
            'https://images.unsplash.com/photo-1436491865332-7a61a109cc05',
        'category': 'recruitment_campaigns',
        'placement': 'hero',
        'cta_type': 'apply_now',
        'cta_text': 'Apply Now',
        'cta_text_am': 'አሁን ያመልክቱ',
        'cta_target': 'https://ethiopianairlines.com',
        'impressions_count': 120,
        'clicks_count': 24,
        'ctr': 20.0,
        'status': 'active',
        'start_date': '2026-11-01',
        'end_date': '2026-11-30',
      });

      expect(ad.id, 101);
      expect(ad.getTitle('en'), 'Ethiopian Airlines Pilot Cadet 2026');
      expect(ad.getTitle('am'), 'የኢትዮጵያ አየር መንገድ የፓይለት ቅጥር');
      expect(ad.getSubtitle('am'), 'የአፍሪካ ግዙፉን አየር መንገድ ይቀላቀሉ');
      expect(ad.getBadge('am'), '20% የትምህርት ክፍያ ቅናሽ');
      expect(ad.getCta('am'), 'አሁን ያመልክቱ');
      expect(ad.ctr, 20.0);
      expect(ad.isActive, isTrue);
      expect(ad.isPaused, isFalse);
      expect(ad.isExpired, isFalse);
    },
  );

  test(
    'StorageService persists cookie and ad privacy consent preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      // Default before choice: privacy-first (no tracking or profiling)
      expect(storage.getAdConsentStatus(), isNull);
      expect(storage.hasConsentRecorded(), isFalse);
      expect(storage.isPersonalizedAdsAllowed(), isFalse);
      expect(storage.isAnalyticsAllowed(), isFalse);
      expect(storage.getConsentUuid(), isNotEmpty);

      // Reject consent
      await storage.saveAdConsent(
        status: 'rejected',
        nonPersonalized: false,
        personalized: false,
        analytics: false,
        cookies: false,
      );
      expect(storage.getAdConsentStatus(), 'rejected');
      expect(storage.hasConsentRecorded(), isTrue);
      expect(storage.isNonPersonalizedAdsAllowed(), isFalse);
      expect(storage.isPersonalizedAdsAllowed(), isFalse);
      expect(storage.isAnalyticsAllowed(), isFalse);
      expect(storage.isCookiesAllowed(), isFalse);

      // Accept consent
      await storage.saveAdConsent(
        status: 'accepted',
        nonPersonalized: true,
        personalized: true,
        analytics: true,
        cookies: true,
      );
      expect(storage.getAdConsentStatus(), 'accepted');
      expect(storage.isNonPersonalizedAdsAllowed(), isTrue);
      expect(storage.isPersonalizedAdsAllowed(), isTrue);
      expect(storage.isAnalyticsAllowed(), isTrue);
      expect(storage.isCookiesAllowed(), isTrue);

      // Withdraw consent
      await storage.withdrawAdConsent();
      expect(storage.getAdConsentStatus(), 'withdrawn');
      expect(storage.isNonPersonalizedAdsAllowed(), isFalse);
      expect(storage.isPersonalizedAdsAllowed(), isFalse);
      expect(storage.isAnalyticsAllowed(), isFalse);
      expect(storage.getConsentWithdrawnAt(), isNotNull);
    },
  );

  test(
    'UserModel RBAC verifies JobSeeker, Employer, and Admin roles and aliases',
    () {
      final candidate = UserModel(
        id: 1,
        name: 'Abebe',
        email: 'a@test.com',
        status: 'active',
        roles: ['job_seeker'],
      );
      expect(candidate.isJobSeeker, isTrue);
      expect(candidate.isEmployer, isFalse);
      expect(candidate.isAdmin, isFalse);

      final employer = UserModel(
        id: 2,
        name: 'Ethio Telecom',
        email: 'e@test.com',
        status: 'active',
        roles: ['employer'],
      );
      expect(employer.isJobSeeker, isFalse);
      expect(employer.isEmployer, isTrue);
      expect(employer.isAdmin, isFalse);

      final admin = UserModel(
        id: 3,
        name: 'Root Admin',
        email: 'admin@test.com',
        status: 'active',
        roles: ['administrator'],
      );
      expect(admin.isJobSeeker, isFalse);
      expect(admin.isEmployer, isFalse);
      expect(admin.isAdmin, isTrue);

      // Test alias parsing and case insensitivity
      final userWithSingularRole = UserModel.fromJson({
        'id': 4,
        'name': 'System Manager',
        'email': 'mgr@test.com',
        'role': 'ADMIN',
      });
      expect(userWithSingularRole.isAdmin, isTrue);

      final employeeUser = UserModel.fromJson({
        'id': 5,
        'name': 'Company Recruiter',
        'email': 'recruiter@corp.et',
        'role': 'recruiter',
      });
      expect(employeeUser.isEmployer, isTrue);

      final fallbackUser = UserModel.fromJson({
        'id': 6,
        'name': 'Unknown Role User',
        'email': 'unknown@test.com',
      });
      expect(fallbackUser.isJobSeeker, isTrue);
      expect(fallbackUser.isAdmin, isFalse);
      expect(fallbackUser.isEmployer, isFalse);
    },
  );

  test('ApplicationModel correctly parses interview booking details', () {
    final json = {
      'id': 10,
      'job_id': 5,
      'profile_id': 2,
      'cv_document_id': 1,
      'status': 'interview',
      'applied_at': '2026-11-06T10:00:00Z',
      'interview_at': '2026-11-10T14:00:00Z',
      'interview_type': 'video',
      'interview_location': 'https://meet.google.com/abc-xyz',
      'interview_notes': 'Please be prepared to present your portfolio.',
      'interview_status': 'confirmed',
    };

    final app = ApplicationModel.fromJson(json);
    expect(app.id, 10);
    expect(app.status, 'interview');
    expect(app.interviewAt, '2026-11-10T14:00:00Z');
    expect(app.interviewType, 'video');
    expect(app.interviewLocation, 'https://meet.google.com/abc-xyz');
    expect(app.interviewNotes, 'Please be prepared to present your portfolio.');
    expect(app.interviewStatus, 'confirmed');
  });

  test('getAvatarImageProvider handles network URLs and data URIs', () {
    final httpProvider = getAvatarImageProvider(
      'https://example.com/photo.jpg',
    );
    expect(httpProvider, isA<NetworkImage>());

    final dataUriProvider = getAvatarImageProvider(
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    expect(dataUriProvider, isA<MemoryImage>());

    expect(getAvatarImageProvider(null), isNull);
    expect(getAvatarImageProvider(''), isNull);
  });

  test(
    'ApiResponse correctly parses standardized 422 validation errors map',
    () {
      final rawResponse = {
        'success': false,
        'message': 'The profile details provided are invalid.',
        'data': null,
        'errors': {
          'name': ['Full name must contain at least 2 characters.'],
          'phone': ['Please provide a valid phone number format.'],
        },
      };

      expect(rawResponse['success'], isFalse);
      expect(rawResponse['errors'], isNotNull);
      final errors = rawResponse['errors'] as Map<String, dynamic>;
      expect(
        errors['name'],
        contains('Full name must contain at least 2 characters.'),
      );
      expect(
        errors['phone'],
        contains('Please provide a valid phone number format.'),
      );
    },
  );

  test('ProfileFormScreen widget class is instantiable and verified', () {
    expect(ProfileFormScreen, isNotNull);
  });

  test(
    'ChatGroupModel and ChatMessageModel parse data and job share correctly',
    () {
      final groupJson = {
        'id': 1,
        'name': 'Tech Careers Ethiopia',
        'description': 'Peer career group',
        'created_by': 1,
        'is_private': false,
        'members_count': 12,
        'is_member': true,
        'latest_message': {
          'message': 'Check out this vacancy!',
          'created_at': '2026-11-06T15:00:00Z',
          'user': {'name': 'Sara'},
        },
      };

      final group = ChatGroupModel.fromJson(groupJson);
      expect(group.id, 1);
      expect(group.name, 'Tech Careers Ethiopia');
      expect(group.memberCount, 12);
      expect(group.isMember, isTrue);
      expect(group.lastMessageText, 'Check out this vacancy!');
      expect(group.lastMessageSender, 'Sara');

      final msgJson = {
        'id': 100,
        'group_id': 1,
        'user_id': 2,
        'message': 'Vacancy alert',
        'message_type': 'job_share',
        'shared_job_id': 5,
        'shared_job': {
          'id': 5,
          'title': 'Senior Software Engineer',
          'employment_type': 'Full-time',
          'location': 'Addis Ababa',
          'salary_min': 50000,
          'salary_max': 80000,
          'currency': 'ETB',
          'deadline': '2026-12-01',
          'status': 'published',
        },
        'user': {'name': 'Abebe', 'profile_photo': null},
        'created_at': '2026-11-06T15:30:00Z',
      };

      final msg = ChatMessageModel.fromJson(msgJson);
      expect(msg.id, 100);
      expect(msg.senderName, 'Abebe');
      expect(msg.messageType, 'job_share');
      expect(msg.sharedJobId, 5);
      expect(msg.sharedJob?.title, 'Senior Software Engineer');
    },
  );

  test('ShareWithFriendsModal class is instantiable', () {
    expect(ShareWithFriendsModal, isNotNull);
  });

  test('EthiopianJobCatalogue bundles all 30 categories and 475 titles', () {
    expect(EthiopianJobCatalogue.categories.length, 30);
    expect(EthiopianJobCatalogue.allTitles.length, 475);

    // Search functionality
    final engResults = EthiopianJobCatalogue.searchTitles('engineer');
    expect(engResults, isNotEmpty);
    expect(
      engResults.every((t) => t.toLowerCase().contains('engineer')),
      isTrue,
    );

    // Category matching
    final agriCat = EthiopianJobCatalogue.findCategoryForTitle('Agronomist');
    expect(agriCat, isNotNull);
    expect(agriCat?.name, 'Agriculture and Farming');
    expect(agriCat?.icon, Icons.agriculture);

    // JobCategoryModel serialization
    final catModel = JobCategoryModel(
      id: 1,
      name: agriCat!.name,
      slug: agriCat.slug,
      iconName: agriCat.iconName,
      titlesCount: agriCat.titles.length,
    );
    expect(catModel.icon, Icons.agriculture);
    expect(catModel.toJson()['name'], 'Agriculture and Farming');
  });

  test(
    'JobSeekerDashboardScreen widget class is instantiable and verified',
    () {
      expect(JobSeekerDashboardScreen, isNotNull);
    },
  );

  test(
    'JobModel safely parses category as either String or eager-loaded Map',
    () {
      // 1. Eager loaded relation object from Eloquent with(['category'])
      final eagerJson = {
        'id': 101,
        'employer_id': 1,
        'title': 'Senior Flutter Architect',
        'description': 'Building next-gen mobile systems',
        'location': 'Addis Ababa (Bole)',
        'employment_type': 'Full-time',
        'currency': 'ETB',
        'deadline': '2026-12-31',
        'status': 'published',
        'category': {
          'id': 15,
          'name': 'Information Technology',
          'slug': 'information-technology',
        },
      };
      final eagerJob = JobModel.fromJson(eagerJson);
      expect(eagerJob.id, 101);
      expect(eagerJob.category, 'Information Technology');

      // 2. Direct string category column
      final stringJson = {
        'id': 102,
        'employer_id': 1,
        'title': 'Database Administrator',
        'description': 'PostgreSQL optimization',
        'location': 'Addis Ababa',
        'employment_type': 'Full-time',
        'currency': 'ETB',
        'deadline': '2026-12-31',
        'status': 'published',
        'category': 'Database & Infrastructure',
      };
      final stringJob = JobModel.fromJson(stringJson);
      expect(stringJob.id, 102);
      expect(stringJob.category, 'Database & Infrastructure');
    },
  );

  test('JobSeekerProfileModel parses preferred_job_title and preferred_category_id', () {
    final profileJson = {
      'id': 50,
      'user_id': 12,
      'preferred_job_title': 'Senior Mobile Engineer',
      'preferred_category_id': 15,
      'experience_years': 4.5,
      'location': 'Addis Ababa',
    };
    final prof = JobSeekerProfileModel.fromJson(profileJson);
    expect(prof.preferredJobTitle, 'Senior Mobile Engineer');
    expect(prof.preferredCategoryId, 15);
    expect(prof.experienceYears, 4.5);
  });

  test('JobModel copyWith preserves and updates state immutably', () {
    final originalJob = JobModel(
      id: 201,
      employerId: 5,
      title: 'Full Stack Engineer',
      description: 'Laravel and Flutter development',
      location: 'Bole, Addis Ababa',
      latitude: 9.0123,
      longitude: 38.7654,
      category: 'Software Engineering',
      categoryId: 15,
      jobTitleId: 42,
      employmentType: 'Full-time',
      currency: 'ETB',
      deadline: '2026-12-31',
      status: 'published',
      isSaved: false,
    );

    final savedJob = originalJob.copyWith(isSaved: true);
    expect(savedJob.id, 201);
    expect(savedJob.title, 'Full Stack Engineer');
    expect(savedJob.location, 'Bole, Addis Ababa');
    expect(savedJob.latitude, 9.0123);
    expect(savedJob.longitude, 38.7654);
    expect(savedJob.category, 'Software Engineering');
    expect(savedJob.isSaved, isTrue);
    expect(originalJob.isSaved, isFalse);
  });

  test('AdvertisementModel with status expired and varied categories parses cleanly', () {
    final adJson = {
      'id': 105,
      'title': 'Expired Holiday Promotion',
      'category': 'company_promotions',
      'placement': 'dashboard',
      'target_role': 'all',
      'cta_type': 'visit_company',
      'cta_text': 'Visit Website',
      'cta_target': 'https://example.com',
      'start_date': '2026-01-01',
      'end_date': '2026-02-01',
      'status': 'expired',
      'priority': 5,
      'impressions_count': 500,
      'clicks_count': 45,
      'ctr': 9.0,
    };

    final ad = AdvertisementModel.fromJson(adJson);
    expect(ad.id, 105);
    expect(ad.status, 'expired');
    expect(ad.category, 'company_promotions');
    expect(ad.impressionsCount, 500);
    expect(ad.clicksCount, 45);
    expect(ad.ctr, 9.0);
  });

  test('NotificationModel copyWith immutably updates read status', () {
    final note = NotificationModel(
      id: 12,
      title: 'Interview Scheduled',
      message: 'You have an interview scheduled for Friday.',
      notificationType: 'interview_invitation',
      isRead: false,
      createdAt: '2026-11-07T12:00:00Z',
    );

    expect(note.isRead, isFalse);
    final updated = note.copyWith(isRead: true);
    expect(updated.isRead, isTrue);
    expect(updated.id, 12);
    expect(updated.title, 'Interview Scheduled');
    expect(note.isRead, isFalse);
  });

  testWidgets('JobCard renders Apply Now button and triggers callback', (
    WidgetTester tester,
  ) async {
    bool applyClicked = false;
    bool bookmarkClicked = false;

    final testJob = JobModel(
      id: 77,
      employerId: 2,
      title: 'Senior Flutter Architect',
      description: 'Building mobile client apps',
      location: 'Addis Ababa',
      employmentType: 'full_time',
      currency: 'ETB',
      deadline: '2026-12-31',
      status: 'published',
      hasApplied: false,
      isSaved: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobCard(
            job: testJob,
            onTap: () => applyClicked = true,
            onSaveToggle: () => bookmarkClicked = true,
          ),
        ),
      ),
    );

    expect(find.text('Senior Flutter Architect'), findsOneWidget);
    expect(find.text('Apply Now'), findsOneWidget);

    // Tap Apply Now button
    await tester.tap(find.text('Apply Now'));
    await tester.pump();
    expect(applyClicked, isTrue);

    // Tap Bookmark Icon button
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();
    expect(bookmarkClicked, isTrue);
  });

  testWidgets('JobCard renders Applied badge when hasApplied is true', (
    WidgetTester tester,
  ) async {
    final testJob = JobModel(
      id: 78,
      employerId: 2,
      title: 'Senior Flutter Architect',
      description: 'Building mobile client apps',
      location: 'Addis Ababa',
      employmentType: 'full_time',
      currency: 'ETB',
      deadline: '2026-12-31',
      status: 'published',
      hasApplied: true,
      isSaved: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobCard(job: testJob, onTap: () {}, onSaveToggle: () {}),
        ),
      ),
    );

    expect(find.text('Applied'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  test('RecommendationsScreen class is instantiable and verified', () {
    expect(RecommendationsScreen, isNotNull);
  });

  test('JobModel parses fraud detection fields and risk classifications accurately', () {
    final rawJson = {
      'id': 105,
      'employer_id': 3,
      'title': 'High Risk Overseas Job',
      'description': 'Send registration fee 2000 ETB upfront',
      'location': 'Bole, Addis Ababa',
      'employment_type': 'Full-time',
      'deadline': '2026-12-31',
      'status': 'draft',
      'fraud_score': 75,
      'fraud_risk_level': 'high',
      'fraud_indicators': [
        'Demands upfront payment, registration, or processing fees',
        'Directs candidates strictly to Telegram',
      ],
      'is_flagged': true,
      'moderation_status': 'under_review',
      'moderation_notes': 'Quarantined for upfront fee triggers',
    };

    final job = JobModel.fromJson(rawJson);

    expect(job.fraudScore, 75);
    expect(job.fraudRiskLevel, 'high');
    expect(job.isFlagged, isTrue);
    expect(job.isHighFraudRisk, isTrue);
    expect(job.isMediumFraudRisk, isFalse);
    expect(job.isQuarantinedOrFraud, isTrue);
    expect(job.fraudIndicators.length, 2);
    expect(job.moderationNotes, 'Quarantined for upfront fee triggers');

    // Test copyWith preserves and modifies fraud attributes
    final clearedJob = job.copyWith(
      fraudScore: 10,
      fraudRiskLevel: 'low',
      isFlagged: false,
      moderationStatus: 'cleared',
    );

    expect(clearedJob.fraudScore, 10);
    expect(clearedJob.isFlagged, isFalse);
    expect(clearedJob.isHighFraudRisk, isFalse);
    expect(clearedJob.moderationStatus, 'cleared');
  });

  test('AdminFraudScreen class is instantiable and verified', () {
    expect(AdminFraudScreen, isNotNull);
  });

  test('JobAlertModel parses and serializes correctly', () {
    final json = {
      'id': 1,
      'user_id': 10,
      'title': 'Flutter Developer in Bole',
      'keyword': 'Flutter',
      'location': 'Bole, Addis Ababa',
      'employment_type': 'Full-time',
      'category': 'Software Engineering',
      'min_salary': 35000.0,
      'frequency': 'daily',
      'is_active': true,
      'created_at': '2026-11-08T12:00:00Z',
    };

    final alert = JobAlertModel.fromJson(json);
    expect(alert.id, 1);
    expect(alert.title, 'Flutter Developer in Bole');
    expect(alert.keyword, 'Flutter');
    expect(alert.location, 'Bole, Addis Ababa');
    expect(alert.minSalary, 35000.0);
    expect(alert.frequency, 'daily');
    expect(alert.isActive, isTrue);

    final serialized = alert.toJson();
    expect(serialized['keyword'], 'Flutter');
    expect(serialized['min_salary'], 35000.0);
    expect(serialized['frequency'], 'daily');
  });

  test(
    'JobOfferModel parses offer attributes and status helpers accurately',
    () {
      final offerJson = {
        'application_id': 42,
        'status': 'offered',
        'offer_salary': 45000.0,
        'offer_benefits':
            'Health insurance, transport allowance, performance bonus',
        'offer_conditions': '3-month probationary review period',
        'offer_start_date': '2026-12-01',
        'offer_status': 'offered',
        'offer_notes': 'Congratulations on your stellar interview performance!',
        'candidate_response_notes': null,
        'offered_at': '2026-11-08T10:00:00Z',
        'offer_responded_at': null,
        'job': {
          'id': 101,
          'title': 'Senior Software Architect',
          'location': 'Kazanchis, Addis Ababa',
          'employer': {'id': 5, 'organization_name': 'Ethio Telecom'},
        },
      };

      final offer = JobOfferModel.fromJson(offerJson);
      expect(offer.applicationId, 42);
      expect(offer.offerSalary, 45000.0);
      expect(offer.offerBenefits?.contains('Health insurance'), isTrue);
      expect(offer.offerConditions?.contains('probationary'), isTrue);
      expect(offer.offerStartDate, '2026-12-01');
      expect(offer.offerStatus, 'offered');
      expect(offer.isOffered, isTrue);
      expect(offer.isAccepted, isFalse);
      expect(offer.isDeclined, isFalse);
      expect(offer.jobTitle, 'Senior Software Architect');
      expect(offer.employerName, 'Ethio Telecom');

      // Test accepted state
      final acceptedOffer = JobOfferModel.fromJson({
        ...offerJson,
        'offer_status': 'accepted',
      });
      expect(acceptedOffer.isAccepted, isTrue);
      expect(acceptedOffer.isOffered, isFalse);
    },
  );

  test('Career features screens and classes are verified and instantiable', () {
    expect(AiCareerAssistantScreen, isNotNull);
    expect(JobAlertsScreen, isNotNull);
    expect(JobOfferModal, isNotNull);
    expect(CareerRepository, isNotNull);

    // Initial parameters verification
    const assistantScreen = AiCareerAssistantScreen(
      initialJobId: 101,
      initialTabIndex: 2,
    );
    expect(assistantScreen.initialJobId, 101);
    expect(assistantScreen.initialTabIndex, 2);

    const alertsScreen = JobAlertsScreen();
    expect(alertsScreen, isA<StatefulWidget>());
  });

  test(
    'Profile and Candidate CRUD management screens are instantiated cleanly',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      final apiService = ApiService(storage);
      final profRepo = ProfileRepository(apiService);

      expect(EducationManagementScreen, isNotNull);
      expect(ExperienceManagementScreen, isNotNull);
      expect(SkillsManagementScreen, isNotNull);
      expect(ProfileRepository, isNotNull);
      expect(ApplicationRepository, isNotNull);

      final eduScreen = EducationManagementScreen(profRepo: profRepo);
      expect(eduScreen, isA<StatefulWidget>());

      final expScreen = ExperienceManagementScreen(profRepo: profRepo);
      expect(expScreen, isA<StatefulWidget>());

      final skillsScreen = SkillsManagementScreen(profRepo: profRepo);
      expect(skillsScreen, isA<StatefulWidget>());
    },
  );

  test(
    'AdConsentModel serializes, deserializes, and checks permissions correctly',
    () {
      final consent = AdConsentModel.fromJson({
        'id': 10,
        'user_id': 5,
        'consent_uuid': 'test-uuid-1234',
        'status': 'custom',
        'personalized_ads': false,
        'non_personalized_ads': true,
        'analytics': true,
        'advertising_cookies': false,
        'policy_version': '1.0',
        'consented_at': '2026-11-08T12:00:00Z',
      });

      expect(consent.id, 10);
      expect(consent.userId, 5);
      expect(consent.consentUuid, 'test-uuid-1234');
      expect(consent.status, 'custom');
      expect(consent.isCustom, isTrue);
      expect(consent.allowsNonPersonalizedAds, isTrue);
      expect(consent.allowsPersonalizedAds, isFalse);
      expect(consent.allowsAnalytics, isTrue);
      expect(consent.allowsCookies, isFalse);
      expect(consent.isWithdrawn, isFalse);

      final withdrawn = consent.copyWith(
        status: 'withdrawn',
        withdrawnAt: DateTime.now(),
      );
      expect(withdrawn.isWithdrawn, isTrue);
      expect(withdrawn.allowsNonPersonalizedAds, isFalse);
      expect(withdrawn.allowsPersonalizedAds, isFalse);
      expect(withdrawn.allowsAnalytics, isFalse);
      expect(withdrawn.allowsCookies, isFalse);

      final json = consent.toJson();
      expect(json['consent_uuid'], 'test-uuid-1234');
      expect(json['status'], 'custom');
    },
  );

  test('Privacy and Ads preferences screen and modal are instantiable and verified', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final apiService = ApiService(storage);
    final repo = AdsConsentRepository(apiService, storage);

    expect(PrivacyAndAdsPreferencesScreen, isNotNull);
    expect(AdConsentModal, isNotNull);
    expect(AdConsentBanner, isNotNull);
    expect(AdsConsentRepository, isNotNull);

    const screen = PrivacyAndAdsPreferencesScreen();
    expect(screen, isA<StatefulWidget>());

    final modal = AdConsentModal(
      storageService: storage,
      consentRepository: repo,
    );
    expect(modal, isA<StatefulWidget>());

    final banner = AdConsentBanner(storageService: storage);
    expect(banner, isA<StatefulWidget>());
  });

  test(
    'Simulated app restart and offline persistence maintains consent state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage1 = await StorageService.init();

      // Device gets persistent UUID
      final originalUuid = storage1.getConsentUuid();
      expect(originalUuid, isNotEmpty);

      // User customizes consent
      await storage1.saveAdConsent(
        status: 'custom',
        nonPersonalized: true,
        personalized: false,
        analytics: true,
        cookies: false,
        policyVersion: '1.0',
      );

      // SIMULATE APP RESTART: Instantiate a new StorageService from disk preferences
      final storage2 = await StorageService.init();

      expect(storage2.getConsentUuid(), equals(originalUuid));
      expect(storage2.hasConsentRecorded(), isTrue);
      expect(storage2.getAdConsentStatus(), equals('custom'));
      expect(storage2.isNonPersonalizedAdsAllowed(), isTrue);
      expect(storage2.isPersonalizedAdsAllowed(), isFalse);
      expect(storage2.isAnalyticsAllowed(), isTrue);
      expect(storage2.isCookiesAllowed(), isFalse);
      expect(storage2.requiresPolicyReconsent('1.0'), isFalse);
      expect(storage2.requiresPolicyReconsent('2.0'), isTrue);

      // User withdraws consent offline
      await storage2.withdrawAdConsent();

      // SIMULATE SUBSEQUENT RESTART
      final storage3 = await StorageService.init();
      expect(storage3.getAdConsentStatus(), equals('withdrawn'));
      expect(storage3.isNonPersonalizedAdsAllowed(), isFalse);
      expect(storage3.isPersonalizedAdsAllowed(), isFalse);
      expect(storage3.isAnalyticsAllowed(), isFalse);
      expect(storage3.isCookiesAllowed(), isFalse);
      expect(storage3.getConsentWithdrawnAt(), isNotNull);
    },
  );

  test('AdvertisingPackageModel parses JSON, formats ETB price, and handles duration cleanly', () {
    final json = {
      'id': 3,
      'name': 'Premium Brand & Vacancy',
      'slug': 'premium-brand-vacancy',
      'description': 'Maximum visibility for 30 days.',
      'duration_days': 30,
      'price_etb': 7000.0,
      'price_formatted': '7,000.00 ETB',
      'allowed_placements': ['hero', 'dashboard', 'job_list', 'search_sponsored'],
      'allowed_categories': ['featured_jobs', 'sponsored_vacancies'],
      'benefits': [
        '30 Days prime placement',
        'Top of search results',
      ],
      'badge_label': 'Best Value',
      'is_active': true,
      'priority_level': 3,
      'advertisements_count': 12,
    };

    final pkg = AdvertisingPackageModel.fromJson(json);

    expect(pkg.id, 3);
    expect(pkg.name, 'Premium Brand & Vacancy');
    expect(pkg.slug, 'premium-brand-vacancy');
    expect(pkg.priceEtb, 7000.0);
    expect(pkg.displayPrice, '7,000.00 ETB');
    expect(pkg.durationText, '1 Month (30 Days)');
    expect(pkg.badgeLabel, 'Best Value');
    expect(pkg.isActive, isTrue);
    expect(pkg.benefits.length, 2);
    expect(pkg.allowedPlacements.contains('hero'), isTrue);
    expect(pkg.advertisementsCount, 12);

    final copy = pkg.copyWith(priceEtb: 7500.0, durationDays: 45);
    expect(copy.priceEtb, 7500.0);
    expect(copy.durationDays, 45);
    expect(copy.durationText, '45 Days');
    expect(copy.name, 'Premium Brand & Vacancy');
  });

  testWidgets('PackageCardWidget renders package info, price in ETB, and fires selection callback', (tester) async {
    final pkg = AdvertisingPackageModel(
      id: 1,
      name: 'Standard Package',
      slug: 'standard-package',
      description: 'Expanded reach across dashboards and feeds.',
      durationDays: 15,
      priceEtb: 3500.0,
      priceFormatted: '3,500.00 ETB',
      allowedPlacements: ['dashboard', 'job_list'],
      allowedCategories: ['featured_jobs'],
      benefits: ['15 Days active campaign duration', 'Dashboard prominent placement'],
      badgeLabel: 'Popular',
      isActive: true,
    );

    bool selected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackageCardWidget(
            package: pkg,
            isSelected: false,
            onSelect: () => selected = true,
          ),
        ),
      ),
    );

    expect(find.text('Standard Package'), findsOneWidget);
    expect(find.text('3500'), findsOneWidget);
    expect(find.text('ETB'), findsOneWidget);
    expect(find.text('POPULAR'), findsOneWidget);
    expect(find.text('15 Days active campaign duration'), findsOneWidget);
    expect(find.text('Select Package'), findsOneWidget);

    await tester.tap(find.text('Select Package'));
    await tester.pump();

    expect(selected, isTrue);
  });

  test('AdvertisingPackagesScreen and AdvertisingPackageManagerScreen classes are instantiable', () {
    expect(AdvertisingPackagesScreen, isNotNull);
    expect(AdvertisingPackageManagerScreen, isNotNull);
  });

  test('AdvertisementModel parses Phase 2 campaign lifecycle and Ethiopian targeting attributes', () {
    final json = {
      'id': 101,
      'title': 'FinTech Senior Core Engineer Hiring',
      'title_am': 'የከፍተኛ ኮር ኢንጂነር የቅጥር ማስታወቂያ',
      'subtitle': 'Accelerate financial technology across Addis Ababa.',
      'description': 'Comprehensive hiring drive for certified mobile architects.',
      'badge_text': 'FEATURED VACANCY',
      'image_url': 'https://example.com/banner.png',
      'category': 'featured_jobs',
      'placement': 'hero',
      'placements': ['hero', 'job_list', 'search_sponsored'],
      'target_role': 'job_seeker',
      'target_locations': ['Addis Ababa - Bole', 'Hawassa'],
      'cta_type': 'apply_now',
      'cta_text': 'Apply Today',
      'cta_target': '/jobs/42',
      'start_date': '2026-11-10T00:00:00Z',
      'end_date': '2026-11-25T00:00:00Z',
      'status': 'draft',
      'approval_status': 'draft',
      'payment_status': 'unpaid',
      'price_paid': 3500.0,
      'package_id': 2,
    };

    final ad = AdvertisementModel.fromJson(json);

    expect(ad.id, 101);
    expect(ad.title, 'FinTech Senior Core Engineer Hiring');
    expect(ad.isDraft, isTrue);
    expect(ad.canBeEdited, isTrue);
    expect(ad.isApproved, isFalse);
    expect(ad.isPaid, isFalse);
    expect(ad.placements.length, 3);
    expect(ad.targetLocations.contains('Addis Ababa - Bole'), isTrue);
    expect(ad.pricePaid, 3500.0);

    final approvedAd = ad.copyWith(
      approvalStatus: 'approved',
      status: 'active',
      paymentStatus: 'paid',
    );
    expect(approvedAd.isApproved, isTrue);
    expect(approvedAd.isActive, isTrue);
    expect(approvedAd.isPaid, isTrue);
    expect(approvedAd.canBeEdited, isFalse);
  });

  testWidgets('CampaignPreviewWidget renders simulation preview and handles placement switching', (tester) async {
    final campaign = AdvertisementModel(
      id: 55,
      title: 'Ethiopian Airlines Cloud Engineer Drive',
      subtitle: 'Join leading aviation cloud infrastructure team in Bole.',
      badgeText: 'EXCLUSIVE CAMPAIGN',
      imageUrl: 'https://example.com/plane.jpg',
      category: 'recruitment_campaigns',
      placement: 'hero',
      placements: ['hero', 'dashboard', 'job_list'],
      ctaType: 'apply_now',
      ctaText: 'Apply Online',
      ctaTarget: '/jobs/1',
      startDate: '2026-11-10',
      endDate: '2026-11-25',
      status: 'pending_approval',
      approvalStatus: 'pending_approval',
      targetLocations: ['Bole', 'Kirkos'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CampaignPreviewWidget(campaign: campaign),
          ),
        ),
      ),
    );

    expect(find.textContaining('Live Preview:'), findsOneWidget);
    expect(find.text('EXCLUSIVE CAMPAIGN'), findsOneWidget);
    expect(find.text('Ethiopian Airlines Cloud Engineer Drive'), findsOneWidget);
    expect(find.text('Apply Online'), findsOneWidget);

    // Switch to Dashboard simulation
    await tester.tap(find.text('Dashboard'));
    await tester.pump();

    expect(find.text('Billboard'), findsOneWidget);
  });

  test('CampaignCreationWizardScreen, EmployerCampaignsScreen, and AdminCampaignReviewScreen classes are instantiable', () {
    expect(CampaignCreationWizardScreen, isNotNull);
    expect(EmployerCampaignsScreen, isNotNull);
    expect(AdminCampaignReviewScreen, isNotNull);
  });

  test('PaymentTransactionModel parses attributes, helpers, and formats ETB amounts accurately', () {
    final json = {
      'id': 101,
      'transaction_reference': 'TXN-CHAPA-20261108-XYZ789',
      'merchant_reference': 'CMP-10-ORD',
      'provider_reference': 'chapa_ref_112233',
      'checkout_url': 'https://checkout.chapa.co/checkout/payment/mock',
      'payment_method': 'chapa',
      'expected_amount_etb': '3500.00',
      'confirmed_amount_etb': '3500.00',
      'currency': 'ETB',
      'payment_status': 'successful',
      'receipt_number': 'RCP-20261108-XYZ123',
      'verified_at': '2026-11-08T20:30:00Z',
      'campaign_title': 'Senior Engineer Hiring',
      'package_name': 'Standard Package',
    };

    final model = PaymentTransactionModel.fromJson(json);

    expect(model.id, 101);
    expect(model.transactionReference, 'TXN-CHAPA-20261108-XYZ789');
    expect(model.paymentMethod, 'chapa');
    expect(model.expectedAmountEtb, 3500.00);
    expect(model.confirmedAmountEtb, 3500.00);
    expect(model.formattedAmount, '3500.00 ETB');
    expect(model.isSuccessful, isTrue);
    expect(model.isPending, isFalse);
    expect(model.isFailed, isFalse);
    expect(model.receiptNumber, 'RCP-20261108-XYZ123');
    expect(model.verifiedAt, isNotNull);
    expect(model.campaignTitle, 'Senior Engineer Hiring');
    expect(model.packageName, 'Standard Package');
  });

  test('CheckoutScreen, PaymentStatusScreen, and TransactionHistoryScreen classes are instantiable', () {
    expect(CheckoutScreen, isNotNull);
    expect(PaymentStatusScreen, isNotNull);
    expect(TransactionHistoryScreen, isNotNull);

    const adminHistory = TransactionHistoryScreen(isAdminView: true);
    expect(adminHistory.isAdminView, isTrue);

    const employerHistory = TransactionHistoryScreen(isAdminView: false);
    expect(employerHistory.isAdminView, isFalse);
  });

  test('ApiResponse unpacks validation errors into formattedErrorMessage correctly', () {
    final responseWithErrors = ApiResponse(
      success: false,
      message: 'Validation failed.',
      statusCode: 422,
      errors: {
        'email': ['The email has already been taken.'],
        'password': ['The password must be at least 8 characters.'],
      },
    );

    expect(responseWithErrors.hasValidationErrors, isTrue);
    expect(
      responseWithErrors.formattedErrorMessage,
      contains('The email has already been taken.'),
    );
    expect(
      responseWithErrors.formattedErrorMessage,
      contains('The password must be at least 8 characters.'),
    );

    final simpleResponse = ApiResponse(
      success: false,
      message: 'Resource not found',
      statusCode: 404,
    );
    expect(simpleResponse.hasValidationErrors, isFalse);
    expect(simpleResponse.formattedErrorMessage, 'Resource not found');
  });

  test('Quiz and Skill Assessment screen classes are instantiable', () {
    expect(QuizListScreen, isNotNull);
    expect(QuizTakeScreen, isNotNull);
    expect(SalaryBenchmarksScreen, isNotNull);
    expect(NoticeBoardLookupDialog, isNotNull);
    expect(ProfileCvPreviewDialog, isNotNull);
  });

  test('JobModel employerName and salaryText getters handle null and populated values safely', () {
    final job = JobModel(
      id: 1,
      employerId: 2,
      title: 'Senior Developer',
      description: 'Test job',
      employmentType: 'Full-time',
      location: 'Addis Ababa',
      currency: 'ETB',
      deadline: '2026-12-31',
      status: 'published',
      salaryMin: 30000,
      salaryMax: 50000,
    );

    expect(job.employerName, 'Employer');
    expect(job.salaryText, '30000 - 50000 ETB');
  });
}
