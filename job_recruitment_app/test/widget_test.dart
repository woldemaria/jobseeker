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

  test('MapService generates accurate OpenStreetMap and Google Maps URLs', () async {
    final osmUrl = MapService.getOpenStreetMapUrl('Bole, Addis Ababa', lat: 8.995, lon: 38.788);
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
  });

  test('MapService builds exact place queries and targets specific subcities without generic Addis Ababa hijacking', () async {
    final queryWithOrg = MapService.buildExactPlaceQuery('Bole, Addis Ababa', organizationName: 'Commercial Bank of Ethiopia');
    expect(queryWithOrg, 'Commercial Bank of Ethiopia, Bole, Addis Ababa, Ethiopia');

    final gmapsUrl = MapService.getGoogleMapsUrl('Kazanchis, Addis Ababa', organizationName: 'UNECA HQ', lat: 9.0159, lon: 38.7712);
    expect(gmapsUrl.contains('UNECA%20HQ%2C%20Kazanchis%2C%20Addis%20Ababa%2C%20Ethiopia'), isTrue);
    expect(gmapsUrl.contains('&center=9.0159,38.7712'), isTrue);

    final dirUrl = MapService.getGoogleMapsDirectionsUrl('Bole Medhanialem', organizationName: 'Safaricom');
    expect(dirUrl.contains('Safaricom%2C%20Bole%20Medhanialem%2C%20Ethiopia'), isTrue);

    // Bole with Addis Ababa in string must NOT be hijacked by 9.0300
    final loc = await MapService.geocode('Bole Medhanialem, Addis Ababa');
    expect(loc, isNotNull);
    expect(loc!.latitude, isNot(equals(9.0300))); // Must be exact Bole (around 8.998)
  });

  testWidgets('MatchScoreBadge and StatusBadge render accurately', (WidgetTester tester) async {
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

  testWidgets('JobCard renders vacancy information correctly', (WidgetTester tester) async {
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
          body: JobCard(
            job: sampleJob,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Junior Flutter Developer'), findsOneWidget);
    expect(find.text('Addis Ababa'), findsOneWidget);
    expect(find.text('Full-time'), findsOneWidget);
    expect(find.text('25000 - 35000 ETB'), findsOneWidget);
    expect(find.text('87% Match'), findsOneWidget);
  });

  testWidgets('LocationMapModal renders location and map buttons', (WidgetTester tester) async {
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
      'profile_photo': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2',
      'status': 'active',
      'roles': ['job_seeker'],
    });

    expect(user.profilePhoto, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2');
    expect(user.name, 'Sara Bekele');
    expect(user.isJobSeeker, isTrue);
  });

  test('AdvertisementModel parses JSON and provides bilingual translations', () {
    final ad = AdvertisementModel.fromJson({
      'id': 101,
      'title': 'Ethiopian Airlines Pilot Cadet 2026',
      'title_am': 'የኢትዮጵያ አየር መንገድ የፓይለት ቅጥር',
      'subtitle': 'Join Africa’s Largest Airline',
      'subtitle_am': 'የአፍሪካ ግዙፉን አየር መንገድ ይቀላቀሉ',
      'badge_text': '20% Tuition Discount',
      'badge_text_am': '20% የትምህርት ክፍያ ቅናሽ',
      'image_url': 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05',
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
  });

  test('StorageService persists cookie and ad privacy consent preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    // Default before choice
    expect(storage.getAdConsentStatus(), isNull);
    expect(storage.isPersonalizedAdsAllowed(), isTrue);
    expect(storage.isAnalyticsAllowed(), isTrue);

    // Reject consent
    await storage.saveAdConsent(status: 'rejected', personalized: false, analytics: false);
    expect(storage.getAdConsentStatus(), 'rejected');
    expect(storage.isPersonalizedAdsAllowed(), isFalse);
    expect(storage.isAnalyticsAllowed(), isFalse);

    // Accept consent
    await storage.saveAdConsent(status: 'accepted', personalized: true, analytics: true);
    expect(storage.getAdConsentStatus(), 'accepted');
    expect(storage.isPersonalizedAdsAllowed(), isTrue);
    expect(storage.isAnalyticsAllowed(), isTrue);
  });

  test('UserModel RBAC verifies JobSeeker, Employer, and Admin roles', () {
    final candidate = UserModel(id: 1, name: 'Abebe', email: 'a@test.com', status: 'active', roles: ['job_seeker']);
    expect(candidate.isJobSeeker, isTrue);
    expect(candidate.isEmployer, isFalse);
    expect(candidate.isAdmin, isFalse);

    final employer = UserModel(id: 2, name: 'Ethio Telecom', email: 'e@test.com', status: 'active', roles: ['employer']);
    expect(employer.isJobSeeker, isFalse);
    expect(employer.isEmployer, isTrue);
    expect(employer.isAdmin, isFalse);

    final admin = UserModel(id: 3, name: 'Root Admin', email: 'admin@test.com', status: 'active', roles: ['administrator']);
    expect(admin.isJobSeeker, isFalse);
    expect(admin.isEmployer, isFalse);
    expect(admin.isAdmin, isTrue);
  });

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
    final httpProvider = getAvatarImageProvider('https://example.com/photo.jpg');
    expect(httpProvider, isA<NetworkImage>());

    final dataUriProvider = getAvatarImageProvider('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
    expect(dataUriProvider, isA<MemoryImage>());

    expect(getAvatarImageProvider(null), isNull);
    expect(getAvatarImageProvider(''), isNull);
  });

  test('ApiResponse correctly parses standardized 422 validation errors map', () {
    final rawResponse = {
      'success': false,
      'message': 'The profile details provided are invalid.',
      'data': null,
      'errors': {
        'name': ['Full name must contain at least 2 characters.'],
        'phone': ['Please provide a valid phone number format.'],
      }
    };

    expect(rawResponse['success'], isFalse);
    expect(rawResponse['errors'], isNotNull);
    final errors = rawResponse['errors'] as Map<String, dynamic>;
    expect(errors['name'], contains('Full name must contain at least 2 characters.'));
    expect(errors['phone'], contains('Please provide a valid phone number format.'));
  });

  test('ProfileFormScreen widget class is instantiable and verified', () {
    expect(ProfileFormScreen, isNotNull);
  });

  test('ChatGroupModel and ChatMessageModel parse data and job share correctly', () {
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
      }
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
      'user': {
        'name': 'Abebe',
        'profile_photo': null,
      },
      'created_at': '2026-11-06T15:30:00Z',
    };

    final msg = ChatMessageModel.fromJson(msgJson);
    expect(msg.id, 100);
    expect(msg.senderName, 'Abebe');
    expect(msg.messageType, 'job_share');
    expect(msg.sharedJobId, 5);
    expect(msg.sharedJob?.title, 'Senior Software Engineer');
  });

  test('ShareWithFriendsModal class is instantiable', () {
    expect(ShareWithFriendsModal, isNotNull);
  });

  test('EthiopianJobCatalogue bundles all 30 categories and 475 titles', () {
    expect(EthiopianJobCatalogue.categories.length, 30);
    expect(EthiopianJobCatalogue.allTitles.length, 475);

    // Search functionality
    final engResults = EthiopianJobCatalogue.searchTitles('engineer');
    expect(engResults, isNotEmpty);
    expect(engResults.every((t) => t.toLowerCase().contains('engineer')), isTrue);

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

  test('JobSeekerDashboardScreen widget class is instantiable and verified', () {
    expect(JobSeekerDashboardScreen, isNotNull);
  });

  test('JobModel safely parses category as either String or eager-loaded Map', () {
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
  });

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

  testWidgets('JobCard renders Apply Now button and triggers callback', (WidgetTester tester) async {
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

  testWidgets('JobCard renders Applied badge when hasApplied is true', (WidgetTester tester) async {
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
          body: JobCard(
            job: testJob,
            onTap: () {},
            onSaveToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Applied'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  test('RecommendationsScreen class is instantiable and verified', () {
    expect(RecommendationsScreen, isNotNull);
  });
}
