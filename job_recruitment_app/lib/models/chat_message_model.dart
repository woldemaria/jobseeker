import 'job_model.dart';

class ChatMessageModel {
  final int id;
  final int groupId;
  final int userId;
  final String message;
  final String messageType; // text, job_share, image
  final int? sharedJobId;
  final JobModel? sharedJob;
  final String senderName;
  final String? senderPhoto;
  final String createdAt;

  ChatMessageModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.message,
    this.messageType = 'text',
    this.sharedJobId,
    this.sharedJob,
    required this.senderName,
    this.senderPhoto,
    required this.createdAt,
  });

  bool isSentBy(int currentUserId) => userId == currentUserId;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String sender = 'Member';
    String? photo;
    if (json['user'] != null && json['user'] is Map) {
      sender = json['user']['name'] ?? 'Member';
      photo = json['user']['profile_photo'];
    }

    JobModel? job;
    if (json['shared_job'] != null && json['shared_job'] is Map) {
      job = JobModel.fromJson(json['shared_job']);
    }

    return ChatMessageModel(
      id: json['id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      message: json['message'] ?? '',
      messageType: json['message_type'] ?? 'text',
      sharedJobId: json['shared_job_id'],
      sharedJob: job,
      senderName: sender,
      senderPhoto: photo,
      createdAt: json['created_at'] ?? '',
    );
  }
}
