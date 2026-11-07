import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

class AdConsentModal extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback? onConsentUpdated;

  const AdConsentModal({
    super.key,
    required this.storageService,
    this.onConsentUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required StorageService storageService,
    VoidCallback? onConsentUpdated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AdConsentModal(
        storageService: storageService,
        onConsentUpdated: onConsentUpdated,
      ),
    );
  }

  @override
  State<AdConsentModal> createState() => _AdConsentModalState();
}

class _AdConsentModalState extends State<AdConsentModal> {
  late bool _personalized;
  late bool _analytics;

  @override
  void initState() {
    super.initState();
    _personalized = widget.storageService.isPersonalizedAdsAllowed();
    _analytics = widget.storageService.isAnalyticsAllowed();
  }

  Future<void> _save(String status, bool personalized, bool analytics) async {
    await widget.storageService.saveAdConsent(
      status: status,
      personalized: personalized,
      analytics: analytics,
    );
    if (widget.onConsentUpdated != null) {
      widget.onConsentUpdated!();
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy and advertising preferences saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryColor, size: 26),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cookie & Advertising Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'We respect your privacy. You can choose which cookies and data processing categories you permit for recruitment advertising and analytics.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Essential (Locked)
                    _preferenceTile(
                      title: 'Strictly Necessary Data',
                      subtitle: 'Required for core platform features like authentication, secure navigation, and session persistence.',
                      value: true,
                      isLocked: true,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 12),

                    // Personalized Advertisements
                    _preferenceTile(
                      title: 'Personalized Advertisements & Recommendations',
                      subtitle: 'Enables tailored banners and promotional campaigns based on your verified skills, experience, and job search categories.',
                      value: _personalized,
                      isLocked: false,
                      onChanged: (val) => setState(() => _personalized = val),
                    ),
                    const SizedBox(height: 12),

                    // Campaign Analytics
                    _preferenceTile(
                      title: 'Campaign Analytics & Telemetry',
                      subtitle: 'Allows recording impression and click metrics to verify advertising performance without tracking across external websites.',
                      value: _analytics,
                      isLocked: false,
                      onChanged: (val) => setState(() => _analytics = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _save('rejected', false, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      child: const Text('Reject All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _save('custom', _personalized, _analytics),
                      child: const Text('Save Choices'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _save('accepted', true, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept All'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preferenceTile({
    required String title,
    required String subtitle,
    required bool value,
    required bool isLocked,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.primaryColor,
            onChanged: isLocked ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
