import '../core/constants/api_constants.dart';
import '../services/api_service.dart';

class AdminRepository {
  final ApiService _apiService;

  AdminRepository(this._apiService);

  Future<Map<String, dynamic>?> getStatistics() async {
    final response = await _apiService.get(ApiConstants.adminStatistics);
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsers({int page = 1}) async {
    final response = await _apiService.get(
      ApiConstants.adminUsers,
      queryParams: {'page': page.toString()},
    );
    if (response.success && response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> updateUserStatus(int id, String status) async {
    final response = await _apiService.patch(ApiConstants.adminUserStatus(id), {
      'status': status,
    });
    return response.success;
  }

  Future<List<Map<String, dynamic>>> getVerifications() async {
    final response = await _apiService.get(ApiConstants.adminVerifications);
    if (response.success && response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> reviewVerification(
    int id,
    String status, {
    String? notes,
  }) async {
    final response = await _apiService.patch(
      ApiConstants.adminReviewVerification(id),
      {
        'status': status,
        if (notes != null && notes.isNotEmpty) 'review_notes': notes,
      },
    );
    return response.success;
  }

  Future<List<Map<String, dynamic>>> getReports({String? status}) async {
    final Map<String, String> params = {};
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _apiService.get(
      ApiConstants.adminReports,
      queryParams: params,
    );
    if (response.success && response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> moderateReport(int id, String action, {String? notes}) async {
    final response = await _apiService.patch(
      ApiConstants.adminModerateReport(id),
      {'action': action, if (notes != null && notes.isNotEmpty) 'notes': notes},
    );
    return response.success;
  }

  Future<Map<String, dynamic>> getFraudJobs({
    String? riskLevel,
    String? moderationStatus,
    String? search,
    int page = 1,
  }) async {
    final Map<String, String> params = {'page': page.toString()};
    if (riskLevel != null && riskLevel.isNotEmpty && riskLevel != 'all') {
      params['risk_level'] = riskLevel;
    }
    if (moderationStatus != null &&
        moderationStatus.isNotEmpty &&
        moderationStatus != 'all') {
      params['moderation_status'] = moderationStatus;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final response = await _apiService.get(
      ApiConstants.adminFraudJobs,
      queryParams: params,
    );
    if (response.success && response.data is List) {
      return {
        'items': (response.data as List).cast<Map<String, dynamic>>(),
        'meta': response.meta ?? {},
      };
    }
    return {'items': <Map<String, dynamic>>[], 'meta': {}};
  }

  Future<bool> moderateJob(int id, String action, {String? notes}) async {
    final response = await _apiService.post(ApiConstants.adminModerateJob(id), {
      'action': action,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return response.success;
  }

  Future<Map<String, dynamic>?> runFraudScan() async {
    final response = await _apiService.post(ApiConstants.adminFraudScan, {});
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }
}
