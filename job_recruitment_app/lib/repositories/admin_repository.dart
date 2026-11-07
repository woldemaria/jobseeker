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
    final response = await _apiService.patch(
      ApiConstants.adminUserStatus(id),
      {'status': status},
    );
    return response.success;
  }

  Future<List<Map<String, dynamic>>> getVerifications() async {
    final response = await _apiService.get(ApiConstants.adminVerifications);
    if (response.success && response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<bool> reviewVerification(int id, String status, {String? notes}) async {
    final response = await _apiService.patch(
      ApiConstants.adminReviewVerification(id),
      {
        'status': status,
        if (notes != null && notes.isNotEmpty) 'review_notes': notes,
      },
    );
    return response.success;
  }

  Future<List<Map<String, dynamic>>> getReports() async {
    final response = await _apiService.get(ApiConstants.adminReports);
    if (response.success && response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
