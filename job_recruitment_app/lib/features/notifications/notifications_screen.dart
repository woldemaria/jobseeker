import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const NotificationsScreen({super.key, required this.profRepo});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final notes = await widget.profRepo.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notes;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });
    await widget.profRepo.markAllNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('notifications')),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllRead,
              child: Text(loc.t('mark_all_read')),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? EmptyStateWidget(
              icon: Icons.notifications_none,
              title: loc.t('no_notifications'),
              subtitle: 'You will receive updates when employers review your applications.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: n.isRead ? Colors.white : const Color(0xFFF0FDF4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: n.isRead
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF0D6B4F).withOpacity(0.12),
                        child: Icon(
                          Icons.notifications,
                          color: n.isRead
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0D6B4F),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: n.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(n.message, style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            n.createdAt.split('T').first,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (!n.isRead) {
                          setState(() {
                            _notifications[index] = n.copyWith(isRead: true);
                          });
                          await widget.profRepo.markNotificationRead(n.id);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
