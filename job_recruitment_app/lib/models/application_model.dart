import 'job_model.dart';
import 'document_model.dart';
import 'user_model.dart';

class ApplicationModel {
  final int id;
  final int jobId;
  final int profileId;
  final int cvDocumentId;
  final String? coverLetter;
  final String status;
  final String appliedAt;
  final String? interviewAt;
  final String? interviewType;
  final String? interviewLocation;
  final String? interviewNotes;
  final String? interviewStatus;
  final JobModel? job;
  final DocumentModel? cvDocument;
  final JobSeekerProfileModel? profile;
  final List<StatusHistoryModel> statusHistories;

  ApplicationModel({
    required this.id,
    required this.jobId,
    required this.profileId,
    required this.cvDocumentId,
    this.coverLetter,
    required this.status,
    required this.appliedAt,
    this.interviewAt,
    this.interviewType,
    this.interviewLocation,
    this.interviewNotes,
    this.interviewStatus,
    this.job,
    this.cvDocument,
    this.profile,
    this.statusHistories = const [],
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    List<StatusHistoryModel> histories = [];
    if (json['status_histories'] != null && json['status_histories'] is List) {
      histories = (json['status_histories'] as List)
          .map((h) => StatusHistoryModel.fromJson(h))
          .toList();
    }

    return ApplicationModel(
      id: json['id'] ?? 0,
      jobId: json['job_id'] ?? 0,
      profileId: json['profile_id'] ?? 0,
      cvDocumentId: json['cv_document_id'] ?? 0,
      coverLetter: json['cover_letter'],
      status: json['status'] ?? 'submitted',
      appliedAt: json['applied_at'] ?? '',
      interviewAt: json['interview_at'],
      interviewType: json['interview_type'],
      interviewLocation: json['interview_location'],
      interviewNotes: json['interview_notes'],
      interviewStatus: json['interview_status'],
      job: json['job'] != null ? JobModel.fromJson(json['job']) : null,
      cvDocument: json['cv_document'] != null
          ? DocumentModel.fromJson(json['cv_document'])
          : null,
      profile: json['profile'] != null
          ? JobSeekerProfileModel.fromJson(json['profile'])
          : null,
      statusHistories: histories,
    );
  }
}

class StatusHistoryModel {
  final int id;
  final String? oldStatus;
  final String newStatus;
  final String? notes;
  final String createdAt;

  StatusHistoryModel({
    required this.id,
    this.oldStatus,
    required this.newStatus,
    this.notes,
    required this.createdAt,
  });

  factory StatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return StatusHistoryModel(
      id: json['id'] ?? 0,
      oldStatus: json['old_status'],
      newStatus: json['new_status'] ?? '',
      notes: json['notes'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
