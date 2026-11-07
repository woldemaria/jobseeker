import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../repositories/profile_repository.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/avatar_helper.dart';
import 'cv_management_screen.dart';

class ProfileFormScreen extends StatefulWidget {
  final ProfileRepository profRepo;
  final AuthService authService;

  const ProfileFormScreen({
    super.key,
    required this.profRepo,
    required this.authService,
  });

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _educationLevelController = TextEditingController();
  final _fieldOfStudyController = TextEditingController();
  final _experienceController = TextEditingController();
  final _bioController = TextEditingController();

  // State Variables
  String? _gender;
  String? _profilePhoto;
  DateTime? _dateOfBirth;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  // Professional Server-side Error Mapping
  Map<String, String> _serverFieldErrors = {};
  String? _generalErrorMessage;

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
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _generalErrorMessage = null;
    });

    try {
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
          _experienceController.text = (profile['experience_years'] ?? 0).toString();
          _bioController.text = profile['biography'] ?? '';
          _gender = profile['gender']?.toString().toLowerCase();

          if (profile['date_of_birth'] != null) {
            try {
              _dateOfBirth = DateTime.parse(profile['date_of_birth']);
            } catch (_) {}
          }
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _generalErrorMessage = 'Failed to load profile details: $e';
        });
      }
    }
  }

  Future<void> _pickImageFromDisk(BuildContext modalCtx) async {
    setState(() => _isPickingPhoto = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last.toLowerCase();
        final mime = (ext == 'png') ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

        setState(() {
          _profilePhoto = dataUri;
        });
        if (mounted && Navigator.canPop(modalCtx)) {
          Navigator.pop(modalCtx);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error choosing image from device: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _showPhotoPickerModal() {
    final customUrlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Update Profile Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              // Upload from Device Disk
              InkWell(
                onTap: _isPickingPhoto ? null : () => _pickImageFromDisk(ctx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6B4F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D6B4F), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_outlined, color: Color(0xFF0D6B4F), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _isPickingPhoto ? 'Selecting Image...' : 'Pick Photo from Storage / Disk',
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
                'Or select from curated executive avatars:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
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
                          color: isSelected ? const Color(0xFF0D6B4F) : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1,
                        ),
                        color: isSelected ? const Color(0xFF0D6B4F).withOpacity(0.08) : Colors.white,
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
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF0D6B4F) : const Color(0xFF334155),
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
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 16),
                    label: const Text('Remove Photo', style: TextStyle(color: Color(0xFFDC2626))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitProfile() async {
    // Reset server errors
    setState(() {
      _serverFieldErrors = {};
      _generalErrorMessage = null;
    });

    // Client-side form validation
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the validation errors in the form before saving.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'profile_photo': _profilePhoto,
        'location': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        'education_level': _educationLevelController.text.trim().isNotEmpty ? _educationLevelController.text.trim() : null,
        'field_of_study': _fieldOfStudyController.text.trim().isNotEmpty ? _fieldOfStudyController.text.trim() : null,
        'experience_years': double.tryParse(_experienceController.text.trim()) ?? 0.0,
        'biography': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        'gender': _gender,
      };

      if (_dateOfBirth != null) {
        payload['date_of_birth'] =
            "${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}";
      }

      final resp = await widget.profRepo.updateProfile(payload);

      if (mounted) {
        setState(() => _isSaving = false);
        if (resp.success) {
          await widget.authService.checkAuthStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved and updated successfully!'),
              backgroundColor: Color(0xFF0D6B4F),
            ),
          );
          Navigator.pop(context, true);
        } else {
          // Map backend server-side errors
          final Map<String, String> fieldErrors = {};
          if (resp.errors != null) {
            resp.errors!.forEach((key, val) {
              if (val is List && val.isNotEmpty) {
                fieldErrors[key] = val.first.toString();
              } else if (val is String) {
                fieldErrors[key] = val;
              }
            });
          }

          setState(() {
            _serverFieldErrors = fieldErrors;
            _generalErrorMessage = resp.message.isNotEmpty ? resp.message : 'Failed to update profile.';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_generalErrorMessage!),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _generalErrorMessage = 'Unexpected connection error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_generalErrorMessage!),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
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
      appBar: AppBar(
        title: const Text('Professional Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _submitProfile,
            icon: _isSaving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check, color: Colors.white, size: 18),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Server / General Error Alert
                  if (_generalErrorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _generalErrorMessage!,
                              style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Avatar & Profile Photo Section
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _showPhotoPickerModal,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0D6B4F).withOpacity(0.08),
                              border: Border.all(color: const Color(0xFF0D6B4F), width: 2.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: avatarProvider != null
                                ? Image(
                                    image: avatarProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.person, size: 54, color: Color(0xFF0D6B4F)),
                                  )
                                : const Icon(Icons.person, size: 54, color: Color(0xFF0D6B4F)),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showPhotoPickerModal,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D6B4F),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _showPhotoPickerModal,
                      icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF0D6B4F)),
                      label: Text(
                        _profilePhoto != null ? 'Change Profile Avatar' : 'Upload Profile Avatar',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF0D6B4F), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section 1: Basic Information
                  _buildSectionHeader('Personal Information', Icons.badge_outlined),
                  const SizedBox(height: 10),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '${loc.t('name')} *',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: _serverFieldErrors['name'],
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Full name is required.';
                      }
                      if (val.trim().length < 2) {
                        return 'Name must be at least 2 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: loc.t('phone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      hintText: '+251911223344',
                      errorText: _serverFieldErrors['phone'],
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final reg = RegExp(r'^[0-9\+\-\s\(\)]+$');
                        if (!reg.hasMatch(val.trim())) {
                          return 'Please enter a valid phone number format.';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Location Field
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: loc.t('location'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      hintText: 'e.g. Bole, Addis Ababa, Ethiopia',
                      errorText: _serverFieldErrors['location'],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date of Birth & Gender Row
                  Row(
                    children: [
                      // Date of Birth
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _dateOfBirth ?? DateTime(1998, 1, 1),
                              firstDate: DateTime(1950),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _dateOfBirth = d);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              errorText: _serverFieldErrors['date_of_birth'],
                            ),
                            child: Text(
                              _dateOfBirth != null
                                  ? "${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}"
                                  : 'Select Date',
                              style: TextStyle(
                                color: _dateOfBirth != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Gender Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            prefixIcon: const Icon(Icons.people_outline),
                            errorText: _serverFieldErrors['gender'],
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (val) => setState(() => _gender = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Career & Qualifications
                  _buildSectionHeader('Professional Qualifications', Icons.school_outlined),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _educationLevelController,
                    decoration: InputDecoration(
                      labelText: loc.t('education'),
                      prefixIcon: const Icon(Icons.school_outlined),
                      hintText: 'e.g. Bachelor Degree, Master of Science, PhD',
                      errorText: _serverFieldErrors['education_level'],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _fieldOfStudyController,
                    decoration: InputDecoration(
                      labelText: loc.t('field_of_study'),
                      prefixIcon: const Icon(Icons.menu_book_outlined),
                      hintText: 'e.g. Computer Science, Civil Engineering',
                      errorText: _serverFieldErrors['field_of_study'],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _experienceController,
                    decoration: InputDecoration(
                      labelText: loc.t('experience_years'),
                      prefixIcon: const Icon(Icons.timeline_outlined),
                      hintText: 'e.g. 3.5',
                      errorText: _serverFieldErrors['experience_years'],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final num = double.tryParse(val.trim());
                        if (num == null) {
                          return 'Years of experience must be a numeric value.';
                        }
                        if (num < 0 || num > 60) {
                          return 'Please provide a valid experience between 0 and 60 years.';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Biography
                  _buildSectionHeader('Professional Summary', Icons.description_outlined),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: loc.t('biography'),
                      hintText: 'Summarize your expertise, career accomplishments, and professional objectives...',
                      errorText: _serverFieldErrors['biography'],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 4: CV Document Card
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
                                  color: const Color(0xFF0D6B4F).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.folder_shared, color: Color(0xFF0D6B4F), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Curriculum Vitae (CV) & Documents',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'Attach your verified CV from disk so employers can review your profile.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                                    builder: (_) => CvManagementScreen(profRepo: widget.profRepo),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.upload_file, color: Color(0xFF0D6B4F), size: 18),
                              label: const Text('Manage & Upload CV from Disk', style: TextStyle(color: Color(0xFF0D6B4F))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submitProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(loc.t('save')),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0D6B4F)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ],
    );
  }
}
