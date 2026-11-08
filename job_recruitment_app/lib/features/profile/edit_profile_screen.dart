import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

export 'profile_form_screen.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/avatar_helper.dart';
import 'cv_management_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileRepository profRepo;
  final AuthService authService;

  const EditProfileScreen({
    super.key,
    required this.profRepo,
    required this.authService,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _educationLevelController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();
  String? _gender;
  String? _profilePhoto;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingFile = false;

  static final List<Map<String, String>> _curatedAvatars = [
    {
      'name': 'Corporate Leader',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
    },
    {
      'name': 'Executive Manager',
      'url': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=300&q=80',
    },
    {
      'name': 'Software Engineer',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
    },
    {
      'name': 'Business Consultant',
      'url': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=300&q=80',
    },
    {
      'name': 'Product Specialist',
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
    },
    {
      'name': 'Creative Designer',
      'url': 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?auto=format&fit=crop&w=300&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.profRepo.getProfile();
    final user = widget.authService.currentUser;
    if (mounted) {
      if (user != null) {
        _nameController.text = user.name;
        _phoneController.text = user.phone ?? '';
        _profilePhoto = user.profilePhoto;
      }
      if (profile != null) {
        _locationController.text = profile['location'] ?? '';
        _educationLevelController.text = profile['education_level'] ?? '';
        _fieldOfStudyController.text = profile['field_of_study'] ?? '';
        _experienceController.text = (profile['experience_years'] ?? 0)
            .toString();
        _bioController.text = profile['biography'] ?? '';
        _gender = profile['gender'];
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImageFromDisk(BuildContext ctx) async {
    setState(() => _isPickingFile = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last.toLowerCase();
        final mime = (ext == 'png')
            ? 'image/png'
            : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

        setState(() {
          _profilePhoto = dataUri;
        });
        if (mounted && Navigator.canPop(ctx)) {
          Navigator.pop(ctx);
        }

        // Upload directly to server storage endpoint
        final uploadResp = await widget.profRepo.uploadProfilePhoto(
          bytes,
          file.name,
        );
        if (uploadResp.success && uploadResp.data != null) {
          final serverUrl = uploadResp.data['profile_photo'] as String?;
          if (serverUrl != null && serverUrl.isNotEmpty) {
            if (mounted) {
              setState(() {
                _profilePhoto = serverUrl;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Profile photo uploaded and saved successfully!',
                  ),
                  backgroundColor: Color(0xFF0D6B4F),
                ),
              );
            }
            await widget.authService.refreshUser();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  void _showPhotoPicker() {
    final customUrlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (bottomCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // Upload from Disk Button
              InkWell(
                onTap: _isPickingFile ? null : () => _pickImageFromDisk(ctx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6B4F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0D6B4F),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.file_upload_outlined,
                        color: Color(0xFF0D6B4F),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPickingFile
                            ? 'Selecting Photo...'
                            : 'Upload Photo from Device / Disk',
                        style: const TextStyle(
                          color: Color(0xFF0D6B4F),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Or choose a professional avatar:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _curatedAvatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, index) {
                  final avatar = _curatedAvatars[index];
                  final isSelected = _profilePhoto == avatar['url'];

                  return InkWell(
                    onTap: () {
                      setState(() => _profilePhoto = avatar['url']);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D6B4F)
                              : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                        color: isSelected
                            ? const Color(0xFF0D6B4F).withOpacity(0.08)
                            : Colors.white,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundImage: NetworkImage(avatar['url']!),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            avatar['name']!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF0D6B4F)
                                  : const Color(0xFF334155),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: customUrlController,
                decoration: InputDecoration(
                  labelText: 'Or enter custom image URL',
                  hintText: 'https://...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check, color: Color(0xFF0D6B4F)),
                    onPressed: () {
                      final text = customUrlController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() => _profilePhoto = text);
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_profilePhoto != null)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _profilePhoto = null);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                      size: 16,
                    ),
                    label: const Text(
                      'Remove Photo',
                      style: TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final resp = await widget.profRepo.updateProfile({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'profile_photo': _profilePhoto,
      'location': _locationController.text.trim(),
      'education_level': _educationLevelController.text.trim(),
      'field_of_study': _fieldOfStudyController.text.trim(),
      'experience_years':
          double.tryParse(_experienceController.text.trim()) ?? 0,
      'biography': _bioController.text.trim(),
      'gender': _gender,
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (resp.success) {
        await widget.authService.checkAuthStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resp.message)));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _educationLevelController.dispose();
    _fieldOfStudyController.dispose();
    _experienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final avatarProvider = getAvatarImageProvider(_profilePhoto);

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('profile'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Photo selector
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoPicker,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0D6B4F).withOpacity(0.08),
                            border: Border.all(
                              color: const Color(0xFF0D6B4F),
                              width: 2.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: avatarProvider != null
                              ? Image(
                                  image: avatarProvider,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.person,
                                        size: 52,
                                        color: Color(0xFF0D6B4F),
                                      ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 52,
                                  color: Color(0xFF0D6B4F),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showPhotoPicker,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D6B4F),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _showPhotoPicker,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 16,
                      color: Color(0xFF0D6B4F),
                    ),
                    label: Text(
                      _profilePhoto != null
                          ? 'Change Profile Photo'
                          : 'Upload Profile Photo',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0D6B4F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: loc.t('name'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: loc.t('phone'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: loc.t('location'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _educationLevelController,
                  decoration: InputDecoration(
                    labelText: loc.t('education'),
                    prefixIcon: const Icon(Icons.school_outlined),
                    hintText: 'e.g. Bachelor Degree, Master, PhD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fieldOfStudyController,
                  decoration: InputDecoration(
                    labelText: loc.t('field_of_study'),
                    prefixIcon: const Icon(Icons.menu_book_outlined),
                    hintText: 'e.g. Computer Science, Electrical Eng',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _experienceController,
                  decoration: InputDecoration(
                    labelText: loc.t('experience_years'),
                    prefixIcon: const Icon(Icons.timeline_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.people_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) => setState(() => _gender = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: loc.t('biography'),
                    hintText: 'Brief summary of your background...',
                  ),
                ),
                const SizedBox(height: 20),

                // CV & Documents Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  color: const Color(0xFFF8FAFC),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D6B4F)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.description,
                                color: Color(0xFF0D6B4F),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Curriculum Vitae (CV) & Files',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Upload and manage your CVs from disk to apply for jobs.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CvManagementScreen(
                                    profRepo: widget.profRepo,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              color: Color(0xFF0D6B4F),
                              size: 18,
                            ),
                            label: const Text(
                              'Manage & Upload CV from Disk',
                              style: TextStyle(color: Color(0xFF0D6B4F)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(loc.t('save')),
                ),
              ],
            ),
    );
  }
}
