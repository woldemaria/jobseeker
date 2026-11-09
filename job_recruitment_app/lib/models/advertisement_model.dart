import 'advertising_package_model.dart';

class AdvertisementModel {
  final int id;
  final String title;
  final String? titleAm;
  final String? subtitle;
  final String? subtitleAm;
  final String? description;
  final String? badgeText;
  final String? badgeTextAm;
  final String imageUrl;
  final String category;
  final String placement;
  final List<String> placements;
  final String targetRole;
  final List<String> targetSkills;
  final String? targetCategory;
  final List<String> targetLocations;
  final Map<String, dynamic>? targetAudience;
  final String ctaType;
  final String ctaText;
  final String? ctaTextAm;
  final String ctaTarget;
  final String? backgroundColor;
  final int priority;
  final int impressionsCount;
  final int clicksCount;
  final double ctr;
  final String startDate;
  final String endDate;
  final String status;
  final String approvalStatus;
  final int? packageId;
  final AdvertisingPackageModel? package;
  final int? employerId;
  final String? employerName;
  final String? approvedByName;
  final String? approvedAt;
  final String? rejectionReason;
  final String paymentStatus;
  final double pricePaid;
  final int? relevanceScore;
  final String? createdAt;
  final String? updatedAt;

  AdvertisementModel({
    required this.id,
    required this.title,
    this.titleAm,
    this.subtitle,
    this.subtitleAm,
    this.description,
    this.badgeText,
    this.badgeTextAm,
    required this.imageUrl,
    required this.category,
    required this.placement,
    this.placements = const [],
    this.targetRole = 'all',
    this.targetSkills = const [],
    this.targetCategory,
    this.targetLocations = const [],
    this.targetAudience,
    required this.ctaType,
    required this.ctaText,
    this.ctaTextAm,
    required this.ctaTarget,
    this.backgroundColor,
    this.priority = 0,
    this.impressionsCount = 0,
    this.clicksCount = 0,
    this.ctr = 0.0,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.approvalStatus = 'draft',
    this.packageId,
    this.package,
    this.employerId,
    this.employerName,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    this.paymentStatus = 'unpaid',
    this.pricePaid = 0.0,
    this.relevanceScore,
    this.createdAt,
    this.updatedAt,
  });

  factory AdvertisementModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    double parseDouble(dynamic raw) {
      if (raw == null) return 0.0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? 0.0;
    }

    int parseInt(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? 0;
    }

    String? parseApprovedBy(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map && raw['name'] != null) {
        return raw['name'].toString();
      }
      if (raw is String) return raw;
      return null;
    }

    String? parseEmployerName(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map && raw['organization_name'] != null) {
        return raw['organization_name'].toString();
      }
      return null;
    }

    AdvertisingPackageModel? pkg;
    if (json['package'] != null && json['package'] is Map<String, dynamic>) {
      pkg = AdvertisingPackageModel.fromJson(json['package'] as Map<String, dynamic>);
    }

    return AdvertisementModel(
      id: parseInt(json['id']),
      title: json['title'] as String? ?? '',
      titleAm: json['title_am'] as String?,
      subtitle: json['subtitle'] as String?,
      subtitleAm: json['subtitle_am'] as String?,
      description: json['description'] as String?,
      badgeText: json['badge_text'] as String?,
      badgeTextAm: json['badge_text_am'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      category: json['category'] as String? ?? 'featured_jobs',
      placement: json['placement'] as String? ?? 'hero',
      placements: parseList(json['placements']),
      targetRole: json['target_role'] as String? ?? 'all',
      targetSkills: parseList(json['target_skills']),
      targetCategory: json['target_category'] as String?,
      targetLocations: parseList(json['target_locations']),
      targetAudience: json['target_audience'] is Map<String, dynamic>
          ? json['target_audience'] as Map<String, dynamic>
          : null,
      ctaType: json['cta_type'] as String? ?? 'explore_jobs',
      ctaText: json['cta_text'] as String? ?? 'Learn More',
      ctaTextAm: json['cta_text_am'] as String?,
      ctaTarget: json['cta_target'] as String? ?? '',
      backgroundColor: json['background_color'] as String?,
      priority: parseInt(json['priority']),
      impressionsCount: parseInt(json['impressions_count']),
      clicksCount: parseInt(json['clicks_count']),
      ctr: parseDouble(json['ctr']),
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      approvalStatus: json['approval_status'] as String? ??
          (json['status'] == 'active' ? 'approved' : 'draft'),
      packageId: json['package_id'] != null ? parseInt(json['package_id']) : null,
      package: pkg,
      employerId: json['employer_id'] != null ? parseInt(json['employer_id']) : null,
      employerName: parseEmployerName(json['employer']),
      approvedByName: parseApprovedBy(json['approved_by']),
      approvedAt: json['approved_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      pricePaid: parseDouble(json['price_paid']),
      relevanceScore: json['relevance_score'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_am': titleAm,
      'subtitle': subtitle,
      'subtitle_am': subtitleAm,
      'description': description,
      'badge_text': badgeText,
      'badge_text_am': badgeTextAm,
      'image_url': imageUrl,
      'category': category,
      'placement': placement,
      'placements': placements,
      'target_role': targetRole,
      'target_skills': targetSkills,
      'target_category': targetCategory,
      'target_locations': targetLocations,
      'target_audience': targetAudience,
      'cta_type': ctaType,
      'cta_text': ctaText,
      'cta_text_am': ctaTextAm,
      'cta_target': ctaTarget,
      'background_color': backgroundColor,
      'priority': priority,
      'impressions_count': impressionsCount,
      'clicks_count': clicksCount,
      'ctr': ctr,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'approval_status': approvalStatus,
      'package_id': packageId,
      'payment_status': paymentStatus,
      'price_paid': pricePaid,
    };
  }

  String getTitle(String languageCode) {
    if (languageCode == 'am' && titleAm != null && titleAm!.trim().isNotEmpty) {
      return titleAm!;
    }
    return title;
  }

  String? getSubtitle(String languageCode) {
    if (languageCode == 'am' &&
        subtitleAm != null &&
        subtitleAm!.trim().isNotEmpty) {
      return subtitleAm;
    }
    return subtitle;
  }

  String? getBadge(String languageCode) {
    if (languageCode == 'am' &&
        badgeTextAm != null &&
        badgeTextAm!.trim().isNotEmpty) {
      return badgeTextAm;
    }
    return badgeText;
  }

  String getCta(String languageCode) {
    if (languageCode == 'am' &&
        ctaTextAm != null &&
        ctaTextAm!.trim().isNotEmpty) {
      return ctaTextAm!;
    }
    return ctaText;
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isExpired => status == 'expired';
  bool get isDraft => approvalStatus == 'draft' || status == 'draft';
  bool get isPendingApproval =>
      approvalStatus == 'pending_approval' || status == 'pending_approval';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected' || status == 'rejected';
  bool get isPaid =>
      ['paid', 'free_trial'].contains(paymentStatus) || pricePaid <= 0;
  bool get canBeEdited => isDraft || isRejected;

  AdvertisementModel copyWith({
    int? id,
    String? title,
    String? titleAm,
    String? subtitle,
    String? subtitleAm,
    String? description,
    String? badgeText,
    String? badgeTextAm,
    String? imageUrl,
    String? category,
    String? placement,
    List<String>? placements,
    String? targetRole,
    List<String>? targetSkills,
    String? targetCategory,
    List<String>? targetLocations,
    Map<String, dynamic>? targetAudience,
    String? ctaType,
    String? ctaText,
    String? ctaTextAm,
    String? ctaTarget,
    String? backgroundColor,
    int? priority,
    int? impressionsCount,
    int? clicksCount,
    double? ctr,
    String? startDate,
    String? endDate,
    String? status,
    String? approvalStatus,
    int? packageId,
    AdvertisingPackageModel? package,
    int? employerId,
    String? employerName,
    String? approvedByName,
    String? approvedAt,
    String? rejectionReason,
    String? paymentStatus,
    double? pricePaid,
  }) {
    return AdvertisementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAm: titleAm ?? this.titleAm,
      subtitle: subtitle ?? this.subtitle,
      subtitleAm: subtitleAm ?? this.subtitleAm,
      description: description ?? this.description,
      badgeText: badgeText ?? this.badgeText,
      badgeTextAm: badgeTextAm ?? this.badgeTextAm,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      placement: placement ?? this.placement,
      placements: placements ?? this.placements,
      targetRole: targetRole ?? this.targetRole,
      targetSkills: targetSkills ?? this.targetSkills,
      targetCategory: targetCategory ?? this.targetCategory,
      targetLocations: targetLocations ?? this.targetLocations,
      targetAudience: targetAudience ?? this.targetAudience,
      ctaType: ctaType ?? this.ctaType,
      ctaText: ctaText ?? this.ctaText,
      ctaTextAm: ctaTextAm ?? this.ctaTextAm,
      ctaTarget: ctaTarget ?? this.ctaTarget,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      priority: priority ?? this.priority,
      impressionsCount: impressionsCount ?? this.impressionsCount,
      clicksCount: clicksCount ?? this.clicksCount,
      ctr: ctr ?? this.ctr,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      packageId: packageId ?? this.packageId,
      package: package ?? this.package,
      employerId: employerId ?? this.employerId,
      employerName: employerName ?? this.employerName,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      pricePaid: pricePaid ?? this.pricePaid,
    );
  }
}
