import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'shortlisted':
      case 'accepted':
      case 'approved':
      case 'published':
        return const Color(0xFF0D6B4F); // Green
      case 'interview':
        return const Color(0xFF2563EB); // Blue
      case 'under_review':
      case 'pending':
        return const Color(0xFFD97706); // Amber
      case 'rejected':
      case 'closed':
      case 'archived':
        return const Color(0xFFDC2626); // Red
      case 'withdrawn':
        return const Color(0xFF64748B); // Slate
      case 'submitted':
      default:
        return const Color(0xFF0284C7); // Sky blue
    }
  }

  String _getLocalizedLabel(BuildContext context) {
    final loc = AppLocalizations.of(context);
    switch (status.toLowerCase()) {
      case 'submitted':
        return loc.t('status_submitted');
      case 'under_review':
        return loc.t('status_under_review');
      case 'shortlisted':
        return loc.t('status_shortlisted');
      case 'interview':
        return loc.t('status_interview');
      case 'accepted':
        return loc.t('status_accepted');
      case 'rejected':
        return loc.t('status_rejected');
      case 'withdrawn':
        return loc.t('status_withdrawn');
      case 'approved':
        return loc.t('verified');
      case 'pending':
        return loc.t('pending');
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final label = _getLocalizedLabel(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
