import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../l10n/app_localizations.dart';

import 'package:provider/provider.dart';

import '../../repositories/admin_repository.dart';
import '../../repositories/advertisement_repository.dart';
import '../admin/admin_main_screen.dart';
import '../job_seeker/job_seeker_main_screen.dart';
import '../employer/employer_main_screen.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository profRepo;
  final ApiService apiService;

  const RegisterScreen({
    super.key,
    required this.authService,
    required this.jobRepo,
    required this.appRepo,
    required this.profRepo,
    required this.apiService,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _selectedRole = 'job_seeker';
  String? _selectedProfilePhoto;
  List<int>? _pickedPhotoBytes;
  String? _pickedPhotoFilename;
  List<int>? _pickedCvBytes;
  String? _pickedCvFilename;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Curated Professional Profile Avatars
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

  void _showPhotoPickerSheet() {
    final customUrlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              'Choose Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a file from your disk or choose an avatar below:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Pick from Disk Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final files = await FilePicker.pickFiles(
                      type: FileType.image,
                    );
                    if (files.isNotEmpty) {
                      final f = files.first;
                      final bytes = await f.readAsBytes();
                      setState(() {
                        _pickedPhotoBytes = bytes;
                        _pickedPhotoFilename = f.name;
                        _selectedProfilePhoto = null;
                      });
                      Navigator.pop(ctx);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open file picker: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.drive_folder_upload),
                label: const Text('Upload Photo from Disk / Files'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or select a curated professional avatar:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            // Avatars Grid
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
                final isSelected = _selectedProfilePhoto == avatar['url'];

                return InkWell(
                  onTap: () {
                    setState(() => _selectedProfilePhoto = avatar['url']);
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
                        const SizedBox(height: 6),
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
            const SizedBox(height: 16),

            // Custom URL option
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
                      setState(() => _selectedProfilePhoto = text);
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedProfilePhoto != null)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedProfilePhoto = null);
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
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill all required fields.');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final resp = await widget.authService.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: confirm,
      role: _selectedRole,
      phone: phone.isNotEmpty ? phone : null,
      profilePhoto: _selectedProfilePhoto,
      photoBytes: _pickedPhotoBytes,
      photoFilename: _pickedPhotoFilename,
      cvBytes: _selectedRole == 'job_seeker' ? _pickedCvBytes : null,
      cvFilename: _selectedRole == 'job_seeker' ? _pickedCvFilename : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (resp.success && widget.authService.currentUser != null) {
        final user = widget.authService.currentUser!;
        if (user.isAdmin) {
          final adminRepo = Provider.of<AdminRepository>(
            context,
            listen: false,
          );
          final adRepo = Provider.of<AdvertisementRepository>(
            context,
            listen: false,
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => AdminMainScreen(
                adminRepo: adminRepo,
                adRepo: adRepo,
                authService: widget.authService,
              ),
            ),
            (route) => false,
          );
        } else if (user.isEmployer) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => EmployerMainScreen(
                jobRepo: widget.jobRepo,
                appRepo: widget.appRepo,
                profRepo: widget.profRepo,
                apiService: widget.apiService,
                authService: widget.authService,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => JobSeekerMainScreen(
                jobRepo: widget.jobRepo,
                appRepo: widget.appRepo,
                profRepo: widget.profRepo,
                authService: widget.authService,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        setState(() => _errorMessage = resp.formattedErrorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('register'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Profile Photo Picker Avatar at top of registration
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _showPhotoPickerSheet,
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _pickedPhotoBytes != null
                          ? Image.memory(
                              Uint8List.fromList(_pickedPhotoBytes!),
                              fit: BoxFit.cover,
                            )
                          : _selectedProfilePhoto != null
                          ? Image.network(
                              _selectedProfilePhoto!,
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
                      onTap: _showPhotoPickerSheet,
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
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _selectedProfilePhoto != null
                    ? 'Profile Photo Selected (Tap to change)'
                    : 'Add Profile Photo (Optional)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFF991B1B)),
                ),
              ),

            // Role selection Segmented Buttons
            Text(
              loc.t('role'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        loc.t('job_seeker'),
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: _selectedRole == 'job_seeker',
                    selectedColor: const Color(0xFF0D6B4F).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: _selectedRole == 'job_seeker'
                          ? const Color(0xFF0D6B4F)
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedRole = 'job_seeker');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        loc.t('employer'),
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: _selectedRole == 'employer',
                    selectedColor: const Color(0xFF0D6B4F).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: _selectedRole == 'employer'
                          ? const Color(0xFF0D6B4F)
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedRole = 'employer');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        loc.t('administrator'),
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: _selectedRole == 'administrator',
                    selectedColor: const Color(0xFF0D6B4F).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: _selectedRole == 'administrator'
                          ? const Color(0xFF0D6B4F)
                          : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedRole = 'administrator');
                    },
                  ),
                ),
              ],
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
              controller: _emailController,
              decoration: InputDecoration(
                labelText: loc.t('email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
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
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: loc.t('password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: loc.t('confirm_password'),
                prefixIcon: const Icon(Icons.lock_clock_outlined),
              ),
            ),

            // Optional CV File Upload from Disk for Job Seekers
            if (_selectedRole == 'job_seeker') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: Color(0xFF0D6B4F),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Attach Resume / CV from Disk (Optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attach your PDF or DOCX resume directly from disk to complete your profile at registration.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_pickedCvFilename != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6B4F).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Color(0xFF0D6B4F),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _pickedCvFilename!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() {
                                _pickedCvBytes = null;
                                _pickedCvFilename = null;
                              }),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final files = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'doc', 'docx'],
                            );
                            if (files.isNotEmpty) {
                              final f = files.first;
                              final bytes = await f.readAsBytes();
                              setState(() {
                                _pickedCvBytes = bytes;
                                _pickedCvFilename = f.name;
                              });
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not open file picker: $e'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text(
                          'Choose CV File from Disk (PDF / Word)',
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(loc.t('register')),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(loc.t('already_have_account')),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.t('login')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
