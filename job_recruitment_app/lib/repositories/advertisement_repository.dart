import '../core/constants/api_constants.dart';
import '../models/advertisement_model.dart';
import '../models/advertising_package_model.dart';
import '../models/payment_transaction_model.dart';
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

  // ==========================================
  // ADVERTISING PACKAGES (PHASE 1)
  // ==========================================

  /// Public / Employer: Fetch all active advertising packages
  Future<List<AdvertisingPackageModel>> getAdvertisingPackages() async {
    lastErrorMessage = null;
    final response = await _apiService.get(ApiConstants.adPackages);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map(
            (json) => AdvertisingPackageModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to fetch advertising packages.';
    return [];
  }

  /// Public / Employer: Get details of a single package
  Future<AdvertisingPackageModel?> getAdvertisingPackageDetails(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.get(ApiConstants.adPackageDetail(id));
    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisingPackageModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to load package details.';
    return null;
  }

  /// Admin: Fetch all packages including inactive and usage counts
  Future<List<AdvertisingPackageModel>> getAdminAdvertisingPackages() async {
    lastErrorMessage = null;
    final response = await _apiService.get(ApiConstants.adminAdPackages);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map(
            (json) => AdvertisingPackageModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    }
    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to fetch administration packages.';
    return [];
  }

  /// Admin: Create new advertising package
  Future<AdvertisingPackageModel?> createAdvertisingPackage(
    Map<String, dynamic> data,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.adminAdPackages,
      data,
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisingPackageModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    if (response.errors != null && response.errors!.isNotEmpty) {
      final firstVal = response.errors!.values.first;
      if (firstVal is List && firstVal.isNotEmpty) {
        lastErrorMessage = firstVal.first.toString();
      } else {
        lastErrorMessage = firstVal.toString();
      }
    } else {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to create advertising package.';
    }
    return null;
  }

  /// Admin: Update advertising package (price, duration, benefits, placements)
  Future<AdvertisingPackageModel?> updateAdvertisingPackage(
    int id,
    Map<String, dynamic> data,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.put(
      ApiConstants.adminAdPackageDetail(id),
      data,
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisingPackageModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    if (response.errors != null && response.errors!.isNotEmpty) {
      final firstVal = response.errors!.values.first;
      if (firstVal is List && firstVal.isNotEmpty) {
        lastErrorMessage = firstVal.first.toString();
      } else {
        lastErrorMessage = firstVal.toString();
      }
    } else {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to update advertising package.';
    }
    return null;
  }

  /// Admin: Quick toggle package active status
  Future<bool> toggleAdvertisingPackageStatus(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.patch(
      ApiConstants.adminAdPackageToggle(id),
      {},
    );
    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to toggle package status.';
    }
    return response.success;
  }

  /// Admin: Delete advertising package
  Future<bool> deleteAdvertisingPackage(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.delete(
      ApiConstants.adminAdPackageDetail(id),
    );
    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to delete advertising package.';
    }
    return response.success;
  }

  // ==========================================
  // CAMPAIGN CREATION & MANAGEMENT (PHASE 2)
  // ==========================================

  /// Fetch Ethiopian geographic targeting locations hierarchy
  Future<Map<String, dynamic>?> getCampaignLocations() async {
    lastErrorMessage = null;
    final response = await _apiService.get(ApiConstants.campaignLocations);
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    lastErrorMessage = response.message;
    return null;
  }

  /// Employer: Fetch own advertising campaigns with optional filters
  Future<List<AdvertisementModel>> getAdvertiserCampaigns({
    String? status,
    String? category,
  }) async {
    lastErrorMessage = null;
    final Map<String, String> params = {};
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }

    final response = await _apiService.get(
      ApiConstants.advertiserCampaigns,
      queryParams: params,
    );

    if (response.success && response.data is List) {
      return (response.data as List)
          .map(
            (json) => AdvertisementModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }

    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to fetch employer campaigns.';
    return [];
  }

  /// Employer: Get single campaign profile with daily telemetry
  Future<AdvertisementModel?> getAdvertiserCampaignDetails(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.get(
      ApiConstants.advertiserCampaignDetail(id),
    );

    if (response.success && response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      if (map['campaign'] != null && map['campaign'] is Map<String, dynamic>) {
        return AdvertisementModel.fromJson(
          map['campaign'] as Map<String, dynamic>,
        );
      }
      return AdvertisementModel.fromJson(map);
    }

    lastErrorMessage = response.message;
    return null;
  }

  /// Employer: Create campaign (draft or direct submit)
  Future<AdvertisementModel?> createCampaign(Map<String, dynamic> data) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.advertiserCampaigns,
      data,
    );

    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisementModel.fromJson(response.data as Map<String, dynamic>);
    }

    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to create campaign.';
    return null;
  }

  /// Employer: Update campaign draft or resubmit rejected campaign
  Future<AdvertisementModel?> updateCampaign(
    int id,
    Map<String, dynamic> data,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.put(
      ApiConstants.advertiserCampaignDetail(id),
      data,
    );

    if (response.success && response.data is Map<String, dynamic>) {
      return AdvertisementModel.fromJson(response.data as Map<String, dynamic>);
    }

    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Failed to update campaign.';
    return null;
  }

  /// Employer: Submit draft for administrative approval
  Future<bool> submitCampaign(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.advertiserCampaignSubmit(id),
      {},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to submit campaign for approval.';
    }
    return response.success;
  }

  /// Employer: Pause own active campaign
  Future<bool> pauseCampaign(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.advertiserCampaignPause(id),
      {},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to pause campaign.';
    }
    return response.success;
  }

  /// Employer: Resume paused campaign
  Future<bool> resumeCampaign(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.advertiserCampaignResume(id),
      {},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to resume campaign.';
    }
    return response.success;
  }

  // ==========================================
  // ADMIN CAMPAIGN MODERATION & REVIEW
  // ==========================================

  /// Admin: Fetch all campaigns with multi-criteria filters
  Future<List<AdvertisementModel>> getAdminCampaigns({
    String? status,
    String? approvalStatus,
    int? employerId,
    int? packageId,
    String? search,
  }) async {
    lastErrorMessage = null;
    final Map<String, String> params = {};
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (approvalStatus != null && approvalStatus.isNotEmpty && approvalStatus != 'all') {
      params['approval_status'] = approvalStatus;
    }
    if (employerId != null) params['employer_id'] = employerId.toString();
    if (packageId != null) params['package_id'] = packageId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiService.get(
      ApiConstants.adminCampaigns,
      queryParams: params,
    );

    if (response.success && response.data is List) {
      return (response.data as List)
          .map(
            (json) => AdvertisementModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    }

    lastErrorMessage = response.message;
    return [];
  }

  /// Admin: Approve campaign
  Future<bool> approveCampaign(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.adminCampaignApprove(id),
      {},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to approve campaign.';
    }
    return response.success;
  }

  /// Admin: Reject campaign with mandatory reason
  Future<bool> rejectCampaign(int id, String reason) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.adminCampaignReject(id),
      {'rejection_reason': reason},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to reject campaign.';
    }
    return response.success;
  }

  /// Admin: Suspend campaign
  Future<bool> suspendCampaign(int id) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.adminCampaignSuspend(id),
      {},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to suspend campaign.';
    }
    return response.success;
  }

  // ---------------------------------------------------------
  // PHASE 3: PAYMENT GATEWAY & TRANSACTIONS
  // ---------------------------------------------------------

  /// Fetch supported payment providers and live configuration status
  Future<Map<String, dynamic>> getPaymentMethods() async {
    final response = await _apiService.get(ApiConstants.paymentMethods);
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {};
  }

  /// Initiate payment checkout session
  Future<PaymentTransactionModel?> initiatePayment({
    required int advertisementId,
    required String paymentMethod,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.initiatePayment,
      {
        'advertisement_id': advertisementId,
        'payment_method': paymentMethod,
        'customer_name': ?customerName,
        'customer_email': ?customerEmail,
        'customer_phone': ?customerPhone,
      },
    );

    if (response.success && response.data is Map<String, dynamic>) {
      return PaymentTransactionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Payment initiation failed.';
    return null;
  }

  /// Direct server-to-server payment verification
  Future<PaymentTransactionModel?> verifyPayment(
    String transactionReference,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.get(
      ApiConstants.verifyPayment(transactionReference),
    );

    if (response.success && response.data is Map<String, dynamic>) {
      return PaymentTransactionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    lastErrorMessage = response.message.isNotEmpty
        ? response.message
        : 'Payment verification failed.';
    return null;
  }

  /// Retrieve employer transactions
  Future<List<PaymentTransactionModel>> getEmployerTransactions({
    String? status,
    int page = 1,
  }) async {
    final Map<String, String> params = {'page': '$page'};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final response = await _apiService.get(
      ApiConstants.employerTransactions,
      queryParams: params,
    );

    if (response.success && response.data is Map<String, dynamic>) {
      final list = response.data['data'];
      if (list is List) {
        return list
            .map(
              (item) => PaymentTransactionModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    }
    return [];
  }

  /// Retrieve detailed transaction data by reference
  Future<PaymentTransactionModel?> getTransactionDetail(
    String transactionReference,
  ) async {
    final response = await _apiService.get(
      ApiConstants.employerTransactionDetail(transactionReference),
    );

    if (response.success && response.data is Map<String, dynamic>) {
      return PaymentTransactionModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return null;
  }

  /// Admin: Retrieve all platform payment transactions
  Future<List<PaymentTransactionModel>> getAdminTransactions({
    String? status,
    String? search,
    int page = 1,
  }) async {
    final Map<String, String> params = {'page': '$page'};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiService.get(
      ApiConstants.adminTransactions,
      queryParams: params,
    );

    if (response.success && response.data is Map<String, dynamic>) {
      final list = response.data['data'];
      if (list is List) {
        return list
            .map(
              (item) => PaymentTransactionModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    }
    return [];
  }

  /// Admin: Authorize and record payment refund
  Future<bool> refundTransaction(
    String transactionReference,
    double amount,
    String reason,
  ) async {
    lastErrorMessage = null;
    final response = await _apiService.post(
      ApiConstants.adminRefundTransaction(transactionReference),
      {'amount': amount, 'reason': reason},
    );

    if (!response.success) {
      lastErrorMessage = response.message.isNotEmpty
          ? response.message
          : 'Failed to process refund.';
    }
    return response.success;
  }
}
