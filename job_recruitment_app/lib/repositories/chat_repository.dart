import '../core/constants/api_constants.dart';
import '../models/chat_group_model.dart';
import '../models/chat_message_model.dart';
import '../services/api_service.dart';

class ChatRepository {
  final ApiService _apiService;

  ChatRepository(this._apiService);

  Future<List<ChatGroupModel>> getGroups() async {
    final response = await _apiService.get(ApiConstants.chatGroups);
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((g) => ChatGroupModel.fromJson(g))
          .toList();
    }
    return [];
  }

  Future<ApiResponse> createGroup({
    required String name,
    String? description,
    bool isPrivate = false,
  }) async {
    return await _apiService.post(ApiConstants.chatGroups, {
      'name': name,
      'description': description,
      'is_private': isPrivate,
    });
  }

  Future<ApiResponse> joinGroup(int groupId) async {
    return await _apiService.post(
      '${ApiConstants.chatGroups}/$groupId/join',
      {},
    );
  }

  Future<ApiResponse> leaveGroup(int groupId) async {
    return await _apiService.post(
      '${ApiConstants.chatGroups}/$groupId/leave',
      {},
    );
  }

  Future<List<ChatMessageModel>> getMessages(int groupId) async {
    final response = await _apiService.get(
      '${ApiConstants.chatGroups}/$groupId/messages',
    );
    if (response.success && response.data is List) {
      return (response.data as List)
          .map((m) => ChatMessageModel.fromJson(m))
          .toList();
    }
    return [];
  }

  Future<ApiResponse> sendMessage({
    required int groupId,
    required String message,
    int? sharedJobId,
  }) async {
    return await _apiService.post(
      '${ApiConstants.chatGroups}/$groupId/messages',
      {
        'message': message,
        'message_type': sharedJobId != null ? 'job_share' : 'text',
        'shared_job_id': sharedJobId,
      },
    );
  }
}
