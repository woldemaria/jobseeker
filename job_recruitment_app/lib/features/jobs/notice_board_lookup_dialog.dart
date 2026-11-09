import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/profile_repository.dart';
import 'job_details_screen.dart';

class NoticeBoardLookupDialog extends StatefulWidget {
  final JobRepository jobRepo;
  final ApplicationRepository appRepo;
  final ProfileRepository? profRepo;

  const NoticeBoardLookupDialog({
    super.key,
    required this.jobRepo,
    required this.appRepo,
    this.profRepo,
  });

  static void show(
    BuildContext context, {
    required JobRepository jobRepo,
    required ApplicationRepository appRepo,
    ProfileRepository? profRepo,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => NoticeBoardLookupDialog(
        jobRepo: jobRepo,
        appRepo: appRepo,
        profRepo: profRepo,
      ),
    );
  }

  @override
  State<NoticeBoardLookupDialog> createState() => _NoticeBoardLookupDialogState();
}

class _NoticeBoardLookupDialogState extends State<NoticeBoardLookupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  JobModel? _matchedJob;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _lookupCode([String? directCode]) async {
    final rawCode = (directCode ?? _codeController.text).trim();
    if (rawCode.isEmpty) {
      setState(() => _errorMessage = 'Please enter a notice board code.');
      return;
    }

    // Extract ID: supports ET-JOB-00001, JOBSEEKER://VACANCY/1, or just 1
    int? jobId;
    if (rawCode.contains('ET-JOB-')) {
      final parts = rawCode.split('ET-JOB-');
      if (parts.length > 1) {
        jobId = int.tryParse(parts[1]);
      }
    } else if (rawCode.contains('VACANCY/')) {
      final parts = rawCode.split('VACANCY/');
      if (parts.length > 1) {
        jobId = int.tryParse(parts[1]);
      }
    } else {
      jobId = int.tryParse(rawCode);
    }

    if (jobId == null || jobId <= 0) {
      setState(() => _errorMessage = 'Invalid notice code format. Example: ET-JOB-00001');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _matchedJob = null;
    });

    try {
      final job = await widget.jobRepo.getJobDetails(jobId);
      if (mounted) {
        if (job != null) {
          setState(() {
            _matchedJob = job;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Vacancy not found for notice code: $rawCode';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error looking up notice: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.qr_code_scanner, color: Color(0xFF0D6B4F)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notice Board Poster QR Lookup',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Scan or enter code from Kebele or University boards',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Notice Board Code or Job ID',
              hintText: 'e.g. ET-JOB-00001',
              prefixIcon: const Icon(Icons.tag),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Color(0xFF0D6B4F)),
                onPressed: () => _lookupCode(),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (val) => _lookupCode(val),
          ),
          const SizedBox(height: 10),
          // Quick sample chips
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Sample Codes:',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              ...['ET-JOB-00001', 'ET-JOB-00002', 'ET-JOB-00003'].map(
                (code) => InkWell(
                  onTap: () {
                    _codeController.text = code;
                    _lookupCode(code);
                  },
                  child: Chip(
                    label: Text(code, style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isLoading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_matchedJob != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF0D6B4F), size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Verified Physical Notice Vacancy',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          _matchedJob!.employmentType.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF0D6B4F)),
                        ),
                        backgroundColor: const Color(0xFFDCFCE7),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _matchedJob!.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _matchedJob!.employerName,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        _matchedJob!.location,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      Text(
                        _matchedJob!.salaryText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D6B4F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6B4F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final prof = widget.profRepo ??
                            Provider.of<ProfileRepository>(context, listen: false);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailsScreen(
                              jobId: _matchedJob!.id,
                              jobRepo: widget.jobRepo,
                              appRepo: widget.appRepo,
                              profRepo: prof,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('View Full Vacancy & 1-Tap Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
