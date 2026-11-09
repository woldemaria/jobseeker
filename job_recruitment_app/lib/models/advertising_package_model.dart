class AdvertisingPackageModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int durationDays;
  final double priceEtb;
  final String? priceFormatted;
  final List<String> allowedPlacements;
  final List<String> allowedCategories;
  final List<String> benefits;
  final String? badgeLabel;
  final bool isActive;
  final int priorityLevel;
  final int advertisementsCount;

  AdvertisingPackageModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.durationDays,
    required this.priceEtb,
    this.priceFormatted,
    required this.allowedPlacements,
    required this.allowedCategories,
    required this.benefits,
    this.badgeLabel,
    required this.isActive,
    this.priorityLevel = 0,
    this.advertisementsCount = 0,
  });

  String get displayPrice =>
      priceFormatted ?? '${priceEtb.toStringAsFixed(2)} ETB';

  String get durationText {
    if (durationDays == 7) return '1 Week (7 Days)';
    if (durationDays == 14 || durationDays == 15) return '15 Days';
    if (durationDays == 30) return '1 Month (30 Days)';
    if (durationDays == 60) return '2 Months (60 Days)';
    return '$durationDays Days';
  }

  factory AdvertisingPackageModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return AdvertisingPackageModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      durationDays: json['duration_days'] is int
          ? json['duration_days']
          : int.tryParse(json['duration_days'].toString()) ?? 7,
      priceEtb: json['price_etb'] != null
          ? (double.tryParse(json['price_etb'].toString()) ?? 0.0)
          : 0.0,
      priceFormatted: json['price_formatted']?.toString(),
      allowedPlacements: parseStringList(json['allowed_placements']),
      allowedCategories: parseStringList(json['allowed_categories']),
      benefits: parseStringList(json['benefits']),
      badgeLabel: json['badge_label']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1',
      priorityLevel: json['priority_level'] is int
          ? json['priority_level']
          : int.tryParse(json['priority_level'].toString()) ?? 0,
      advertisementsCount: json['advertisements_count'] is int
          ? json['advertisements_count']
          : int.tryParse(json['advertisements_count'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'duration_days': durationDays,
      'price_etb': priceEtb,
      'allowed_placements': allowedPlacements,
      'allowed_categories': allowedCategories,
      'benefits': benefits,
      'badge_label': badgeLabel,
      'is_active': isActive,
      'priority_level': priorityLevel,
    };
  }

  AdvertisingPackageModel copyWith({
    int? id,
    String? name,
    String? slug,
    String? description,
    int? durationDays,
    double? priceEtb,
    String? priceFormatted,
    List<String>? allowedPlacements,
    List<String>? allowedCategories,
    List<String>? benefits,
    String? badgeLabel,
    bool? isActive,
    int? priorityLevel,
    int? advertisementsCount,
  }) {
    return AdvertisingPackageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      durationDays: durationDays ?? this.durationDays,
      priceEtb: priceEtb ?? this.priceEtb,
      priceFormatted: priceFormatted ?? this.priceFormatted,
      allowedPlacements: allowedPlacements ?? this.allowedPlacements,
      allowedCategories: allowedCategories ?? this.allowedCategories,
      benefits: benefits ?? this.benefits,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      isActive: isActive ?? this.isActive,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      advertisementsCount: advertisementsCount ?? this.advertisementsCount,
    );
  }
}
