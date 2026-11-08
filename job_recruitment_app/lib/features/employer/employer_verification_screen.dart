import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/status_badge.dart';

class EmployerVerificationScreen extends StatefulWidget {
  final ApiService apiService;

  const EmployerVerificationScreen({super.key, required this.apiService});

  @override
  State<EmployerVerificationScreen> createState() =>
      _EmployerVerificationScreenState();
}

class _EmployerVerificationScreenState
    extends State<EmployerVerificationScreen> {
  String _status = 'pending';
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await widget.apiService.get(
        ApiConstants.employerVerification,
      );
      if (mounted && resp.success && resp.data != null) {
        setState(() {
          _status = resp.data['verification_status'] ?? 'pending';
          _history = resp.data['history'] ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    final resp = await widget.apiService.post(
      ApiConstants.employerVerification,
      {'review_notes': _notesController.text.trim()},
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (resp.success) {
        _notesController.clear();
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification request submitted for admin review.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resp.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('verification_status'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Organization Status:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            StatusBadge(status: _status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Verified employers earn trusted badges and heightened applicant confidence.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  loc.t('request_verification'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Registration / Tax Identification Notes',
                            hintText: 'Enter business license or TIN details for administration review...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(loc.t('request_verification')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Verification Submissions History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_history.isEmpty)
                  const Text(
                    'No prior verification submissions.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  )
                else
                  ..._history.map((h) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          'Status: ${(h['status'] ?? "").toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Date: ${(h['submitted_at'] ?? "").toString().split('T').first}\nNotes: ${h['review_notes'] ?? "None"}',
                        ),
                        trailing: StatusBadge(status: h['status'] ?? 'pending'),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
