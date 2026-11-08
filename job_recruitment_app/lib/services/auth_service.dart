import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';
import '../core/constants/api_constants.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  UserModel? _currentUser;
  bool _isLoading = false;
  String _localeCode = 'en';

  AuthService(this._apiService, this._storageService) {
    _localeCode = _storageService.getLanguage();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated =>
      _storageService.getToken() != null && _currentUser != null;
  bool get isLoading => _isLoading;
  Locale get currentLocale => Locale(_localeCode);

  Future<void> setLanguage(String code) async {
    _localeCode = code;
    await _storageService.saveLanguage(code);
    notifyListeners();
  }

  Future<bool> checkAuthStatus() async {
    final token = _storageService.getToken();
    if (token == null || token.isEmpty) {
      _currentUser = null;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    final response = await _apiService.get(ApiConstants.user);
    _isLoading = false;

    if (response.success && response.data != null) {
      _currentUser = UserModel.fromJson(response.data);
      notifyListeners();
      return true;
    } else {
      await _storageService.removeToken();
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  Future<ApiResponse> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final response = await _apiService.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });

    _isLoading = false;

    if (response.success && response.data != null) {
      final token = response.data['token'];
      if (token != null) {
        await _storageService.saveToken(token);
        // Sync anonymous device consent with authenticated user account
        try {
          await _apiService.post(ApiConstants.adsConsentSync, {
            'consent_uuid': _storageService.getConsentUuid(),
          });
        } catch (_) {}
      }
      if (response.data['user'] != null) {
        _currentUser = UserModel.fromJson(response.data['user']);
      }
      notifyListeners();
    }

    return response;
  }

  Future<ApiResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String role,
    String? phone,
    String? profilePhoto,
    List<int>? photoBytes,
    String? photoFilename,
    List<int>? cvBytes,
    String? cvFilename,
  }) async {
    _isLoading = true;
    notifyListeners();

    final ApiResponse response;
    if (photoBytes != null || cvBytes != null) {
      final fields = <String, String>{
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
      };
      if (phone != null && phone.isNotEmpty) {
        fields['phone'] = phone;
      }
      if (profilePhoto != null && profilePhoto.isNotEmpty) {
        fields['profile_photo'] = profilePhoto;
      }

      response = await _apiService.registerMultipart(
        endpoint: ApiConstants.register,
        fields: fields,
        photoBytes: photoBytes,
        photoFilename: photoFilename,
        cvBytes: cvBytes,
        cvFilename: cvFilename,
      );
    } else {
      response = await _apiService.post(ApiConstants.register, {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': role,
        'phone': phone,
        'profile_photo': profilePhoto,
      });
    }

    _isLoading = false;

    if (response.success && response.data != null) {
      final token = response.data['token'];
      if (token != null) {
        await _storageService.saveToken(token);
        // Sync anonymous device consent with authenticated user account
        try {
          await _apiService.post(ApiConstants.adsConsentSync, {
            'consent_uuid': _storageService.getConsentUuid(),
          });
        } catch (_) {}
      }
      if (response.data['user'] != null) {
        _currentUser = UserModel.fromJson(response.data['user']);
      }
      notifyListeners();
    }

    return response;
  }

  Future<void> logout() async {
    try {
      await _apiService.post(ApiConstants.logout, {});
    } catch (_) {}
    await _storageService.removeToken();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final response = await _apiService.get(ApiConstants.user);
    if (response.success && response.data != null) {
      _currentUser = UserModel.fromJson(response.data);
      notifyListeners();
    }
  }
}
