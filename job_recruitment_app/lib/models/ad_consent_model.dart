class AdConsentModel {
  final int? id;
  final int? userId;
  final String consentUuid;
  final String status;
  final bool personalizedAds;
  final bool nonPersonalizedAds;
  final bool analytics;
  final bool advertisingCookies;
  final String policyVersion;
  final DateTime? consentedAt;
  final DateTime? withdrawnAt;

  AdConsentModel({
    this.id,
    this.userId,
    required this.consentUuid,
    required this.status,
    required this.personalizedAds,
    required this.nonPersonalizedAds,
    required this.analytics,
    required this.advertisingCookies,
    this.policyVersion = '1.0',
    this.consentedAt,
    this.withdrawnAt,
  });

  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isWithdrawn => status == 'withdrawn';
  bool get isCustom => status == 'custom';

  bool get allowsPersonalizedAds => !isWithdrawn && personalizedAds;
  bool get allowsNonPersonalizedAds => !isWithdrawn && nonPersonalizedAds;
  bool get allowsAnalytics => !isWithdrawn && analytics;
  bool get allowsCookies => !isWithdrawn && advertisingCookies;

  factory AdConsentModel.fromJson(Map<String, dynamic> json) {
    return AdConsentModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? ''),
      consentUuid: json['consent_uuid']?.toString() ?? '',
      status: json['status']?.toString() ?? 'custom',
      personalizedAds:
          json['personalized_ads'] == true ||
          json['personalized_ads'] == 1 ||
          json['personalized_ads'] == '1',
      nonPersonalizedAds:
          json['non_personalized_ads'] == true ||
          json['non_personalized_ads'] == 1 ||
          json['non_personalized_ads'] == '1',
      analytics:
          json['analytics'] == true ||
          json['analytics'] == 1 ||
          json['analytics'] == '1',
      advertisingCookies:
          json['advertising_cookies'] == true ||
          json['advertising_cookies'] == 1 ||
          json['advertising_cookies'] == '1',
      policyVersion: json['policy_version']?.toString() ?? '1.0',
      consentedAt: json['consented_at'] != null
          ? DateTime.tryParse(json['consented_at'].toString())
          : null,
      withdrawnAt: json['withdrawn_at'] != null
          ? DateTime.tryParse(json['withdrawn_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'consent_uuid': consentUuid,
      'status': status,
      'personalized_ads': personalizedAds,
      'non_personalized_ads': nonPersonalizedAds,
      'analytics': analytics,
      'advertising_cookies': advertisingCookies,
      'policy_version': policyVersion,
      if (consentedAt != null) 'consented_at': consentedAt!.toIso8601String(),
      if (withdrawnAt != null) 'withdrawn_at': withdrawnAt!.toIso8601String(),
    };
  }

  AdConsentModel copyWith({
    int? id,
    int? userId,
    String? consentUuid,
    String? status,
    bool? personalizedAds,
    bool? nonPersonalizedAds,
    bool? analytics,
    bool? advertisingCookies,
    String? policyVersion,
    DateTime? consentedAt,
    DateTime? withdrawnAt,
  }) {
    return AdConsentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      consentUuid: consentUuid ?? this.consentUuid,
      status: status ?? this.status,
      personalizedAds: personalizedAds ?? this.personalizedAds,
      nonPersonalizedAds: nonPersonalizedAds ?? this.nonPersonalizedAds,
      analytics: analytics ?? this.analytics,
      advertisingCookies: advertisingCookies ?? this.advertisingCookies,
      policyVersion: policyVersion ?? this.policyVersion,
      consentedAt: consentedAt ?? this.consentedAt,
      withdrawnAt: withdrawnAt ?? this.withdrawnAt,
    );
  }
}
