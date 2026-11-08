import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_group_model.dart';
import '../../repositories/chat_repository.dart';
import '../../shared/widgets/empty_state.dart';
import 'group_chat_screen.dart';

class ChatGroupsScreen extends StatefulWidget {
  const ChatGroupsScreen({super.key});

  @override
  State<ChatGroupsScreen> createState() => _ChatGroupsScreenState();
}

class _ChatGroupsScreenState extends State<ChatGroupsScreen> {
  List<ChatGroupModel> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() => _isLoading = true);
    try {
      final chatRepo = Provider.of<ChatRepository>(context, listen: false);
      final results = await chatRepo.getGroups();
      if (mounted) {
        setState(() {
          _groups = results;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.group_add, color: Color(0xFF0D6B4F)),
              SizedBox(width: 8),
              Text('Create Career Group', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a community group to discuss job openings, share advice, and connect with peers.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name *',
                    hintText: 'e.g. Addis Software Developers',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Purpose and guidelines for members...',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Private Group',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Only invited members can find and join',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: isPrivate,
                  activeColor: const Color(0xFF0D6B4F),
                  onChanged: (val) => setDialogState(() => isPrivate = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Group name is required.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final chatRepo = Provider.of<ChatRepository>(
                        context,
                        listen: false,
                      );
                      final resp = await chatRepo.createGroup(
                        name: name,
                        description: descController.text.trim(),
                        isPrivate: isPrivate,
                      );

                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        if (resp.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chat group created!'),
                              backgroundColor: Color(0xFF0D6B4F),
                            ),
                          );
                          _fetchGroups();
                        } else {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(resp.message)));
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Group'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _groups.where((g) {
      if (_searchQuery.isEmpty) return true;
      return g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (g.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community & Friends Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Create New Group',
            onPressed: _showCreateGroupDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchGroups),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search career groups...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  ),
                ),

                // Group List
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.forum_outlined,
                          title: 'No Groups Found',
                          subtitle: 'Create a group to connect with friends, peers, and fellow job seekers in Ethiopia.',
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchGroups,
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (context, index) {
                              final group = filtered[index];

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF0D6B4F)
                                      .withOpacity(0.12),
                                  child: Text(
                                    group.name.isNotEmpty
                                        ? group.name[0].toUpperCase()
                                        : 'G',
                                    style: const TextStyle(
                                      color: Color(0xFF0D6B4F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (group.isPrivate)
                                      const Icon(
                                        Icons.lock_outline,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      group.lastMessageText ??
                                          (group.description ??
                                              'No messages yet.'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${group.memberCount} members',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0D6B4F),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF94A3B8),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GroupChatScreen(group: group),
                                    ),
                                  ).then((_) => _fetchGroups());
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFF0D6B4F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Group',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
