import 'skill_model.dart';
import 'user_model.dart';

class JobModel {
  final int id;
  final int employerId;
  final String? category;
  final int? categoryId;
  final int? jobTitleId;
  final String title;
  final String description;
  final String? responsibilities;
  final String? requirements;
  final String location;
  final double? latitude;
  final double? longitude;
  final String employmentType;
  final double? experienceRequired;
  final double? salaryMin;
  final double? salaryMax;
  final String currency;
  final String deadline;
  final String status;
  final String? publishedAt;
  final EmployerModel? employer;
  final List<SkillModel> skills;
  final bool isSaved;
  final bool hasApplied;
  final String? applicationStatus;
  final double? matchScore;
  final Map<String, dynamic>? matchDetails;
  final int? applicantsCount;
  final int fraudScore;
  final String fraudRiskLevel;
  final List<String> fraudIndicators;
  final bool isFlagged;
  final String moderationStatus;
  final String? moderationNotes;

  JobModel({
    required this.id,
    required this.employerId,
    this.category,
    this.categoryId,
    this.jobTitleId,
    required this.title,
    required this.description,
    this.responsibilities,
    this.requirements,
    required this.location,
    this.latitude,
    this.longitude,
    required this.employmentType,
    this.experienceRequired,
    this.salaryMin,
    this.salaryMax,
    required this.currency,
    required this.deadline,
    required this.status,
    this.publishedAt,
    this.employer,
    this.skills = const [],
    this.isSaved = false,
    this.hasApplied = false,
    this.applicationStatus,
    this.matchScore,
    this.matchDetails,
    this.applicantsCount,
    this.fraudScore = 0,
    this.fraudRiskLevel = 'low',
    this.fraudIndicators = const [],
    this.isFlagged = false,
    this.moderationStatus = 'clean',
    this.moderationNotes,
  });

  JobModel copyWith({
    int? id,
    int? employerId,
    String? category,
    int? categoryId,
    int? jobTitleId,
    String? title,
    String? description,
    String? responsibilities,
    String? requirements,
    String? location,
    double? latitude,
    double? longitude,
    String? employmentType,
    double? experienceRequired,
    double? salaryMin,
    double? salaryMax,
    String? currency,
    String? deadline,
    String? status,
    String? publishedAt,
    EmployerModel? employer,
    List<SkillModel>? skills,
    bool? isSaved,
    bool? hasApplied,
    String? applicationStatus,
    double? matchScore,
    Map<String, dynamic>? matchDetails,
    int? applicantsCount,
    int? fraudScore,
    String? fraudRiskLevel,
    List<String>? fraudIndicators,
    bool? isFlagged,
    String? moderationStatus,
    String? moderationNotes,
  }) {
    return JobModel(
      id: id ?? this.id,
      employerId: employerId ?? this.employerId,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      jobTitleId: jobTitleId ?? this.jobTitleId,
      title: title ?? this.title,
      description: description ?? this.description,
      responsibilities: responsibilities ?? this.responsibilities,
      requirements: requirements ?? this.requirements,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      employmentType: employmentType ?? this.employmentType,
      experienceRequired: experienceRequired ?? this.experienceRequired,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      currency: currency ?? this.currency,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      employer: employer ?? this.employer,
      skills: skills ?? this.skills,
      isSaved: isSaved ?? this.isSaved,
      hasApplied: hasApplied ?? this.hasApplied,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      matchScore: matchScore ?? this.matchScore,
      matchDetails: matchDetails ?? this.matchDetails,
      applicantsCount: applicantsCount ?? this.applicantsCount,
      fraudScore: fraudScore ?? this.fraudScore,
      fraudRiskLevel: fraudRiskLevel ?? this.fraudRiskLevel,
      fraudIndicators: fraudIndicators ?? this.fraudIndicators,
      isFlagged: isFlagged ?? this.isFlagged,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      moderationNotes: moderationNotes ?? this.moderationNotes,
    );
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    List<SkillModel> skillList = [];
    if (json['skills'] != null && json['skills'] is List) {
      skillList = (json['skills'] as List)
          .map((s) => SkillModel.fromJson(s))
          .toList();
    }

    return JobModel(
      id: json['id'] ?? 0,
      employerId: json['employer_id'] ?? 0,
      category: json['category'] is String
          ? json['category'] as String
          : (json['category'] is Map
                ? (json['category']['name']?.toString())
                : (json['category_name']?.toString())),
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? ''),
      jobTitleId: json['job_title_id'] is int
          ? json['job_title_id']
          : int.tryParse(json['job_title_id']?.toString() ?? ''),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      responsibilities: json['responsibilities'],
      requirements: json['requirements'],
      location: json['location'] ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      employmentType: json['employment_type'] ?? 'Full-time',
      experienceRequired: json['experience_required'] != null
          ? double.tryParse(json['experience_required'].toString())
          : null,
      salaryMin: json['salary_min'] != null
          ? double.tryParse(json['salary_min'].toString())
          : null,
      salaryMax: json['salary_max'] != null
          ? double.tryParse(json['salary_max'].toString())
          : null,
      currency: json['currency'] ?? 'ETB',
      deadline: json['deadline'] ?? '',
      status: json['status'] ?? 'draft',
      publishedAt: json['published_at'],
      employer: json['employer'] is Map<String, dynamic>
          ? EmployerModel.fromJson(json['employer'])
          : null,
      skills: skillList,
      isSaved: json['is_saved'] ?? false,
      hasApplied: json['has_applied'] ?? false,
      applicationStatus: json['application_status'],
      matchScore: json['match_score'] != null
          ? double.tryParse(json['match_score'].toString())
          : null,
      matchDetails: json['match_details'],
      applicantsCount: json['applications_count'] is int
          ? json['applications_count']
          : int.tryParse(json['applications_count']?.toString() ??
              json['applicants_count']?.toString() ??
              ''),
      fraudScore: json['fraud_score'] is int
          ? json['fraud_score']
          : (int.tryParse(json['fraud_score']?.toString() ?? '0') ?? 0),
      fraudRiskLevel: json['fraud_risk_level']?.toString() ?? 'low',
      fraudIndicators: json['fraud_indicators'] is List
          ? (json['fraud_indicators'] as List).map((e) => e.toString()).toList()
          : const [],
      isFlagged: json['is_flagged'] == true || json['is_flagged'] == 1,
      moderationStatus: json['moderation_status']?.toString() ?? 'clean',
      moderationNotes: json['moderation_notes']?.toString(),
    );
  }

  bool get isHighFraudRisk =>
      fraudScore >= 60 ||
      fraudRiskLevel == 'high' ||
      fraudRiskLevel == 'critical';

  bool get isMediumFraudRisk => fraudScore >= 30 && fraudScore < 60;

  bool get isQuarantinedOrFraud =>
      moderationStatus == 'under_review' || moderationStatus == 'fraudulent';

  String get salaryText {
    if (salaryMin == null && salaryMax == null) return 'Negotiable';
    if (salaryMin != null && salaryMax != null) {
      return '${salaryMin!.toStringAsFixed(0)} - ${salaryMax!.toStringAsFixed(0)} $currency';
    }
    if (salaryMin != null) {
      return 'From ${salaryMin!.toStringAsFixed(0)} $currency';
    }
    return 'Up to ${salaryMax!.toStringAsFixed(0)} $currency';
  }

  String get employerName => employer?.organizationName ?? 'Employer';
}
