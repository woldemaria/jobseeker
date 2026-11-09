import 'dart:io';

import '../models/document_model.dart';
import '../models/notification_model.dart';
import '../models/skill_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_constants.dart';

class ProfileRepository {
  final ApiService _apiService;

  ProfileRepository(this._apiService);

  String? get authToken => _apiService.token;

  Future<Map<String, dynamic>?> getProfile() async {
    final response = await _apiService.get(ApiConstants.profile);
    if (response.success && response.data != null) {
      return response.data;
    }
    return null;
  }

  Future<ApiResponse> updateProfile(Map<String, dynamic> data) async {
    return await _apiService.put(ApiConstants.profile, data);
  }

  Future<ApiResponse> uploadProfilePhoto(
    List<int> bytes,
    String filename,
  ) async {
    return await _apiService.uploadProfilePhotoBytes(bytes, filename);
  }

  Future<List<SkillModel>> getAllSkills() async {
    final response = await _apiService.get(ApiConstants.skills);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((s) => SkillModel.fromJson(s))
          .toList();
    }
    return [];
  }

  Future<List<SkillModel>> getUserSkills() async {
    final response = await _apiService.get(ApiConstants.profileSkills);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((s) => SkillModel.fromJson(s))
          .toList();
    }
    return [];
  }

  Future<ApiResponse> addSkill(
    int skillId,
    String proficiency,
    double years,
  ) async {
    return await _apiService.post(ApiConstants.profileSkills, {
      'skill_id': skillId,
      'proficiency_level': proficiency,
      'years_experience': years,
    });
  }

  Future<ApiResponse> removeSkill(int skillId) async {
    return await _apiService.delete('${ApiConstants.profileSkills}/$skillId');
  }

  Future<List<Map<String, dynamic>>> getEducation() async {
    final response = await _apiService.get(ApiConstants.profileEducation);
    if (response.success && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  Future<ApiResponse> addEducation(Map<String, dynamic> data) async {
    return await _apiService.post(ApiConstants.profileEducation, data);
  }

  Future<ApiResponse> updateEducation(int id, Map<String, dynamic> data) async {
    return await _apiService.put('${ApiConstants.profileEducation}/$id', data);
  }

  Future<ApiResponse> removeEducation(int id) async {
    return await _apiService.delete('${ApiConstants.profileEducation}/$id');
  }

  Future<List<Map<String, dynamic>>> getExperience() async {
    final response = await _apiService.get(ApiConstants.profileExperience);
    if (response.success && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  Future<ApiResponse> addExperience(Map<String, dynamic> data) async {
    return await _apiService.post(ApiConstants.profileExperience, data);
  }

  Future<ApiResponse> updateExperience(
    int id,
    Map<String, dynamic> data,
  ) async {
    return await _apiService.put('${ApiConstants.profileExperience}/$id', data);
  }

  Future<ApiResponse> removeExperience(int id) async {
    return await _apiService.delete('${ApiConstants.profileExperience}/$id');
  }

  // Documents
  Future<List<DocumentModel>> getDocuments() async {
    final response = await _apiService.get(ApiConstants.documents);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((d) => DocumentModel.fromJson(d))
          .toList();
    }
    return [];
  }

  Future<ApiResponse> uploadDocument(File file, String docType) async {
    return await _apiService.uploadFile(ApiConstants.documents, file, docType);
  }

  Future<ApiResponse> uploadDocumentBytes(
    List<int> bytes,
    String filename,
    String docType,
  ) async {
    return await _apiService.uploadFileBytes(
      ApiConstants.documents,
      bytes,
      filename,
      docType,
    );
  }

  Future<ApiResponse> deleteDocument(int docId) async {
    return await _apiService.delete('${ApiConstants.documents}/$docId');
  }

  // Notifications
  Future<List<NotificationModel>> getNotifications() async {
    final response = await _apiService.get(ApiConstants.notifications);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((n) => NotificationModel.fromJson(n))
          .toList();
    }
    return [];
  }

  Future<bool> markNotificationRead(int id) async {
    final response = await _apiService.patch(
      '${ApiConstants.notifications}/$id/read',
    );
    return response.success;
  }

  Future<bool> markAllNotificationsRead() async {
    final response = await _apiService.patch(
      ApiConstants.markAllNotificationsRead,
    );
    return response.success;
  }

  Future<List<Map<String, dynamic>>> getUserBadges() async {
    final response = await _apiService.get('/user/badges');
    if (response.success && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getQuizzes() async {
    final response = await _apiService.get(ApiConstants.quizzes);
    if (response.success && response.data is List) {
      return List<Map<String, dynamic>>.from(response.data);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getQuizDetails(int quizId) async {
    final response = await _apiService.get(ApiConstants.quizDetail(quizId));
    if (response.success && response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return null;
  }

  Future<ApiResponse> submitQuiz(
    int quizId,
    Map<String, dynamic> answers,
  ) async {
    return await _apiService.post(ApiConstants.quizSubmit(quizId), {
      'answers': answers,
    });
  }
}
