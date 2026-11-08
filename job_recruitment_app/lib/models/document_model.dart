class DocumentModel {
  final int id;
  final int userId;
  final String originalName;
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final String documentType;
  final String createdAt;

  DocumentModel({
    required this.id,
    required this.userId,
    required this.originalName,
    required this.storagePath,
    required this.mimeType,
    required this.fileSize,
    required this.documentType,
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      originalName: json['original_name'] ?? '',
      storagePath: json['storage_path'] ?? '',
      mimeType: json['mime_type'] ?? '',
      fileSize: json['file_size'] is int
          ? json['file_size']
          : (int.tryParse(json['file_size']?.toString() ?? '0') ?? 0),
      documentType: json['document_type'] ?? 'other',
      createdAt: json['created_at'] ?? '',
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
