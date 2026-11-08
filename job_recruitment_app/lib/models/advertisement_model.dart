class AdvertisementModel {
  final int id;
  final String title;
  final String? titleAm;
  final String? subtitle;
  final String? subtitleAm;
  final String? badgeText;
  final String? badgeTextAm;
  final String imageUrl;
  final String category;
  final String placement;
  final String targetRole;
  final List<String> targetSkills;
  final String? targetCategory;
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
  final int? relevanceScore;
  final String? createdAt;
  final String? updatedAt;

  AdvertisementModel({
    required this.id,
    required this.title,
    this.titleAm,
    this.subtitle,
    this.subtitleAm,
    this.badgeText,
    this.badgeTextAm,
    required this.imageUrl,
    required this.category,
    required this.placement,
    this.targetRole = 'all',
    this.targetSkills = const [],
    this.targetCategory,
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
    this.relevanceScore,
    this.createdAt,
    this.updatedAt,
  });

  factory AdvertisementModel.fromJson(Map<String, dynamic> json) {
    List<String> parseSkills(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    double parseCtr(dynamic raw) {
      if (raw == null) return 0.0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? 0.0;
    }

    int parseInt(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? 0;
    }

    return AdvertisementModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      titleAm: json['title_am'] as String?,
      subtitle: json['subtitle'] as String?,
      subtitleAm: json['subtitle_am'] as String?,
      badgeText: json['badge_text'] as String?,
      badgeTextAm: json['badge_text_am'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      category: json['category'] as String? ?? 'featured_jobs',
      placement: json['placement'] as String? ?? 'hero',
      targetRole: json['target_role'] as String? ?? 'all',
      targetSkills: parseSkills(json['target_skills']),
      targetCategory: json['target_category'] as String?,
      ctaType: json['cta_type'] as String? ?? 'explore_jobs',
      ctaText: json['cta_text'] as String? ?? 'Learn More',
      ctaTextAm: json['cta_text_am'] as String?,
      ctaTarget: json['cta_target'] as String? ?? '',
      backgroundColor: json['background_color'] as String?,
      priority: parseInt(json['priority']),
      impressionsCount: parseInt(json['impressions_count']),
      clicksCount: parseInt(json['clicks_count']),
      ctr: parseCtr(json['ctr']),
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
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
      'badge_text': badgeText,
      'badge_text_am': badgeTextAm,
      'image_url': imageUrl,
      'category': category,
      'placement': placement,
      'target_role': targetRole,
      'target_skills': targetSkills,
      'target_category': targetCategory,
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
}
