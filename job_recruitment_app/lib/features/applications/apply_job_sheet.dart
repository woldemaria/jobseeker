import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/document_model.dart';
import '../../models/job_model.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';

class ApplyJobSheet extends StatefulWidget {
  final JobModel job;
  final ApplicationRepository applicationRepo;
  final ProfileRepository profileRepo;
  final VoidCallback onApplied;

  const ApplyJobSheet({
    super.key,
    required this.job,
    required this.applicationRepo,
    required this.profileRepo,
    required this.onApplied,
  });

  static void show(
    BuildContext context,
    JobModel job,
    ApplicationRepository appRepo,
    ProfileRepository profRepo,
    VoidCallback onApplied,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ApplyJobSheet(
        job: job,
        applicationRepo: appRepo,
        profileRepo: profRepo,
        onApplied: onApplied,
      ),
    );
  }

  @override
  State<ApplyJobSheet> createState() => _ApplyJobSheetState();
}

class _ApplyJobSheetState extends State<ApplyJobSheet> {
  final _coverLetterController = TextEditingController();
  List<DocumentModel> _cvDocuments = [];
  int? _selectedCvId;
  bool _isLoadingDocs = true;
  bool _isUploadingCv = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCvs();
  }

  Future<void> _fetchCvs({int? selectDocId}) async {
    try {
      final docs = await widget.profileRepo.getDocuments();
      final cvs = docs
          .where(
            (d) =>
                d.documentType.toLowerCase() == 'cv' ||
                d.documentType.toLowerCase() == 'resume',
          )
          .toList();
      final usableDocs = cvs.isNotEmpty ? cvs : docs;
      if (mounted) {
        setState(() {
          _cvDocuments = usableDocs;
          if (selectDocId != null) {
            _selectedCvId = selectDocId;
          } else if (usableDocs.isNotEmpty &&
              (_selectedCvId == null ||
                  !usableDocs.any((d) => d.id == _selectedCvId))) {
            _selectedCvId = usableDocs.first.id;
          }
          _isLoadingDocs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDocs = false;
          _errorMessage = 'Could not load your saved documents: $e';
        });
      }
    }
  }

  Future<void> _pickAndUploadCvFromDisk() async {
    setState(() {
      _isUploadingCv = true;
      _errorMessage = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (files.isNotEmpty) {
        final f = files.first;
        final Uint8List bytes = await f.readAsBytes();

        final resp = await widget.profileRepo.uploadDocumentBytes(
          bytes,
          f.name,
          'cv',
        );
        if (resp.success && resp.data != null) {
          final newDocId = resp.data['id'] as int?;
          await _fetchCvs(selectDocId: newDocId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'CV "${f.name}" uploaded from disk and selected!',
                ),
                backgroundColor: const Color(0xFF0D6B4F),
              ),
            );
          }
        } else {
          setState(
            () => _errorMessage = resp.message.isNotEmpty
                ? resp.message
                : 'CV upload failed.',
          );
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick or upload CV: $e');
    } finally {
      if (mounted) setState(() => _isUploadingCv = false);
    }
  }

  Future<bool> _generateProfileCv() async {
    setState(() {
      _isUploadingCv = true;
      _errorMessage = null;
    });

    try {
      final userProfile = await widget.profileRepo.getProfile();
      final skills = await widget.profileRepo.getUserSkills();
      final experiences = (userProfile?['work_experiences'] as List?) ?? [];
      final educations = (userProfile?['education_records'] as List?) ?? [];

      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('CURRICULUM VITAE - ${widget.job.title.toUpperCase()}');
      buffer.writeln('========================================');
      buffer.writeln(
        'Candidate: ${userProfile?['headline'] ?? "Job Seeker Candidate"}',
      );
      buffer.writeln(
        'Bio: ${userProfile?['bio'] ?? "Dedicated Ethiopian professional"}',
      );
      buffer.writeln(
        'Location: ${userProfile?['location'] ?? widget.job.location}',
      );
      buffer.writeln(
        'Experience: ${userProfile?['experience_years'] ?? 0} years',
      );
      buffer.writeln('');
      buffer.writeln('--- PROFESSIONAL SKILLS ---');
      for (final s in skills) {
        buffer.writeln('• ${s.name} (${s.category})');
      }
      buffer.writeln('');
      buffer.writeln('--- WORK EXPERIENCE ---');
      for (final exp in experiences) {
        buffer.writeln(
          '• ${exp['job_title']} at ${exp['company_name']} (${exp['start_date']} - ${exp['end_date'] ?? "Present"})',
        );
      }
      buffer.writeln('');
      buffer.writeln('--- EDUCATION ---');
      for (final edu in educations) {
        buffer.writeln(
          '• ${edu['degree']} in ${edu['field_of_study']} from ${edu['institution_name']}',
        );
      }

      final bytes = Uint8List.fromList(buffer.toString().codeUnits);
      final filename =
          'Profile_Resume_${DateTime.now().millisecondsSinceEpoch}.txt';

      final resp = await widget.profileRepo.uploadDocumentBytes(
        bytes,
        filename,
        'cv',
      );
      if (resp.success && resp.data != null) {
        final newDocId = resp.data['id'] as int?;
        await _fetchCvs(selectDocId: newDocId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile CV auto-generated and selected!'),
              backgroundColor: Color(0xFF0D6B4F),
            ),
          );
        }
        return true;
      } else {
        setState(
          () => _errorMessage = resp.message.isNotEmpty
              ? resp.message
              : 'Failed to generate profile CV.',
        );
        return false;
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to generate profile CV: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isUploadingCv = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_selectedCvId == null) {
      final generated = await _generateProfileCv();
      if (!generated || _selectedCvId == null) {
        setState(
          () => _errorMessage =
              'Please upload or select a CV/Resume document before submitting.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final resp = await widget.applicationRepo.submitApplication(
        jobId: widget.job.id,
        cvDocumentId: _selectedCvId!,
        coverLetter: _coverLetterController.text.trim().isNotEmpty
            ? _coverLetterController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (resp.success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted successfully! Good luck!'),
              backgroundColor: Color(0xFF0D6B4F),
              duration: Duration(seconds: 4),
            ),
          );
          widget.onApplied();
        } else if (resp.statusCode == 409 ||
            resp.message.toLowerCase().contains('already applied')) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already applied for this vacancy.'),
              backgroundColor: Color(0xFF0D6B4F),
              duration: Duration(seconds: 4),
            ),
          );
          widget.onApplied();
        } else {
          setState(
            () => _errorMessage = resp.message.isNotEmpty
                ? resp.message
                : 'Application submission failed.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Application error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
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
                  color: const Color(0xFF0D6B4F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF0D6B4F),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${loc.t('apply_now')}: ${widget.job.title}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.job.employer?.organizationName ?? 'Employer',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.t('select_cv'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              TextButton.icon(
                onPressed: _isUploadingCv ? null : _pickAndUploadCvFromDisk,
                icon: _isUploadingCv
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.upload_file,
                        size: 16,
                        color: Color(0xFF0D6B4F),
                      ),
                label: Text(
                  _isUploadingCv ? 'Uploading...' : 'Upload CV from Disk',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0D6B4F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (_isLoadingDocs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_cvDocuments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No CV documents uploaded yet. Please upload your CV/Resume file (PDF or DOCX) from your device.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingCv
                              ? null
                              : _pickAndUploadCvFromDisk,
                          icon: _isUploadingCv
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.file_upload, size: 16),
                          label: Text(
                            _isUploadingCv ? 'Uploading...' : 'Upload File',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploadingCv ? null : _generateProfileCv,
                          icon: const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Color(0xFF0D6B4F),
                          ),
                          label: const Text(
                            'Profile as CV',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D6B4F),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<int>(
              value: _selectedCvId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.description_outlined),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _cvDocuments.map((doc) {
                return DropdownMenuItem<int>(
                  value: doc.id,
                  child: Text(
                    '${doc.originalName} (${doc.formattedSize})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCvId = val),
            ),

          const SizedBox(height: 16),
          Text(
            loc.t('cover_letter'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _coverLetterController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe your relevant qualifications, key skills, and passion for this role...',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSubmitting || _isUploadingCv) ? null : _submit,
              icon: (_isSubmitting || _isUploadingCv)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _selectedCvId == null
                    ? 'Generate Profile CV & Apply'
                    : loc.t('submit_application'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
