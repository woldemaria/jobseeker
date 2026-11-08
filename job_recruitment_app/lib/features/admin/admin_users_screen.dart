import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/admin_repository.dart';
import '../../shared/utils/avatar_helper.dart';

class AdminUsersScreen extends StatefulWidget {
  final AdminRepository adminRepo;

  const AdminUsersScreen({super.key, required this.adminRepo});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _selectedRole = 'all';
  String _selectedStatus = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await widget.adminRepo.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final status = (u['status'] ?? '').toString().toLowerCase();

      final roles =
          (u['roles'] as List?)
              ?.map((r) => r is Map ? r['name'] : r.toString())
              .toList() ??
          [];

      final matchesQuery =
          query.isEmpty || name.contains(query) || email.contains(query);
      final matchesRole =
          _selectedRole == 'all' || roles.contains(_selectedRole);
      final matchesStatus =
          _selectedStatus == 'all' || status == _selectedStatus;

      return matchesQuery && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _updateStatus(
    int userId,
    String userName,
    String currentStatus,
  ) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Update Status for $userName'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'active'),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Active (Permit Access)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'suspended'),
            child: const Row(
              children: [
                Icon(Icons.block, color: Colors.amber),
                SizedBox(width: 8),
                Text('Suspended (Temporarily Freeze)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'deactivated'),
            child: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text('Deactivated (Close Account)'),
              ],
            ),
          ),
        ],
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      final success = await widget.adminRepo.updateUserStatus(
        userId,
        newStatus,
      );
      if (mounted) {
        if (success) {
          _loadUsers();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User $userName status set to $newStatus')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update user status')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search user by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['all', 'job_seeker', 'employer', 'administrator'].map((
                role,
              ) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(role.replaceAll('_', ' ').toUpperCase()),
                    onSelected: (_) {
                      setState(() => _selectedRole = role);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['all', 'active', 'pending', 'suspended'].map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: isSelected,
                    label: Text('Status: ${status.toUpperCase()}'),
                    onSelected: (_) {
                      setState(() => _selectedStatus = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                ? const Center(child: Text('No users match criteria.'))
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final user = list[index];
                        final id = user['id'] as int;
                        final name = user['name'] ?? 'User';
                        final email = user['email'] ?? '';
                        final status = user['status'] ?? 'active';
                        final photo = user['profile_photo'];
                        final roles =
                            (user['roles'] as List?)
                                ?.map(
                                  (r) => r is Map ? r['name'] : r.toString(),
                                )
                                .join(', ') ??
                            'job_seeker';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: Builder(
                              builder: (context) {
                                final avatarProvider = getAvatarImageProvider(
                                  photo,
                                );
                                return CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor
                                      .withOpacity(0.12),
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'U',
                                        )
                                      : null,
                                );
                              },
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Roles: $roles',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            trailing: InkWell(
                              onTap: () => _updateStatus(id, name, status),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(status),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.amber.shade800;
      case 'suspended':
        return Colors.orange;
      case 'deactivated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
