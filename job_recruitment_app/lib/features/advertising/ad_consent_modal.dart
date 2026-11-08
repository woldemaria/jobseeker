import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../repositories/ads_consent_repository.dart';
import '../../services/storage_service.dart';
import 'privacy_and_ads_preferences_screen.dart';

class AdConsentModal extends StatefulWidget {
  final StorageService storageService;
  final AdsConsentRepository? consentRepository;
  final VoidCallback? onConsentUpdated;

  const AdConsentModal({
    super.key,
    required this.storageService,
    this.consentRepository,
    this.onConsentUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required StorageService storageService,
    AdsConsentRepository? consentRepository,
    VoidCallback? onConsentUpdated,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AdConsentModal(
        storageService: storageService,
        consentRepository: consentRepository,
        onConsentUpdated: onConsentUpdated,
      ),
    );
  }

  @override
  State<AdConsentModal> createState() => _AdConsentModalState();
}

class _AdConsentModalState extends State<AdConsentModal> {
  late bool _nonPersonalized;
  late bool _personalized;
  late bool _analytics;
  late bool _cookies;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Do not use pre-selected consent if not chosen yet (honest, transparent design)
    _nonPersonalized = widget.storageService.isNonPersonalizedAdsAllowed();
    _personalized = widget.storageService.isPersonalizedAdsAllowed();
    _analytics = widget.storageService.isAnalyticsAllowed();
    _cookies = widget.storageService.isCookiesAllowed();
  }

  Future<void> _save({
    required String status,
    required bool nonPersonalized,
    required bool personalized,
    required bool analytics,
    required bool cookies,
  }) async {
    setState(() => _isSaving = true);

    AdsConsentRepository? repo = widget.consentRepository;
    if (repo == null) {
      try {
        repo = Provider.of<AdsConsentRepository>(context, listen: false);
      } catch (_) {}
    }

    if (repo != null) {
      await repo.saveConsent(
        status: status,
        nonPersonalized: nonPersonalized,
        personalized: personalized,
        analytics: analytics,
        cookies: cookies,
      );
    } else {
      await widget.storageService.saveAdConsent(
        status: status,
        nonPersonalized: nonPersonalized,
        personalized: personalized,
        analytics: analytics,
        cookies: cookies,
      );
    }

    if (widget.onConsentUpdated != null) {
      widget.onConsentUpdated!();
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy and advertising choices saved.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 660),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppTheme.primaryColor,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cookie & Advertising Consent',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                      'We respect your privacy. You can choose which data processing categories you permit for vacancy advertisements, matching, and campaign telemetry.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Essential (Locked)
                    _preferenceTile(
                      title: 'Strictly Necessary Platform Data',
                      subtitle: 'Required for core authentication, session management, and secure tokens. Cannot be disabled.',
                      value: true,
                      isLocked: true,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 10),

                    // Non-personalized ads
                    _preferenceTile(
                      title: 'Non-Personalized Job Advertisements',
                      subtitle: 'Allows displaying contextual job vacancies and announcements without behavioral profiling.',
                      value: _nonPersonalized,
                      isLocked: false,
                      onChanged: (val) =>
                          setState(() => _nonPersonalized = val),
                    ),
                    const SizedBox(height: 10),

                    // Personalized Advertisements
                    _preferenceTile(
                      title: 'Personalized Job Matching & Recommendations',
                      subtitle: 'Enables tailored vacancy banners based on your verified skills, experience, and search categories.',
                      value: _personalized,
                      isLocked: false,
                      onChanged: (val) => setState(() => _personalized = val),
                    ),
                    const SizedBox(height: 10),

                    // Campaign Analytics
                    _preferenceTile(
                      title: 'Campaign Analytics & Telemetry',
                      subtitle: 'Allows recording impression frequency and click metrics to evaluate campaign performance.',
                      value: _analytics,
                      isLocked: false,
                      onChanged: (val) => setState(() => _analytics = val),
                    ),
                    const SizedBox(height: 10),

                    // Cookies & Identifiers
                    _preferenceTile(
                      title: 'Advertising Identifiers & Session Cookies',
                      subtitle: 'Allows pseudonymous device identifiers to avoid duplicate ads across app sessions.',
                      value: _cookies,
                      isLocked: false,
                      onChanged: (val) => setState(() => _cookies = val),
                    ),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.settings_suggest_outlined,
                          size: 16,
                        ),
                        label: const Text('Open Full Privacy & Ads Page'),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrivacyAndAdsPreferencesScreen(
                                onConsentUpdated: widget.onConsentUpdated,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _save(
                          status: 'rejected',
                          nonPersonalized: false,
                          personalized: false,
                          analytics: false,
                          cookies: false,
                        ),
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
                        onPressed: () => _save(
                          status: 'custom',
                          nonPersonalized: _nonPersonalized,
                          personalized: _personalized,
                          analytics: _analytics,
                          cookies: _cookies,
                        ),
                        child: const Text('Save Choices'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _save(
                          status: 'accepted',
                          nonPersonalized: true,
                          personalized: true,
                          analytics: true,
                          cookies: true,
                        ),
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
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
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
