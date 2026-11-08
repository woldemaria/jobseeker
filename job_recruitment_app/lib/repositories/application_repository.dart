import '../models/application_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_constants.dart';

class ApplicationRepository {
  final ApiService _apiService;

  ApplicationRepository(this._apiService);

  Future<ApiResponse> submitApplication({
    required int jobId,
    required int cvDocumentId,
    String? coverLetter,
  }) async {
    return await _apiService.post('${ApiConstants.jobs}/$jobId/applications', {
      'cv_document_id': cvDocumentId,
      'cover_letter': coverLetter,
    });
  }

  Future<List<ApplicationModel>> getMyApplications() async {
    final response = await _apiService.get(ApiConstants.applications);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((a) => ApplicationModel.fromJson(a))
          .toList();
    }
    return [];
  }

  Future<ApplicationModel?> getApplicationDetails(int id) async {
    final response = await _apiService.get('${ApiConstants.applications}/$id');
    if (response.success && response.data != null) {
      return ApplicationModel.fromJson(response.data);
    }
    return null;
  }

  Future<ApiResponse> updateStatus(
    int applicationId,
    String status, {
    String? notes,
  }) async {
    return await _apiService.patch(
      '${ApiConstants.applications}/$applicationId/status',
      {'status': status, 'notes': notes},
    );
  }

  Future<ApiResponse> withdrawApplication(int applicationId) async {
    return await _apiService.post(
      '${ApiConstants.applications}/$applicationId/withdraw',
      {},
    );
  }

  Future<ApiResponse> scheduleInterview({
    required int applicationId,
    required String interviewAt,
    required String interviewType,
    required String interviewLocation,
    String? interviewNotes,
  }) async {
    return await _apiService.post(
      '${ApiConstants.applications}/$applicationId/interview',
      {
        'interview_at': interviewAt,
        'interview_type': interviewType,
        'interview_location': interviewLocation,
        'interview_notes': interviewNotes,
      },
    );
  }

  Future<ApiResponse> confirmInterview(int applicationId) async {
    return await _apiService.post(
      '${ApiConstants.applications}/$applicationId/interview/confirm',
      {},
    );
  }

  Future<ApiResponse> rescheduleInterview({
    required int applicationId,
    String? interviewAt,
    String? reason,
  }) async {
    return await _apiService.post(
      '${ApiConstants.applications}/$applicationId/interview/reschedule',
      {'interview_at': interviewAt, 'reason': reason},
    );
  }

  Future<ApiResponse> createJobOffer({
    required int applicationId,
    required double salary,
    required String startDate,
    String? benefits,
    String? conditions,
    String? notes,
  }) async {
    return await _apiService.post(
      '${ApiConstants.applications}/$applicationId/offer',
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
}
