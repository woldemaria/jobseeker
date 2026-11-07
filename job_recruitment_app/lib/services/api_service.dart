import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final dynamic meta;
  final Map<String, dynamic>? errors;
  final int statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
    this.errors,
    required this.statusCode,
  });
}

class _CacheEntry {
  final ApiResponse response;
  final DateTime expiresAt;

  _CacheEntry(this.response, Duration ttl) : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ApiService {
  final StorageService _storageService;
  static final Map<String, _CacheEntry> _responseCache = {};

  ApiService(this._storageService);

  String? get token => _storageService.getToken();

  /// Clear in-memory cache for microsecond cache invalidation
  static void clearCache([String? endpointPrefix]) {
    if (endpointPrefix == null) {
      _responseCache.clear();
    } else {
      _responseCache.removeWhere((key, _) => key.contains(endpointPrefix));
    }
  }

  void _invalidateOnMutation(String endpoint) {
    if (endpoint.contains('/jobs') || endpoint.contains('/saved-jobs')) {
      clearCache('/jobs');
      clearCache('/saved-jobs');
    }
    if (endpoint.contains('/applications')) {
      clearCache('/applications');
      clearCache('/jobs');
    }
    if (endpoint.contains('/profile')) {
      clearCache('/profile');
      clearCache('/auth/user');
    }
    if (endpoint.contains('/documents')) {
      clearCache('/documents');
    }
    if (endpoint.contains('/notifications')) {
      clearCache('/notifications');
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? cacheTtl,
    bool forceRefresh = false,
  }) async {
    final queryStr = queryParams != null && queryParams.isNotEmpty
        ? queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')
        : '';
    final cacheKey = '$endpoint?$queryStr';

    // Microsecond in-memory cache lookup
    if (!forceRefresh) {
      final cached = _responseCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.response;
      }
    }

    try {
      var uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));

      final apiResponse = _processResponse(response);

      if (apiResponse.success) {
        final ttl = cacheTtl ??
            (endpoint.contains('/categories') ||
                    endpoint.contains('/job-titles') ||
                    endpoint.contains('/salary-benchmarks')
                ? const Duration(minutes: 5)
                : const Duration(seconds: 30));
        _responseCache[cacheKey] = _CacheEntry(apiResponse, ttl);
      }

      return apiResponse;
    } catch (e) {
      // If network fails, return cached response if available
      final fallback = _responseCache[cacheKey];
      if (fallback != null) {
        return fallback.response;
      }

      return ApiResponse(
        success: false,
        message: 'Network error or server unreachable: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> post(String endpoint, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final response = await http
          .post(uri, headers: _buildHeaders(), body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 15));

      final res = _processResponse(response);
      if (res.success) {
        _invalidateOnMutation(endpoint);
      }
      return res;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> put(String endpoint, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final response = await http
          .put(uri, headers: _buildHeaders(), body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 15));

      final res = _processResponse(response);
      if (res.success) {
        _invalidateOnMutation(endpoint);
      }
      return res;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> patch(String endpoint, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final response = await http
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      final res = _processResponse(response);
      if (res.success) {
        _invalidateOnMutation(endpoint);
      }
      return res;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> delete(String endpoint) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final response = await http
          .delete(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));

      final res = _processResponse(response);
      if (res.success) {
        _invalidateOnMutation(endpoint);
      }
      return res;
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Network error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> uploadFile(String endpoint, File file, String documentType) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      final token = _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.fields['document_type'] = documentType;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      return _processResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Upload error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> registerMultipart({
    required String endpoint,
    required Map<String, String> fields,
    List<int>? photoBytes,
    String? photoFilename,
    List<int>? cvBytes,
    String? cvFilename,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);

      if (photoBytes != null && photoFilename != null) {
        request.files.add(
          http.MultipartFile.fromBytes('profile_photo_file', photoBytes, filename: photoFilename),
        );
      }
      if (cvBytes != null && cvFilename != null) {
        request.files.add(
          http.MultipartFile.fromBytes('cv_file', cvBytes, filename: cvFilename),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Registration network error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> uploadFileBytes(
    String endpoint,
    List<int> bytes,
    String filename,
    String documentType,
  ) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      final token = _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.fields['document_type'] = documentType;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      return _processResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Upload error: $e',
        statusCode: 500,
      );
    }
  }

  Future<ApiResponse> uploadProfilePhotoBytes(
    List<int> bytes,
    String filename,
  ) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profilePhoto}');
      final request = http.MultipartRequest('POST', uri);

      final token = _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';

      request.files.add(http.MultipartFile.fromBytes('photo', bytes, filename: filename));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      return _processResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Upload error: $e',
        statusCode: 500,
      );
    }
  }

  ApiResponse _processResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final success = body['success'] ?? (response.statusCode >= 200 && response.statusCode < 300);
        final message = body['message'] ?? (success ? 'Success' : 'Error');
        final data = body['data'];
        final meta = body['meta'];
        Map<String, dynamic>? errors;
        if (body['errors'] is Map<String, dynamic>) {
          errors = body['errors'];
        }

        return ApiResponse(
          success: success,
          message: message,
          data: data,
          meta: meta,
          errors: errors,
          statusCode: response.statusCode,
        );
      }
    } catch (_) {}

    return ApiResponse(
      success: response.statusCode >= 200 && response.statusCode < 300,
      message: 'Status code: ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}
