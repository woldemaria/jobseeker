import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/avatar_helper.dart';
import '../authentication/login_screen.dart';
import 'edit_profile_screen.dart';
import 'skills_management_screen.dart';
import 'education_management_screen.dart';
import 'experience_management_screen.dart';
import 'cv_management_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/chat_groups_screen.dart';
import '../admin/advertisement_management_screen.dart';
import '../admin/admin_main_screen.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/advertisement_repository.dart';
import '../../services/storage_service.dart';
import '../advertising/ad_consent_modal.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileRepository profRepo;
  final AuthService authService;

  const ProfileScreen({
    super.key,
    required this.profRepo,
    required this.authService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await widget.profRepo.getProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final jobRepo = Provider.of<JobRepository>(context, listen: false);
    final appRepo = Provider.of<ApplicationRepository>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    await widget.authService.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          jobRepo: jobRepo,
          appRepo: appRepo,
          profRepo: widget.profRepo,
          apiService: apiService,
        ),
      ),
      (route) => false,
    );
  }

  void _showLanguageDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: const Icon(Icons.language),
              trailing: widget.authService.currentLocale.languageCode == 'en'
                  ? const Icon(Icons.check, color: Color(0xFF0D6B4F))
                  : null,
              onTap: () {
                widget.authService.setLanguage('en');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('አማርኛ (Amharic)'),
              leading: const Icon(Icons.language),
              trailing: widget.authService.currentLocale.languageCode == 'am'
                  ? const Icon(Icons.check, color: Color(0xFF0D6B4F))
                  : null,
              onTap: () {
                widget.authService.setLanguage('am');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('profile'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF0D6B4F),
                          backgroundImage: getAvatarImageProvider(user?.profilePhoto),
                          child: getAvatarImageProvider(user?.profilePhoto) == null
                              ? Text(
                                  (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Candidate',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              if (_profile?['location'] != null && _profile!['location'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF0D6B4F)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _profile!['location'].toString(),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF0D6B4F)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Management Navigation List
                _buildTile(
                  icon: Icons.person_outline,
                  title: 'Edit Personal Details',
                  subtitle: 'Update name, contact, education level, and biography',
                  onTap: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileFormScreen(
                          profRepo: widget.profRepo,
                          authService: widget.authService,
                        ),
                      ),
                    );
                    if (updated == true) _load();
                  },
                ),
                _buildTile(
                  icon: Icons.stars_outlined,
                  title: loc.t('my_skills'),
                  subtitle: 'Manage professional technical & soft skills',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SkillsManagementScreen(profRepo: widget.profRepo),
                      ),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.school_outlined,
                  title: loc.t('my_education'),
                  subtitle: 'Degrees, qualifications, universities, and grades',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EducationManagementScreen(profRepo: widget.profRepo),
                      ),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.work_outline,
                  title: loc.t('my_experience'),
                  subtitle: 'Employment history and previous company roles',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExperienceManagementScreen(profRepo: widget.profRepo),
                      ),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.description_outlined,
                  title: loc.t('manage_cv'),
                  subtitle: 'Upload and manage PDF CVs and certificates',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CvManagementScreen(profRepo: widget.profRepo),
                      ),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.notifications_none_outlined,
                  title: loc.t('notifications'),
                  subtitle: 'Recruitment status updates and notifications',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationsScreen(profRepo: widget.profRepo),
                      ),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.forum_outlined,
                  title: 'Friends & Community Chat',
                  subtitle: 'Join career groups, discuss jobs, and network with friends',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatGroupsScreen(),
                      ),
                    );
                  },
                ),
                if (widget.authService.currentUser?.isAdmin == true)
                  _buildTile(
                    icon: Icons.admin_panel_settings,
                    iconColor: Colors.deepPurple,
                    title: 'Administrator Console',
                    subtitle: 'Manage platform users, employer verifications & reports',
                    onTap: () {
                      final adminRepo = Provider.of<AdminRepository>(context, listen: false);
                      final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminMainScreen(
                            adminRepo: adminRepo,
                            adRepo: adRepo,
                            authService: widget.authService,
                          ),
                        ),
                      );
                    },
                  ),
                if (user?.isAdmin == true || user?.isEmployer == true)
                  _buildTile(
                    icon: Icons.campaign_outlined,
                    title: loc.t('advertisements'),
                    subtitle: 'Manage promotional campaigns & view CTR analytics',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdvertisementManagementScreen(),
                        ),
                      );
                    },
                  ),
                _buildTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Cookie & Advertising Privacy',
                  subtitle: 'Manage personalized recommendations and marketing consent',
                  onTap: () {
                    final storage = Provider.of<StorageService>(context, listen: false);
                    AdConsentModal.show(context, storageService: storage);
                  },
                ),
                _buildTile(
                  icon: Icons.language,
                  title: loc.t('language'),
                  subtitle: widget.authService.currentLocale.languageCode == 'am'
                      ? 'አማርኛ (Amharic)'
                      : 'English',
                  onTap: _showLanguageDialog,
                ),
                _buildTile(
                  icon: Icons.logout,
                  title: loc.t('logout'),
                  iconColor: const Color(0xFFDC2626),
                  textColor: const Color(0xFFDC2626),
                  onTap: _logout,
                ),
              ],
            ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? const Color(0xFF0D6B4F)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}
