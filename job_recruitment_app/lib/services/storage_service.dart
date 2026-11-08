import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'cached_user';
  static const String _keyLanguage = 'selected_language';

  // Advertising & Privacy Consent Keys
  static const String _keyConsentUuid = 'ad_consent_uuid';
  static const String _keyAdConsentStatus = 'ad_consent_status';
  static const String _keyConsentPersonalized = 'consent_personalized_ads';
  static const String _keyConsentNonPersonalized =
      'consent_non_personalized_ads';
  static const String _keyConsentAnalytics = 'consent_analytics';
  static const String _keyConsentCookies = 'consent_advertising_cookies';
  static const String _keyConsentPolicyVersion = 'ad_consent_policy_version';
  static const String _keyConsentTimestamp = 'consent_timestamp';
  static const String _keyConsentWithdrawnAt = 'consent_withdrawn_at';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(_keyToken, token);
  }

  String? getToken() {
    return _prefs.getString(_keyToken);
  }

  Future<void> removeToken() async {
    await _prefs.remove(_keyToken);
  }

  Future<void> saveLanguage(String langCode) async {
    await _prefs.setString(_keyLanguage, langCode);
  }

  String getLanguage() {
    return _prefs.getString(_keyLanguage) ?? 'en';
  }

  // --- Advertising & Cookie Privacy Consent Preferences ---

  /// Get or lazily generate a persistent UUID for anonymous consent tracking
  String getConsentUuid() {
    var uuid = _prefs.getString(_keyConsentUuid);
    if (uuid == null || uuid.isEmpty) {
      uuid = _generateUuidV4();
      _prefs.setString(_keyConsentUuid, uuid);
    }
    return uuid;
  }

  /// Whether the user has explicitly recorded an advertising consent choice
  bool hasConsentRecorded() {
    return _prefs.getString(_keyAdConsentStatus) != null;
  }

  String? getAdConsentStatus() {
    return _prefs.getString(_keyAdConsentStatus);
  }

  String getConsentPolicyVersion() {
    return _prefs.getString(_keyConsentPolicyVersion) ?? '1.0';
  }

  bool requiresPolicyReconsent(String currentVersion) {
    if (!hasConsentRecorded()) {
      return true;
    }
    final status = getAdConsentStatus();
    if (status == 'withdrawn') {
      return false; // Withdrawn remains withdrawn until user changes
    }
    return getConsentPolicyVersion() != currentVersion;
  }

  bool isPersonalizedAdsAllowed() {
    final status = getAdConsentStatus();
    if (status == null || status == 'rejected' || status == 'withdrawn') {
      return false;
    }
    if (status == 'accepted') {
      return true;
    }
    return _prefs.getBool(_keyConsentPersonalized) ?? false;
  }

  bool isNonPersonalizedAdsAllowed() {
    final status = getAdConsentStatus();
    if (status == null || status == 'rejected' || status == 'withdrawn') {
      return false;
    }
    if (status == 'accepted') {
      return true;
    }
    return _prefs.getBool(_keyConsentNonPersonalized) ?? false;
  }

  bool isAnalyticsAllowed() {
    final status = getAdConsentStatus();
    if (status == null || status == 'rejected' || status == 'withdrawn') {
      return false;
    }
    if (status == 'accepted') {
      return true;
    }
    return _prefs.getBool(_keyConsentAnalytics) ?? false;
  }

  bool isCookiesAllowed() {
    final status = getAdConsentStatus();
    if (status == null || status == 'rejected' || status == 'withdrawn') {
      return false;
    }
    if (status == 'accepted') {
      return true;
    }
    return _prefs.getBool(_keyConsentCookies) ?? false;
  }

  DateTime? getConsentTimestamp() {
    final val = _prefs.getString(_keyConsentTimestamp);
    return val != null ? DateTime.tryParse(val) : null;
  }

  DateTime? getConsentWithdrawnAt() {
    final val = _prefs.getString(_keyConsentWithdrawnAt);
    return val != null ? DateTime.tryParse(val) : null;
  }

  Future<void> saveAdConsent({
    required String status,
    required bool personalized,
    required bool nonPersonalized,
    required bool analytics,
    required bool cookies,
    String policyVersion = '1.0',
    DateTime? timestamp,
  }) async {
    await _prefs.setString(_keyAdConsentStatus, status);
    await _prefs.setBool(_keyConsentPersonalized, personalized);
    await _prefs.setBool(_keyConsentNonPersonalized, nonPersonalized);
    await _prefs.setBool(_keyConsentAnalytics, analytics);
    await _prefs.setBool(_keyConsentCookies, cookies);
    await _prefs.setString(_keyConsentPolicyVersion, policyVersion);
    await _prefs.setString(
      _keyConsentTimestamp,
      (timestamp ?? DateTime.now()).toIso8601String(),
    );
    if (status != 'withdrawn') {
      await _prefs.remove(_keyConsentWithdrawnAt);
    }
  }

  Future<void> withdrawAdConsent() async {
    await _prefs.setString(_keyAdConsentStatus, 'withdrawn');
    await _prefs.setBool(_keyConsentPersonalized, false);
    await _prefs.setBool(_keyConsentNonPersonalized, false);
    await _prefs.setBool(_keyConsentAnalytics, false);
    await _prefs.setBool(_keyConsentCookies, false);
    await _prefs.setString(
      _keyConsentWithdrawnAt,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> clearAll() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUser);
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant
    return [
      values
          .sublist(0, 4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      values
          .sublist(4, 6)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      values
          .sublist(6, 8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      values
          .sublist(8, 10)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      values
          .sublist(10, 16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
    ].join('-');
  }
}
