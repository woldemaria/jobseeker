import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_group_model.dart';
import '../../models/job_model.dart';
import '../../repositories/chat_repository.dart';

class ShareWithFriendsModal extends StatefulWidget {
  final JobModel job;

  const ShareWithFriendsModal({
    super.key,
    required this.job,
  });

  static void show(BuildContext context, JobModel job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ShareWithFriendsModal(job: job),
    );
  }

  @override
  State<ShareWithFriendsModal> createState() => _ShareWithFriendsModalState();
}

class _ShareWithFriendsModalState extends State<ShareWithFriendsModal> {
  List<ChatGroupModel> _groups = [];
  bool _isLoadingGroups = true;
  int? _sharingGroupId;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    try {
      final chatRepo = Provider.of<ChatRepository>(context, listen: false);
      final groups = await chatRepo.getGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoadingGroups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  String _getShareText() {
    final deadlineClean = widget.job.deadline.contains('T')
        ? widget.job.deadline.split('T').first
        : widget.job.deadline;

    final jobUrl = 'http://localhost:3000/#/jobs/${widget.job.id}';

    return '''
📢 Job Vacancy: ${widget.job.title}
🏢 Company: ${widget.job.employer?.organizationName ?? "Leading Employer"}
📍 Location: ${widget.job.location}
💼 Type: ${widget.job.employmentType}
💰 Salary: ${widget.job.salaryText}
📅 Deadline: $deadlineClean
🔗 View & Apply Online: $jobUrl

Shared via JobSeeker Ethiopia - Smart Skills-Based Recruitment
'''.trim();
  }

  Future<void> _shareToWhatsApp() async {
    final text = Uri.encodeComponent(_getShareText());
    final uriPrimary = Uri.parse('https://api.whatsapp.com/send?text=$text');
    final uriSecondary = Uri.parse('https://wa.me/?text=$text');

    try {
      bool launched = await launchUrl(uriPrimary, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uriSecondary, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        _copyToClipboard('WhatsApp could not be opened. Vacancy details copied to clipboard!');
      }
    } catch (_) {
      try {
        final fallback = await launchUrl(uriSecondary, mode: LaunchMode.platformDefault);
        if (!fallback) {
          _copyToClipboard('WhatsApp could not be opened. Vacancy details copied to clipboard!');
        }
      } catch (_) {
        _copyToClipboard('WhatsApp could not be opened. Vacancy details copied to clipboard!');
      }
    }
  }

  Future<void> _shareToTelegram() async {
    final jobUrl = Uri.encodeComponent('http://localhost:3000/#/jobs/${widget.job.id}');
    final text = Uri.encodeComponent(_getShareText());
    final url = Uri.parse('https://t.me/share/url?url=$jobUrl&text=$text');

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyToClipboard('Telegram could not be opened. Vacancy details copied to clipboard!');
      }
    } catch (_) {
      try {
        final fallback = await launchUrl(url, mode: LaunchMode.platformDefault);
        if (!fallback) {
          _copyToClipboard('Telegram could not be opened. Vacancy details copied to clipboard!');
        }
      } catch (_) {
        _copyToClipboard('Telegram could not be opened. Vacancy details copied to clipboard!');
      }
    }
  }

  Future<void> _shareToEmail() async {
    final subject = Uri.encodeComponent('Job Opening: ${widget.job.title}');
    final body = Uri.encodeComponent(_getShareText());
    final url = Uri.parse('mailto:?subject=$subject&body=$body');

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyToClipboard('Email client could not be opened. Vacancy details copied to clipboard!');
      }
    } catch (_) {
      try {
        final fallback = await launchUrl(url, mode: LaunchMode.platformDefault);
        if (!fallback) {
          _copyToClipboard('Email client could not be opened. Vacancy details copied to clipboard!');
        }
      } catch (_) {
        _copyToClipboard('Email client could not be opened. Vacancy details copied to clipboard!');
      }
    }
  }

  void _copyToClipboard([String? customMessage]) {
    Clipboard.setData(ClipboardData(text: _getShareText()));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(customMessage ?? 'Vacancy details copied to clipboard!'),
        backgroundColor: const Color(0xFF0D6B4F),
      ),
    );
  }

  Future<void> _shareToChatGroup(ChatGroupModel group) async {
    setState(() => _sharingGroupId = group.id);
    final chatRepo = Provider.of<ChatRepository>(context, listen: false);

    final resp = await chatRepo.sendMessage(
      groupId: group.id,
      message: '📢 Check out this vacancy: ${widget.job.title} at ${widget.job.employer?.organizationName ?? "Leading Employer"}',
      sharedJobId: widget.job.id,
    );

    if (mounted) {
      setState(() => _sharingGroupId = null);
      Navigator.pop(context);
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vacancy shared successfully to "${group.name}"!'),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp.message.isNotEmpty ? resp.message : 'Failed to share to group.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6B4F).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share, color: Color(0xFF0D6B4F), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share with Friends',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Send vacancy via apps or career group chats',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // External Channels Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildChannelButton(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: _shareToWhatsApp,
              ),
              _buildChannelButton(
                icon: Icons.send,
                label: 'Telegram',
                color: const Color(0xFF0088CC),
                onTap: _shareToTelegram,
              ),
              _buildChannelButton(
                icon: Icons.email_outlined,
                label: 'Email',
                color: const Color(0xFFEA4335),
                onTap: _shareToEmail,
              ),
              _buildChannelButton(
                icon: Icons.copy,
                label: 'Copy Link',
                color: const Color(0xFF0D6B4F),
                onTap: () => _copyToClipboard(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 10),

          // Share to Community & Friends Groups
          const Row(
            children: [
              Icon(Icons.groups, size: 18, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text(
                'Share into Community & Friends Group',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoadingGroups)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_groups.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No career chat groups available yet. Create a group to share vacancies directly with friends.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  final isSharing = _sharingGroupId == group.id;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF0D6B4F).withOpacity(0.12),
                      child: Text(
                        group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F), fontSize: 13),
                      ),
                    ),
                    title: Text(group.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1),
                    subtitle: Text('${group.memberCount} members', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: isSharing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : OutlinedButton(
                            onPressed: () => _shareToChatGroup(group),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              side: const BorderSide(color: Color(0xFF0D6B4F)),
                            ),
                            child: const Text('Send', style: TextStyle(fontSize: 12, color: Color(0xFF0D6B4F))),
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }
}
