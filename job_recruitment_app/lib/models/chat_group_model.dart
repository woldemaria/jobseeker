class ChatGroupModel {
  final int id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int createdBy;
  final bool isPrivate;
  final int memberCount;
  final bool isMember;
  final String? lastMessageText;
  final String? lastMessageSender;
  final String? lastMessageTime;

  ChatGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.createdBy,
    this.isPrivate = false,
    this.memberCount = 1,
    this.isMember = false,
    this.lastMessageText,
    this.lastMessageSender,
    this.lastMessageTime,
  });

  factory ChatGroupModel.fromJson(Map<String, dynamic> json) {
    String? lastMsgText;
    String? lastMsgSender;
    String? lastMsgTime;

    if (json['latest_message'] != null && json['latest_message'] is Map) {
      final latest = json['latest_message'] as Map<String, dynamic>;
      lastMsgText = latest['message'];
      lastMsgTime = latest['created_at'];
      if (latest['user'] != null && latest['user'] is Map) {
        lastMsgSender = latest['user']['name'];
      }
    }

    return ChatGroupModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Career Community',
      description: json['description'],
      iconUrl: json['icon_url'],
      createdBy: json['created_by'] ?? 0,
      isPrivate: json['is_private'] == true || json['is_private'] == 1,
      memberCount: json['members_count'] ?? 1,
      isMember: json['is_member'] == true || json['is_member'] == 1,
      lastMessageText: lastMsgText,
      lastMessageSender: lastMsgSender,
      lastMessageTime: lastMsgTime,
    );
  }
}
