import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiConstants {
  static String _customBaseUrl = '';

  static void setBaseUrl(String url) {
    _customBaseUrl = url;
  }

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return 'http://$host:8000/api/v1';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api/v1';
      } else if (Platform.isIOS) {
        return 'http://127.0.0.1:8000/api/v1';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000/api/v1';
  }

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String user = '/auth/user';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Profile
  static const String profile = '/profile';
  static const String profilePhoto = '/profile/photo';
  static const String skills = '/skills';
  static const String profileSkills = '/profile/skills';
  static const String profileEducation = '/profile/education';
  static const String profileExperience = '/profile/experience';

  // Jobs, Categories & Ethiopian Standard Titles
  static const String categories = '/categories';
  static const String jobTitles = '/job-titles';
  static const String jobTitleSuggestions = '/job-titles/suggestions';
  static const String jobs = '/jobs';
  static const String searchJobs = '/jobs/search';
  static const String savedJobs = '/saved-jobs';

  // Applications & Job Offers (Section 11)
  static const String applications = '/applications';
  static String applicationOffer(int id) => '/applications/$id/offer';
  static String applicationOfferRespond(int id) =>
      '/applications/$id/offer/respond';

  // Custom Job Alerts (Section 6)
  static const String jobAlerts = '/job-alerts';
  static String jobAlertToggle(int id) => '/job-alerts/$id/toggle';
  static String jobAlertMatches(int id) => '/job-alerts/$id/matches';

  // AI Career Assistant & Skill-Gap (Section 8 & 14)
  static const String careerAssistantAsk = '/career-assistant/ask';
  static const String careerAssistantCoverLetter =
      '/career-assistant/cover-letter';
  static const String careerAssistantInterviewPractice =
      '/career-assistant/interview-practice';
  static String careerAssistantSkillGap(int jobId) =>
      '/career-assistant/skill-gap/$jobId';

  // Chat & Community Groups
  static const String chatGroups = '/chat/groups';

  // Recommendations & Matching
  static const String recommendations = '/recommendations/jobs';

  // Employer
  static const String employers = '/employers';
  static const String employerProfile = '/employers/profile';
  static const String employerVerification = '/employers/verification';
  static const String employerJobs = '/employers/jobs';

  // Documents
  static const String documents = '/documents';

  // Notifications
  static const String notifications = '/notifications';
  static const String markAllNotificationsRead = '/notifications/read-all';

  // Reports & Fraud Detection
  static const String reports = '/reports';
  static const String checkJobFraud = '/jobs/check-fraud';
  static String jobFraudAssessment(int id) => '/jobs/$id/fraud-assessment';

  // Advertisements
  static const String advertisements = '/advertisements';
  static String adImpression(int id) => '/advertisements/$id/impression';
  static String adClick(int id) => '/advertisements/$id/click';

  // Ads & Privacy Consent
  static const String adsConsent = '/ads-consent';
  static const String adsConsentWithdraw = '/ads-consent/withdraw';
  static const String adsConsentSync = '/ads-consent/sync';
  static const String adsConsentHistory = '/ads-consent/history';

  // Admin Routes
  static const String adminUsers = '/admin/users';
  static String adminUserStatus(int id) => '/admin/users/$id/status';
  static const String adminVerifications = '/admin/verifications';
  static String adminReviewVerification(int id) => '/admin/verifications/$id';
  static const String adminStatistics = '/admin/statistics';
  static const String adminReports = '/admin/reports';
  static String adminModerateReport(int id) => '/admin/reports/$id';
  static const String adminFraudJobs = '/admin/fraud-jobs';
  static String adminModerateJob(int id) => '/admin/fraud-jobs/$id/moderate';
  static const String adminFraudScan = '/admin/fraud-scan';
  static const String adminAdvertisements = '/admin/advertisements';
  static const String adminAdAnalytics = '/admin/advertisements/analytics';
  static String adminAdStatus(int id) => '/admin/advertisements/$id/status';
  static String adminAdDetail(int id) => '/admin/advertisements/$id';
}
