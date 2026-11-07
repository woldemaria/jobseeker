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
      return 'http://127.0.0.1:8000/api/v1';
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

  // Applications
  static const String applications = '/applications';

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

  // Reports
  static const String reports = '/reports';

  // Advertisements
  static const String advertisements = '/advertisements';
  static String adImpression(int id) => '/advertisements/$id/impression';
  static String adClick(int id) => '/advertisements/$id/click';

  // Admin Routes
  static const String adminUsers = '/admin/users';
  static String adminUserStatus(int id) => '/admin/users/$id/status';
  static const String adminVerifications = '/admin/verifications';
  static String adminReviewVerification(int id) => '/admin/verifications/$id';
  static const String adminStatistics = '/admin/statistics';
  static const String adminReports = '/admin/reports';
  static const String adminAdvertisements = '/admin/advertisements';
  static const String adminAdAnalytics = '/admin/advertisements/analytics';
  static String adminAdStatus(int id) => '/admin/advertisements/$id/status';
  static String adminAdDetail(int id) => '/admin/advertisements/$id';
}
