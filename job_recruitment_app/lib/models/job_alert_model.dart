class JobAlertModel {
  final int id;
  final String title;
  final String? keyword;
  final int? categoryId;
  final String? categoryName;
  final String? location;
  final double? minSalary;
  final String frequency;
  final bool isActive;
  final int matchingJobsCount;
  final String? lastNotifiedAt;

  JobAlertModel({
    required this.id,
    required this.title,
    this.keyword,
    this.categoryId,
    this.categoryName,
    this.location,
    this.minSalary,
    required this.frequency,
    required this.isActive,
    this.matchingJobsCount = 0,
    this.lastNotifiedAt,
  });

  factory JobAlertModel.fromJson(Map<String, dynamic> json) {
    String? catName;
    if (json['category'] is Map) {
      catName = json['category']['name'];
    } else if (json['category'] is String) {
      catName = json['category'];
    } else if (json['category_name'] is String) {
      catName = json['category_name'];
    }

    return JobAlertModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Job Alert',
      keyword: json['keyword'],
      categoryId: json['category_id'],
      categoryName: catName,
      location: json['location'],
      minSalary: json['min_salary'] != null
          ? double.tryParse(json['min_salary'].toString())
          : null,
      frequency: json['frequency'] ?? 'daily',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      matchingJobsCount: json['matching_jobs_count'] ?? 0,
      lastNotifiedAt: json['last_notified_at'],
    );
  }

  JobAlertModel copyWith({
    int? id,
    String? title,
    String? keyword,
    int? categoryId,
    String? categoryName,
    String? location,
    double? minSalary,
    String? frequency,
    bool? isActive,
    int? matchingJobsCount,
    String? lastNotifiedAt,
  }) {
    return JobAlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      keyword: keyword ?? this.keyword,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      location: location ?? this.location,
      minSalary: minSalary ?? this.minSalary,
      frequency: frequency ?? this.frequency,
      isActive: isActive ?? this.isActive,
      matchingJobsCount: matchingJobsCount ?? this.matchingJobsCount,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'keyword': keyword,
      'category_id': categoryId,
      'location': location,
      'min_salary': minSalary,
      'frequency': frequency,
      'is_active': isActive,
    };
  }
}
