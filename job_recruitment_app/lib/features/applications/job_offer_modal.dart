import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_offer_model.dart';
import '../../repositories/career_repository.dart';

class JobOfferModal {
  static void show(
    BuildContext context, {
    required int applicationId,
    CareerRepository? careerRepo,
    VoidCallback? onUpdated,
    VoidCallback? onOfferUpdated,
  }) {
    final repo =
        careerRepo ?? Provider.of<CareerRepository>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _JobOfferSheet(
        applicationId: applicationId,
        careerRepo: repo,
        onUpdated: onOfferUpdated ?? onUpdated,
      ),
    );
  }
}

class _JobOfferSheet extends StatefulWidget {
  final int applicationId;
  final CareerRepository careerRepo;
  final VoidCallback? onUpdated;

  const _JobOfferSheet({
    required this.applicationId,
    required this.careerRepo,
    this.onUpdated,
  });

  @override
  State<_JobOfferSheet> createState() => _JobOfferSheetState();
}

class _JobOfferSheetState extends State<_JobOfferSheet> {
  JobOfferModel? _offer;
  bool _isLoading = true;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.careerRepo.getOfferDetails(
        widget.applicationId,
      );
      if (mounted) {
        setState(() {
          _offer = data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _respond(String action) async {
    final noteCtrl = TextEditingController();
    String title = 'Accept Job Offer';
    Color confirmColor = const Color(0xFF0D6B4F);

    if (action == 'declined') {
      title = 'Decline Job Offer';
      confirmColor = Colors.red;
    } else if (action == 'clarification_requested') {
      title = 'Request Clarification / Changes';
      confirmColor = Colors.amber.shade900;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to proceed with: ${action.replaceAll('_', ' ').toUpperCase()}?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes to Employer (Optional)',
                hintText: 'e.g. Inquiries regarding health insurance or start date...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Confirm Response'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isResponding = true);
      final success = await widget.careerRepo.respondToOffer(
        widget.applicationId,
        action,
        notes: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
      );

      if (mounted) {
        setState(() => _isResponding = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: confirmColor,
              content: Text(
                'Offer response "${action.replaceAll('_', ' ')}" sent to employer.',
              ),
            ),
          );
          widget.onUpdated?.call();
          _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Failed to submit offer response.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_offer == null) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text('No formal offer details found for this application.'),
        ),
      );
    }

    final status = _offer!.offerStatus;
    final isPending = _offer!.isPending;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.verified, color: Color(0xFF0D6B4F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Official Job Offer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_offer!.jobTitle} • ${_offer!.companyName}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.amber.shade100
                        : (_offer!.isAccepted
                              ? Colors.green.shade100
                              : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPending
                          ? Colors.amber.shade900
                          : (_offer!.isAccepted
                                ? Colors.green.shade900
                                : Colors.grey.shade800),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Salary & Compensation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF0D6B4F),
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offered Monthly Salary',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534),
                        ),
                      ),
                      Text(
                        _offer!.offerSalary != null
                            ? '${_offer!.offerSalary!.toStringAsFixed(0)} ETB'
                            : 'To be finalized',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Benefits
            if (_offer!.offerBenefits != null &&
                _offer!.offerBenefits!.isNotEmpty) ...[
              _buildSectionTitle(Icons.card_giftcard, 'Benefits & Allowances'),
              const SizedBox(height: 6),
              Text(
                _offer!.offerBenefits!,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],

            // Conditions
            if (_offer!.offerConditions != null &&
                _offer!.offerConditions!.isNotEmpty) ...[
              _buildSectionTitle(Icons.gavel, 'Employment Terms & Conditions'),
              const SizedBox(height: 6),
              Text(
                _offer!.offerConditions!,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],

            // Start Date
            if (_offer!.offerStartDate != null) ...[
              _buildSectionTitle(Icons.event, 'Proposed Starting Date'),
              const SizedBox(height: 6),
              Text(
                _offer!.offerStartDate!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Employer Notes
            if (_offer!.offerNotes != null &&
                _offer!.offerNotes!.isNotEmpty) ...[
              _buildSectionTitle(Icons.notes, 'Employer Message'),
              const SizedBox(height: 6),
              Text(
                _offer!.offerNotes!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Candidate Response Notes (if already responded)
            if (_offer!.candidateResponseNotes != null &&
                _offer!.candidateResponseNotes!.isNotEmpty) ...[
              _buildSectionTitle(Icons.reply, 'Your Response'),
              const SizedBox(height: 6),
              Text(
                _offer!.candidateResponseNotes!,
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (isPending) ...[
              const Divider(height: 24),
              if (_isResponding)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'Accept Offer 🎉',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () => _respond('accepted'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade900,
                          side: BorderSide(color: Colors.amber.shade700),
                        ),
                        onPressed: () => _respond('clarification_requested'),
                        child: const Text('Request Clarification'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _respond('declined'),
                        child: const Text('Decline Offer'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D6B4F)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ],
    );
  }
}
