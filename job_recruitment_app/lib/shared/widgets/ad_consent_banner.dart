import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../features/advertising/ad_consent_modal.dart';
import '../../services/storage_service.dart';

class AdConsentBanner extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback? onConsentChanged;

  const AdConsentBanner({
    super.key,
    required this.storageService,
    this.onConsentChanged,
  });

  @override
  State<AdConsentBanner> createState() => _AdConsentBannerState();
}

class _AdConsentBannerState extends State<AdConsentBanner> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  void _checkVisibility() {
    final status = widget.storageService.getAdConsentStatus();
    setState(() {
      _isVisible = status == null;
    });
  }

  Future<void> _handleQuickChoice(bool acceptAll) async {
    await widget.storageService.saveAdConsent(
      status: acceptAll ? 'accepted' : 'rejected',
      personalized: acceptAll,
      analytics: acceptAll,
    );
    setState(() => _isVisible = false);
    if (widget.onConsentChanged != null) {
      widget.onConsentChanged!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.cookie_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Advertising & Cookie Privacy Consent',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _isVisible = false),
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We use cookies and profile preferences to serve personalized job advertisements and calculate engagement metrics. You can accept, reject, or manage your preferences anytime.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  AdConsentModal.show(
                    context,
                    storageService: widget.storageService,
                    onConsentUpdated: () {
                      _checkVisibility();
                      if (widget.onConsentChanged != null) widget.onConsentChanged!();
                    },
                  );
                },
                child: const Text('Manage', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _handleQuickChoice(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Reject', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () => _handleQuickChoice(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Accept All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
