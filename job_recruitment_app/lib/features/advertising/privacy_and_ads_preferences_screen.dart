import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ad_consent_model.dart';
import '../../repositories/ads_consent_repository.dart';
import '../../services/storage_service.dart';

class PrivacyAndAdsPreferencesScreen extends StatefulWidget {
  final VoidCallback? onConsentUpdated;

  const PrivacyAndAdsPreferencesScreen({super.key, this.onConsentUpdated});

  @override
  State<PrivacyAndAdsPreferencesScreen> createState() =>
      _PrivacyAndAdsPreferencesScreenState();
}

class _PrivacyAndAdsPreferencesScreenState
    extends State<PrivacyAndAdsPreferencesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _status = 'custom';
  bool _nonPersonalized = false;
  bool _personalized = false;
  bool _analytics = false;
  bool _cookies = false;
  String _policyVersion = '1.0';
  DateTime? _lastTimestamp;
  List<Map<String, dynamic>> _auditLogs = [];
  bool _showAuditTrail = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConsent();
  }

  Future<void> _loadCurrentConsent() async {
    setState(() => _isLoading = true);
    final storage = Provider.of<StorageService>(context, listen: false);
    final repo = Provider.of<AdsConsentRepository>(context, listen: false);

    try {
      final consent = await repo.getConsentStatus(forceRefresh: true);
      if (mounted) {
        if (consent != null) {
          setState(() {
            _status = consent.status;
            _nonPersonalized = consent.nonPersonalizedAds;
            _personalized = consent.personalizedAds;
            _analytics = consent.analytics;
            _cookies = consent.advertisingCookies;
            _policyVersion = consent.policyVersion;
            _lastTimestamp = consent.withdrawnAt ?? consent.consentedAt;
          });
        } else {
          // Initialize from local storage or defaults (unselected)
          setState(() {
            _status = storage.getAdConsentStatus() ?? 'unselected';
            _nonPersonalized = storage.isNonPersonalizedAdsAllowed();
            _personalized = storage.isPersonalizedAdsAllowed();
            _analytics = storage.isAnalyticsAllowed();
            _cookies = storage.isCookiesAllowed();
            _policyVersion = storage.getConsentPolicyVersion();
            _lastTimestamp =
                storage.getConsentWithdrawnAt() ??
                storage.getConsentTimestamp();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = storage.getAdConsentStatus() ?? 'unselected';
          _nonPersonalized = storage.isNonPersonalizedAdsAllowed();
          _personalized = storage.isPersonalizedAdsAllowed();
          _analytics = storage.isAnalyticsAllowed();
          _cookies = storage.isCookiesAllowed();
          _policyVersion = storage.getConsentPolicyVersion();
          _lastTimestamp =
              storage.getConsentWithdrawnAt() ?? storage.getConsentTimestamp();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAuditTrail() async {
    final repo = Provider.of<AdsConsentRepository>(context, listen: false);
    try {
      final history = await repo.getAuditHistory();
      if (mounted) {
        setState(() {
          _auditLogs = history;
          _showAuditTrail = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreferences({
    required String status,
    bool? personalized,
    bool? nonPersonalized,
    bool? analytics,
    bool? cookies,
  }) async {
    setState(() => _isSaving = true);
    final repo = Provider.of<AdsConsentRepository>(context, listen: false);

    try {
      AdConsentModel updated;
      if (status == 'withdrawn') {
        updated = await repo.withdrawConsent();
      } else {
        updated = await repo.saveConsent(
          status: status,
          personalized: personalized ?? _personalized,
          nonPersonalized: nonPersonalized ?? _nonPersonalized,
          analytics: analytics ?? _analytics,
          cookies: cookies ?? _cookies,
          policyVersion: _policyVersion,
        );
      }

      if (mounted) {
        setState(() {
          _status = updated.status;
          _nonPersonalized = updated.nonPersonalizedAds;
          _personalized = updated.personalizedAds;
          _analytics = updated.analytics;
          _cookies = updated.advertisingCookies;
          _policyVersion = updated.policyVersion;
          _lastTimestamp = updated.withdrawnAt ?? updated.consentedAt;
        });

        if (widget.onConsentUpdated != null) {
          widget.onConsentUpdated!();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'withdrawn'
                  ? 'All advertising consent withdrawn. Ads and tracking disabled.'
                  : 'Privacy and advertising preferences saved successfully.',
            ),
            backgroundColor: status == 'withdrawn'
                ? Colors.deepOrange
                : AppTheme.primaryColor,
          ),
        );

        if (_showAuditTrail) {
          _loadAuditTrail();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Ads Preferences'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCurrentConsent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildStatusBanner(),
                  const SizedBox(height: 20),
                  const Text(
                    'Consent Categories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure granular permissions for advertising delivery, profile personalization, and engagement telemetry. Your choices are honored immediately and recorded transparently.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),

                  // Strictly Necessary (Locked)
                  _buildPreferenceTile(
                    title: 'Strictly Necessary Platform Data',
                    description: 'Required for core authentication, session verification, security tokens, and preventing CSRF attacks. Cannot be disabled.',
                    icon: Icons.lock_outline,
                    value: true,
                    isLocked: true,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 12),

                  // Non-Personalized Advertisements
                  _buildPreferenceTile(
                    title: 'Non-Personalized Vacancy Advertisements',
                    description: 'Enables contextual job vacancy banners and platform announcements without profiling or analyzing your user history.',
                    icon: Icons.campaign_outlined,
                    value: _nonPersonalized,
                    isLocked: false,
                    onChanged: (val) => setState(() => _nonPersonalized = val),
                  ),
                  const SizedBox(height: 12),

                  // Personalized Advertisements
                  _buildPreferenceTile(
                    title: 'Personalized Job Matching & Campaigns',
                    description: 'Uses your registered skills, search keywords, and experience to prioritize relevant job vacancy advertisements tailored to your career goals.',
                    icon: Icons.psychology_outlined,
                    value: _personalized,
                    isLocked: false,
                    onChanged: (val) => setState(() => _personalized = val),
                  ),
                  const SizedBox(height: 12),

                  // Analytics & Telemetry
                  _buildPreferenceTile(
                    title: 'Campaign Analytics & Telemetry',
                    description: 'Allows recording impression frequency and click events to evaluate ad effectiveness. No tracking across third-party apps or websites.',
                    icon: Icons.insights_outlined,
                    value: _analytics,
                    isLocked: false,
                    onChanged: (val) => setState(() => _analytics = val),
                  ),
                  const SizedBox(height: 12),

                  // Advertising Cookies & Identifiers
                  _buildPreferenceTile(
                    title: 'Advertising Identifiers & Session Cookies',
                    description: 'Permits storing a pseudonymous device identifier to prevent duplicate impressions. If rejected, tracking data is completely anonymized.',
                    icon: Icons.cookie_outlined,
                    value: _cookies,
                    isLocked: false,
                    onChanged: (val) => setState(() => _cookies = val),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text('Accept All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _savePreferences(
                              status: 'accepted',
                              personalized: true,
                              nonPersonalized: true,
                              analytics: true,
                              cookies: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Reject All'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _savePreferences(
                              status: 'rejected',
                              personalized: false,
                              nonPersonalized: false,
                              analytics: false,
                              cookies: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Custom Preferences'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _savePreferences(
                        status: 'custom',
                        personalized: _personalized,
                        nonPersonalized: _nonPersonalized,
                        analytics: _analytics,
                        cookies: _cookies,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.block_outlined, size: 18),
                      label: const Text('Withdraw All Consent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange.shade800,
                        side: BorderSide(color: Colors.deepOrange.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _savePreferences(status: 'withdrawn'),
                    ),
                  ],

                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Audit Trail Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Consent Audit Trail',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        icon: Icon(
                          _showAuditTrail
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          _showAuditTrail ? 'Hide Logs' : 'View Logs',
                        ),
                        onPressed: () {
                          if (!_showAuditTrail && _auditLogs.isEmpty) {
                            _loadAuditTrail();
                          } else {
                            setState(() => _showAuditTrail = !_showAuditTrail);
                          }
                        },
                      ),
                    ],
                  ),
                  if (_showAuditTrail) _buildAuditLogList(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advertising Transparency & Choice',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Governed by Policy v$_policyVersion. Consent is free, revocable at any time, and fully audited.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (_status) {
      case 'accepted':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'All Advertising Permissions Active';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Advertising & Tracking Declined';
        icon = Icons.cancel;
        break;
      case 'withdrawn':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        label = 'Consent Withdrawn (Ads & Tracking Fully Disabled)';
        icon = Icons.block;
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Custom Privacy Configuration Active';
        icon = Icons.tune;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (_lastTimestamp != null)
                  Text(
                    'Recorded: ${_lastTimestamp!.toLocal().toString().split('.').first}',
                    style: TextStyle(color: fg.withOpacity(0.8), fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String description,
    required IconData icon,
    required bool value,
    required bool isLocked,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
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
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isLocked)
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
                          'Essential',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeColor: AppTheme.primaryColor,
            onChanged: isLocked ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogList() {
    if (_auditLogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No historical audit entries recorded yet.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _auditLogs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final action = log['action'] ?? 'change';
        final status = log['status'] ?? '';
        final version = log['policy_version'] ?? '1.0';
        final createdAt = log['created_at'] != null
            ? DateTime.tryParse(log['created_at'].toString())
            : null;

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            action == 'withdraw'
                ? Icons.block
                : action == 'grant'
                ? Icons.verified
                : Icons.history,
            color: action == 'withdraw'
                ? Colors.deepOrange
                : AppTheme.primaryColor,
            size: 20,
          ),
          title: Text(
            'Action: ${action.toString().toUpperCase()} (Status: $status)',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Policy v$version • ${createdAt?.toLocal().toString().split('.').first ?? ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        );
      },
    );
  }
}
