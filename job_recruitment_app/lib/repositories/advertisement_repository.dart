import '../core/constants/api_constants.dart';
import '../models/advertisement_model.dart';
import '../services/api_service.dart';

class AdvertisementRepository {
  final ApiService _apiService;
  String? lastErrorMessage;

  AdvertisementRepository(this._apiService);

  /// Fetch active public advertisements with optional placement, category and privacy consent filters
  Future<List<AdvertisementModel>> getAdvertisements({
    String? placement,
    String? category,
    bool? personalized,
  }) async {
    final Map<String, String> params = {};
    if (placement != null && placement.isNotEmpty) {
      params['placement'] = placement;
    }
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    if (personalized != null) {
      params['personalized'] = personalized ? '1' : '0';
    }

    final response = await _apiService.get(
      ApiConstants.advertisements,
      queryParams: params,
    );
    if (response.success && response.data is List) {
      return (response.data as List)
          .map(
            (json) => AdvertisementModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  /// Fire an impression event
  Future<bool> recordImpression(int adId) async {
    final response = await _apiService.post(ApiConstants.adImpression(adId));
    return response.success;
  }

  /// Fire a click event
  Future<bool> recordClick(int adId) async {
    final response = await _apiService.post(ApiConstants.adClick(adId));
    return response.success;
  }

  /// Admin: Fetch all campaigns
  Future<List<AdvertisementModel>> getAdminAdvertisements({
    String? status,
    String? placement,
    String? category,
  }) async {
    final Map<String, String> params = {};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (placement != null && placement.isNotEmpty) {
      params['placement'] = placement;
    }
    if (category != null && category.isNotEmpty) params['category'] = category;

    final response = await _apiService.get(
      ApiConstants.adminAdvertisements,
      queryParams: params,
    );
    if (response.success && response.data is List) {
      return (response.data as List)
          .map(
            (json) => AdvertisementModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }
    return [];
  }

  /// Admin: Fetch analytics
  Future<Map<String, dynamic>?> getAnalytics() async {
    final response = await _apiService.get(ApiConstants.adminAdAnalytics);
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  /// Admin: Toggle status
  Future<bool> toggleStatus(int id, String status) async {
    final response = await _apiService.patch(ApiConstants.adminAdStatus(id), {
      'status': status,
    });
    return response.success;
  }

  /// Admin: Create advertisement
  Future<AdvertisementModel?> createAdvertisement(
    Map<String, dynamic> data,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.adminAdvertisements,
      data,
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisementModel.fromJson(response.data as Map<String, dynamic>);
    }
    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to create advertisement campaign.';
    return null;
  }

  /// Admin: Update advertisement
  Future<AdvertisementModel?> updateAdvertisement(
    int id,
    Map<String, dynamic> data,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.put(
      ApiConstants.adminAdDetail(id),
      data,
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisementModel.fromJson(response.data as Map<String, dynamic>);
    }
    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to update advertisement campaign.';
    return null;
  }

  /// Admin: Delete campaign
  Future<bool> deleteAdvertisement(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.delete(ApiConstants.adminAdDetail(id));
    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to delete advertisement campaign.';
    }
    return response.success;
  }
}
