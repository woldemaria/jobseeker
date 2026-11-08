import '../core/constants/api_constants.dart';
import '../models/ad_consent_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AdsConsentRepository {
  final ApiService _apiService;
  final StorageService _storageService;

  AdsConsentRepository(this._apiService, this._storageService);

  /// Fetch remote consent status and sync with local storage cache
  Future<AdConsentModel?> getConsentStatus({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.adsConsent,
        forceRefresh: forceRefresh,
      );

      if (response.success && response.data != null && response.data is Map) {
        final consentData = response.data['consent'];
        if (consentData != null && consentData is Map<String, dynamic>) {
          final model = AdConsentModel.fromJson(consentData);
          await _storageService.saveAdConsent(
            status: model.status,
            personalized: model.personalizedAds,
            nonPersonalized: model.nonPersonalizedAds,
            analytics: model.analytics,
            cookies: model.advertisingCookies,
            policyVersion: model.policyVersion,
            timestamp: model.consentedAt,
          );
          return model;
        } else if (consentData != null && consentData is Map) {
          final model = AdConsentModel.fromJson(
            Map<String, dynamic>.from(consentData),
          );
          await _storageService.saveAdConsent(
            status: model.status,
            personalized: model.personalizedAds,
            nonPersonalized: model.nonPersonalizedAds,
            analytics: model.analytics,
            cookies: model.advertisingCookies,
            policyVersion: model.policyVersion,
            timestamp: model.consentedAt,
          );
          return model;
        }
      }
    } catch (_) {
      // Offline fallback: load from StorageService
    }

    if (_storageService.hasConsentRecorded()) {
      return AdConsentModel(
        consentUuid: _storageService.getConsentUuid(),
        status: _storageService.getAdConsentStatus() ?? 'custom',
        personalizedAds: _storageService.isPersonalizedAdsAllowed(),
        nonPersonalizedAds: _storageService.isNonPersonalizedAdsAllowed(),
        analytics: _storageService.isAnalyticsAllowed(),
        advertisingCookies: _storageService.isCookiesAllowed(),
        policyVersion: _storageService.getConsentPolicyVersion(),
        consentedAt: _storageService.getConsentTimestamp(),
        withdrawnAt: _storageService.getConsentWithdrawnAt(),
      );
    }

    return null;
  }

  /// Store or update consent preferences on backend and cache locally
  Future<AdConsentModel> saveConsent({
    required String status,
    bool? personalized,
    bool? nonPersonalized,
    bool? analytics,
    bool? cookies,
    String policyVersion = '1.0',
  }) async {
    final consentUuid = _storageService.getConsentUuid();
    final bool p = (status == 'accepted')
        ? true
        : (status == 'rejected' || status == 'withdrawn')
        ? false
        : (personalized ?? false);
    final bool np = (status == 'accepted')
        ? true
        : (status == 'rejected' || status == 'withdrawn')
        ? false
        : (nonPersonalized ?? false);
    final bool a = (status == 'accepted')
        ? true
        : (status == 'rejected' || status == 'withdrawn')
        ? false
        : (analytics ?? false);
    final bool c = (status == 'accepted')
        ? true
        : (status == 'rejected' || status == 'withdrawn')
        ? false
        : (cookies ?? false);

    // Save locally first for instant UI response and offline integrity
    await _storageService.saveAdConsent(
      status: status,
      personalized: p,
      nonPersonalized: np,
      analytics: a,
      cookies: c,
      policyVersion: policyVersion,
      timestamp: DateTime.now(),
    );

    try {
      final response = await _apiService.post(ApiConstants.adsConsent, {
        'consent_uuid': consentUuid,
        'status': status,
        'personalized_ads': p,
        'non_personalized_ads': np,
        'analytics': a,
        'advertising_cookies': c,
        'policy_version': policyVersion,
      });

      if (response.success && response.data != null && response.data is Map) {
        return AdConsentModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (_) {
      // Backend unavailable; local cached record will be synced later
    }

    return AdConsentModel(
      consentUuid: consentUuid,
      status: status,
      personalizedAds: p,
      nonPersonalizedAds: np,
      analytics: a,
      advertisingCookies: c,
      policyVersion: policyVersion,
      consentedAt: DateTime.now(),
    );
  }

  /// Completely withdraw advertising consent
  Future<AdConsentModel> withdrawConsent() async {
    final consentUuid = _storageService.getConsentUuid();
    await _storageService.withdrawAdConsent();

    try {
      final response = await _apiService.post(ApiConstants.adsConsentWithdraw, {
        'consent_uuid': consentUuid,
      });

      if (response.success && response.data != null && response.data is Map) {
        return AdConsentModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (_) {
      // Offline fallback
    }

    return AdConsentModel(
      consentUuid: consentUuid,
      status: 'withdrawn',
      personalizedAds: false,
      nonPersonalizedAds: false,
      analytics: false,
      advertisingCookies: false,
      policyVersion: _storageService.getConsentPolicyVersion(),
      withdrawnAt: DateTime.now(),
    );
  }

  /// Sync anonymous device consent with authenticated user account
  Future<void> syncAccountConsent() async {
    final consentUuid = _storageService.getConsentUuid();
    try {
      final response = await _apiService.post(ApiConstants.adsConsentSync, {
        'consent_uuid': consentUuid,
      });

      if (response.success && response.data != null && response.data is Map) {
        final model = AdConsentModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        await _storageService.saveAdConsent(
          status: model.status,
          personalized: model.personalizedAds,
          nonPersonalized: model.nonPersonalizedAds,
          analytics: model.analytics,
          cookies: model.advertisingCookies,
          policyVersion: model.policyVersion,
          timestamp: model.consentedAt,
        );
      }
    } catch (_) {}
  }

  /// Retrieve transparent audit history for user review
  Future<List<Map<String, dynamic>>> getAuditHistory() async {
    try {
      final response = await _apiService.get(
        ApiConstants.adsConsentHistory,
        forceRefresh: true,
      );
      if (response.success && response.data is List) {
        return (response.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
