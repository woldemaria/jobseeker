import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../features/advertising/ad_consent_modal.dart';
import '../../repositories/ads_consent_repository.dart';
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
    final requiresConsent =
        !widget.storageService.hasConsentRecorded() ||
        widget.storageService.requiresPolicyReconsent('1.0');
    setState(() {
      _isVisible = requiresConsent;
    });
  }

  Future<void> _handleQuickChoice(bool acceptAll) async {
    AdsConsentRepository? repo;
    try {
      repo = Provider.of<AdsConsentRepository>(context, listen: false);
    } catch (_) {}

    final status = acceptAll ? 'accepted' : 'rejected';
    if (repo != null) {
      await repo.saveConsent(
        status: status,
        nonPersonalized: acceptAll,
        personalized: acceptAll,
        analytics: acceptAll,
        cookies: acceptAll,
      );
    } else {
      await widget.storageService.saveAdConsent(
        status: status,
        nonPersonalized: acceptAll,
        personalized: acceptAll,
        analytics: acceptAll,
        cookies: acceptAll,
      );
    }

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
              const Icon(
                Icons.privacy_tip_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
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
            'We use cookies and profile preferences to serve contextual job vacancy advertisements, personalize matching, and compute campaign telemetry. You have full control to accept, reject, or customize your permissions anytime.',
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
                      if (widget.onConsentChanged != null) {
                        widget.onConsentChanged!();
                      }
                    },
                  );
                },
                child: const Text('Customize', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _handleQuickChoice(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Reject All', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () => _handleQuickChoice(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
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
