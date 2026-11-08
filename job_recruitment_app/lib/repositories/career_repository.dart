import '../core/constants/api_constants.dart';
import '../models/job_alert_model.dart';
import '../models/job_model.dart';
import '../models/job_offer_model.dart';
import '../services/api_service.dart';

class CareerRepository {
  final ApiService _apiService;

  CareerRepository(this._apiService);

  // ----------------------------------------------------
  // AI Career Assistant & Guidance (Section 8)
  // ----------------------------------------------------

  /// Ask career-related questions with bilingual English & Amharic guidance
  Future<Map<String, dynamic>?> askAssistant(
    String question, {
    String locale = 'en',
  }) async {
    final response = await _apiService.post(ApiConstants.careerAssistantAsk, {
      'question': question,
      'locale': locale,
    });
    if (response.success && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  /// Generate personalized cover letter draft tailored to candidate profile and target job
  Future<Map<String, dynamic>?> generateCoverLetter(
    int jobId, {
    String tone = 'professional',
    String? customNotes,
  }) async {
    final response = await _apiService.post(
      ApiConstants.careerAssistantCoverLetter,
      {
        'job_id': jobId,
        'tone': tone,
        if (customNotes != null && customNotes.isNotEmpty)
          'custom_notes': customNotes,
      },
    );
    if (response.success && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  /// Practice interview questions with model STAR answers and coaching tips
  Future<Map<String, dynamic>?> getInterviewPractice(
    int jobId, {
    String? roleTitle,
  }) async {
    final response = await _apiService.post(
      ApiConstants.careerAssistantInterviewPractice,
      {
        'job_id': jobId,
        if (roleTitle != null && roleTitle.isNotEmpty) 'role_title': roleTitle,
      },
    );
    if (response.success && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  /// Skill-gap analysis comparing candidate profile to job requirements (Section 14)
  Future<Map<String, dynamic>?> getSkillGap(int jobId) async {
    final response = await _apiService.get(
      ApiConstants.careerAssistantSkillGap(jobId),
    );
    if (response.success && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  // ----------------------------------------------------
  // Custom Job Alerts (Section 6)
  // ----------------------------------------------------

  Future<List<JobAlertModel>> getJobAlerts() async {
    final response = await _apiService.get(ApiConstants.jobAlerts);
    if (response.success && response.data is List) {
      return (response.data as List)
          .whereType<Map>()
          .map((j) => JobAlertModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
    return [];
  }

  Future<JobAlertModel?> createJobAlert(Map<String, dynamic> data) async {
    final response = await _apiService.post(ApiConstants.jobAlerts, data);
    if (response.success && response.data is Map) {
      return JobAlertModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    return null;
  }

  Future<bool> toggleJobAlert(int id) async {
    final response = await _apiService.patch(
      ApiConstants.jobAlertToggle(id),
      {},
    );
    return response.success;
  }

  Future<bool> deleteJobAlert(int id) async {
    final response = await _apiService.delete('${ApiConstants.jobAlerts}/$id');
    return response.success;
  }

  Future<List<JobModel>> getJobAlertMatches(int alertId) async {
    final response = await _apiService.get(
      ApiConstants.jobAlertMatches(alertId),
    );
    if (response.success && response.data is List) {
      return (response.data as List)
          .whereType<Map>()
          .map((j) => JobModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
    return [];
  }

  // ----------------------------------------------------
  // Job Offer Management (Section 11)
  // ----------------------------------------------------

  Future<ApiResponse> createJobOffer({
    required int applicationId,
    required double salary,
    required String startDate,
    String? benefits,
    String? conditions,
    String? notes,
  }) async {
    return await _apiService.post(
      ApiConstants.applicationOffer(applicationId),
      {
        'offer_salary': salary,
        'offer_start_date': startDate,
        if (benefits != null && benefits.isNotEmpty) 'offer_benefits': benefits,
        if (conditions != null && conditions.isNotEmpty)
          'offer_conditions': conditions,
        if (notes != null && notes.isNotEmpty) 'offer_notes': notes,
      },
    );
  }

  Future<JobOfferModel?> getOfferDetails(int applicationId) async {
    final response = await _apiService.get(
      ApiConstants.applicationOffer(applicationId),
    );
    if (response.success && response.data is Map) {
      return JobOfferModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    }
    return null;
  }

  Future<bool> respondToOffer(
    int applicationId,
    String action, {
    String? notes,
  }) async {
    final response = await _apiService.post(
      ApiConstants.applicationOfferRespond(applicationId),
      {'action': action, if (notes != null && notes.isNotEmpty) 'notes': notes},
    );
    return response.success;
  }
}
