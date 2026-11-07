import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'cached_user';
  static const String _keyLanguage = 'selected_language';
  static const String _keyAdConsentStatus = 'ad_consent_status';
  static const String _keyConsentPersonalized = 'consent_personalized_ads';
  static const String _keyConsentAnalytics = 'consent_analytics';

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

  // Cookie & Advertisement Consent Preferences
  String? getAdConsentStatus() {
    return _prefs.getString(_keyAdConsentStatus);
  }

  bool isPersonalizedAdsAllowed() {
    final status = getAdConsentStatus();
    if (status == 'rejected') return false;
    return _prefs.getBool(_keyConsentPersonalized) ?? true;
  }

  bool isAnalyticsAllowed() {
    final status = getAdConsentStatus();
    if (status == 'rejected') return false;
    return _prefs.getBool(_keyConsentAnalytics) ?? true;
  }

  Future<void> saveAdConsent({
    required String status,
    required bool personalized,
    required bool analytics,
  }) async {
    await _prefs.setString(_keyAdConsentStatus, status);
    await _prefs.setBool(_keyConsentPersonalized, personalized);
    await _prefs.setBool(_keyConsentAnalytics, analytics);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyUser);
  }
}
