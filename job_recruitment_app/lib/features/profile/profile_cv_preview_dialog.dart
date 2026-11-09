import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/skill_model.dart';
import '../../repositories/profile_repository.dart';

class ProfileCvPreviewDialog extends StatefulWidget {
  final ProfileRepository profRepo;

  const ProfileCvPreviewDialog({super.key, required this.profRepo});

  static void show(BuildContext context, {required ProfileRepository profRepo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ProfileCvPreviewDialog(profRepo: profRepo),
    );
  }

  @override
  State<ProfileCvPreviewDialog> createState() => _ProfileCvPreviewDialogState();
}

class _ProfileCvPreviewDialogState extends State<ProfileCvPreviewDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  List<dynamic> _education = [];
  List<dynamic> _experience = [];
  List<SkillModel> _skills = [];
  List<Map<String, dynamic>> _badges = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final p = await widget.profRepo.getProfile();
      final skills = await widget.profRepo.getUserSkills();
      final badges = await widget.profRepo.getUserBadges();

      if (mounted) {
        setState(() {
          _profile = p;
          _skills = skills;
          _badges = badges;
          _education = (p?['education_records'] as List?) ?? [];
          _experience = (p?['work_experiences'] as List?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to generate profile CV: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _generateCvMarkdown() {
    final user = _profile?['user'] as Map<String, dynamic>?;
    final name = user?['name'] ?? 'Candidate Name';
    final email = user?['email'] ?? 'email@example.com';
    final phone = user?['phone'] ?? '+251 9...';
    final title = _profile?['professional_title'] ?? 'Professional';
    final bio = _profile?['bio'] ?? 'Dedicated professional seeking opportunities.';
    final location = _profile?['current_location'] ?? 'Addis Ababa, Ethiopia';

    final sb = StringBuffer();
    sb.writeln('# $name');
    sb.writeln('**$title** | $location');
    sb.writeln('Email: $email | Phone: $phone\n');

    sb.writeln('## Professional Summary');
    sb.writeln('$bio\n');

    if (_badges.isNotEmpty) {
      sb.writeln('## Verified Ethiopian Skill Badges');
      for (final b in _badges) {
        final sName = b['skill']?['name'] ?? 'Skill';
        final score = b['score'] ?? 0;
        sb.writeln('- $sName: Verified ($score% assessment score)');
      }
      sb.writeln('');
    }

    if (_experience.isNotEmpty) {
      sb.writeln('## Professional Experience');
      for (final exp in _experience) {
        final pos = exp['job_title'] ?? 'Role';
        final company = exp['company_name'] ?? 'Company';
        final start = exp['start_date'] ?? '';
        final end = exp['is_current'] == true ? 'Present' : (exp['end_date'] ?? '');
        final desc = exp['responsibilities'] ?? exp['description'] ?? '';
        sb.writeln('### $pos - $company ($start - $end)');
        if (desc.isNotEmpty) sb.writeln('$desc');
        sb.writeln('');
      }
    }

    if (_education.isNotEmpty) {
      sb.writeln('## Education & Qualifications');
      for (final edu in _education) {
        final qual = edu['qualification'] ?? edu['degree'] ?? 'Degree';
        final inst = edu['institution_name'] ?? 'Institution';
        final field = edu['field_of_study'] ?? '';
        final year = edu['graduation_year'] ?? '';
        sb.writeln('- **$qual${field.isNotEmpty ? " in $field" : ""}** - $inst ($year)');
      }
      sb.writeln('');
    }

    if (_skills.isNotEmpty) {
      sb.writeln('## Skills & Competencies');
      final skillNames = _skills.map((s) => s.name).join(', ');
      sb.writeln('$skillNames\n');
    }

    return sb.toString();
  }

  void _copyCv() {
    final text = _generateCvMarkdown();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Standard Ethiopian CV copied to clipboard!'),
        backgroundColor: Color(0xFF0D6B4F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile?['user'] as Map<String, dynamic>?;
    final name = user?['name'] ?? 'Candidate Name';
    final email = user?['email'] ?? 'email@example.com';
    final phone = user?['phone'] ?? '+251 9...';
    final title = _profile?['professional_title'] ?? 'Professional';
    final bio = _profile?['bio'] ?? 'Dedicated professional in Ethiopia.';
    final location = _profile?['current_location'] ?? 'Addis Ababa, Ethiopia';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.picture_as_pdf, color: Color(0xFF0D6B4F)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Standard Ethiopian Curriculum Vitae',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Auto-compiled from verified profile records',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                tooltip: 'Copy Text',
                onPressed: _isLoading ? null : _copyCv,
              ),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView(
                          children: [
                            // CV Header
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D6B4F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(location, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                const SizedBox(width: 14),
                                const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 14),

                            // Summary
                            const Text(
                              'PROFESSIONAL SUMMARY',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: Color(0xFF0D6B4F),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bio,
                              style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 16),

                            // Verified Badges Section
                            if (_badges.isNotEmpty) ...[
                              const Text(
                                'VERIFIED ETHIOPIAN SKILL BADGES',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF0D6B4F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _badges.map((b) {
                                  final sName = b['skill']?['name'] ?? 'Skill';
                                  final score = b['score'] ?? 0;
                                  return Chip(
                                    avatar: const Icon(Icons.verified, size: 16, color: Color(0xFF0D6B4F)),
                                    label: Text(
                                      '$sName ($score%)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: const Color(0xFFDCFCE7),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Work Experience Section
                            if (_experience.isNotEmpty) ...[
                              const Text(
                                'WORK EXPERIENCE',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF0D6B4F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._experience.map((exp) {
                                final pos = exp['job_title'] ?? 'Role';
                                final comp = exp['company_name'] ?? 'Company';
                                final start = exp['start_date'] ?? '';
                                final end = exp['is_current'] == true ? 'Present' : (exp['end_date'] ?? '');
                                final desc = exp['responsibilities'] ?? exp['description'] ?? '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pos,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '$comp • $start - $end',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(desc, style: const TextStyle(fontSize: 12, height: 1.3)),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 10),
                            ],

                            // Education Section
                            if (_education.isNotEmpty) ...[
                              const Text(
                                'EDUCATION',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF0D6B4F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._education.map((edu) {
                                final qual = edu['qualification'] ?? edu['degree'] ?? 'Degree';
                                final inst = edu['institution_name'] ?? 'Institution';
                                final field = edu['field_of_study'] ?? '';
                                final year = edu['graduation_year'] ?? '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.school_outlined, size: 16, color: Color(0xFF64748B)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$qual${field.isNotEmpty ? " in $field" : ""}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text('$inst • $year', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 10),
                            ],

                            // Skills Section
                            if (_skills.isNotEmpty) ...[
                              const Text(
                                'CORE COMPETENCIES',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF0D6B4F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _skills.map((s) => Chip(
                                  label: Text(s.name, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  visualDensity: VisualDensity.compact,
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _copyCv,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Resume Text'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6B4F),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
