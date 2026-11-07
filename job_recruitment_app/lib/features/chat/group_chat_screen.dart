import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_group_model.dart';
import '../../models/chat_message_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../shared/utils/avatar_helper.dart';
import '../jobs/job_details_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final ChatGroupModel group;

  const GroupChatScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages(initial: true);
    // Poll every 4 seconds for fresh messages from friends
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchMessages(initial: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    final chatRepo = Provider.of<ChatRepository>(context, listen: false);
    final msgs = await chatRepo.getMessages(widget.group.id);

    if (mounted) {
      final shouldScroll = initial || msgs.length > _messages.length;
      setState(() {
        _messages = msgs;
        if (initial) _isLoading = false;
      });

      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final chatRepo = Provider.of<ChatRepository>(context, listen: false);
    final resp = await chatRepo.sendMessage(
      groupId: widget.group.id,
      message: text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (resp.success) {
        _fetchMessages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp.message.isNotEmpty ? resp.message : 'Failed to deliver message.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(ChatMessageModel msg, int currentUserId) {
    final isMe = msg.userId == currentUserId;
    final avatarProvider = getAvatarImageProvider(msg.senderPhoto);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF0D6B4F).withOpacity(0.15),
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F)),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF0D6B4F) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      msg.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6B4F),
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 2),

                  // Shared Vacancy Card inside chat message
                  if (msg.sharedJob != null || msg.sharedJobId != null) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D6B4F).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.work_outline, color: Color(0xFF0D6B4F), size: 16),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Shared Vacancy',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg.sharedJob?.title ?? 'Job Opportunity #${msg.sharedJobId}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (msg.sharedJob?.employer != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              msg.sharedJob!.employer!.organizationName,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                          if (msg.sharedJob?.location != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '📍 ${msg.sharedJob!.location} • ${msg.sharedJob!.employmentType}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final jobId = msg.sharedJob?.id ?? msg.sharedJobId;
                                if (jobId != null) {
                                  final jobRepo = Provider.of<JobRepository>(context, listen: false);
                                  final appRepo = Provider.of<ApplicationRepository>(context, listen: false);
                                  final profRepo = Provider.of<ProfileRepository>(context, listen: false);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => JobDetailsScreen(
                                        jobId: jobId,
                                        jobRepo: jobRepo,
                                        appRepo: appRepo,
                                        profRepo: profRepo,
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                backgroundColor: const Color(0xFF0D6B4F),
                              ),
                              icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white),
                              label: const Text('View Vacancy Details', style: TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Text(
                    msg.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.createdAt.contains('T')
                        ? msg.createdAt.split('T').last.substring(0, 5)
                        : (msg.createdAt.length >= 5 ? msg.createdAt.substring(msg.createdAt.length - 5) : ''),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white.withOpacity(0.7) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final currentUserId = auth.currentUser?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.group.memberCount} members • Career Group',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh messages',
            onPressed: () => _fetchMessages(initial: false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned Info Banner
          if (widget.group.description != null && widget.group.description!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0D6B4F).withOpacity(0.06),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF0D6B4F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.group.description!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0D6B4F)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet in this group.\nStart the conversation or share a vacancy!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index], currentUserId);
                        },
                      ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Message friends in group...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0D6B4F),
                    radius: 22,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
