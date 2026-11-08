class JobOfferModel {
  final int applicationId;
  final int jobId;
  final String jobTitle;
  final String companyName;
  final String candidateName;
  final double? offerSalary;
  final String? offerBenefits;
  final String? offerConditions;
  final String? offerStartDate;
  final String offerStatus;
  final String? offerNotes;
  final String? candidateResponseNotes;
  final String? offeredAt;
  final String? offerRespondedAt;

  JobOfferModel({
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.companyName,
    required this.candidateName,
    this.offerSalary,
    this.offerBenefits,
    this.offerConditions,
    this.offerStartDate,
    required this.offerStatus,
    this.offerNotes,
    this.candidateResponseNotes,
    this.offeredAt,
    this.offerRespondedAt,
  });

  factory JobOfferModel.fromJson(Map<String, dynamic> json) {
    final jobMap = json['job'] is Map
        ? Map<String, dynamic>.from(json['job'])
        : null;
    final employerMap = jobMap?['employer'] is Map
        ? Map<String, dynamic>.from(jobMap!['employer'])
        : null;
    final userMap = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'])
        : null;

    return JobOfferModel(
      applicationId: json['application_id'] ?? json['id'] ?? 0,
      jobId: json['job_id'] ?? jobMap?['id'] ?? 0,
      jobTitle: json['job_title'] ?? jobMap?['title'] ?? '',
      companyName:
          json['company_name'] ??
          employerMap?['organization_name'] ??
          'Employer',
      candidateName: json['candidate_name'] ?? userMap?['name'] ?? 'Candidate',
      offerSalary: json['offer_salary'] != null
          ? double.tryParse(json['offer_salary'].toString())
          : null,
      offerBenefits: json['offer_benefits'],
      offerConditions: json['offer_conditions'],
      offerStartDate: json['offer_start_date'],
      offerStatus: json['offer_status'] ?? json['status'] ?? 'offered',
      offerNotes: json['offer_notes'],
      candidateResponseNotes: json['candidate_response_notes'],
      offeredAt: json['offered_at'],
      offerRespondedAt: json['offer_responded_at'],
    );
  }

  bool get isOffered => offerStatus == 'offered';
  bool get isPending => offerStatus == 'offered' || offerStatus == 'pending';
  bool get isAccepted => offerStatus == 'accepted';
  bool get isDeclined => offerStatus == 'declined';
  bool get isClarificationRequested => offerStatus == 'clarification_requested';
  String get employerName => companyName;
}
