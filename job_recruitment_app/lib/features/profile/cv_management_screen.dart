import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/document_model.dart';
import '../../repositories/profile_repository.dart';

class CvManagementScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const CvManagementScreen({super.key, required this.profRepo});

  @override
  State<CvManagementScreen> createState() => _CvManagementScreenState();
}

class _CvManagementScreenState extends State<CvManagementScreen> {
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final docs = await widget.profRepo.getDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadDocument() async {
    String selectedType = 'cv';
    List<int>? pickedBytes;
    String? pickedName;
    int? pickedSize;

    final shouldUpload = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upload Document from Disk',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Document Type Dropdown
                  const Text('Document Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'cv', child: Text('Curriculum Vitae / Resume (CV)')),
                      DropdownMenuItem(value: 'certificate', child: Text('Professional Certificate')),
                      DropdownMenuItem(value: 'transcript', child: Text('Academic Transcript')),
                      DropdownMenuItem(value: 'verification', child: Text('Verification / Identification Document')),
                      DropdownMenuItem(value: 'other', child: Text('Other Supporting Document')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // File Picker Trigger
                  InkWell(
                    onTap: () async {
                      try {
                        final files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                        );
                        if (files.isNotEmpty) {
                          final f = files.first;
                          final bytes = await f.readAsBytes();
                          setSheetState(() {
                            pickedBytes = bytes;
                            pickedName = f.name;
                            pickedSize = bytes.length;
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File picker error: $e')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(
                          color: pickedName != null ? AppTheme.primaryColor : Colors.grey.shade300,
                          width: pickedName != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            pickedName != null ? Icons.check_circle : Icons.upload_file,
                            size: 40,
                            color: pickedName != null ? AppTheme.primaryColor : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pickedName != null
                                ? pickedName!
                                : 'Choose PDF, Word (DOC/DOCX), or image file from disk',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: pickedName != null ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                              color: pickedName != null ? Colors.black87 : Colors.grey.shade700,
                            ),
                          ),
                          if (pickedSize != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${(pickedSize! / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Upload Button
                  ElevatedButton.icon(
                    onPressed: pickedBytes == null
                        ? null
                        : () {
                            Navigator.pop(ctx, true);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Confirm & Upload Document'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldUpload == true && pickedBytes != null && pickedName != null) {
      setState(() => _isUploading = true);
      try {
        final resp = await widget.profRepo.uploadDocumentBytes(
          pickedBytes!,
          pickedName!,
          selectedType,
        );

        if (mounted) {
          setState(() => _isUploading = false);
          if (resp.success) {
            _load();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$pickedName" uploaded successfully!'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(resp.message)),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      }
    }
  }

  void _downloadOrViewDocument(DocumentModel doc, {bool viewInline = true}) {
    final token = widget.profRepo.authToken;
    final queryParams = <String, String>{};
    if (token != null && token.isNotEmpty) {
      queryParams['token'] = token;
    }
    if (viewInline) {
      queryParams['view'] = '1';
    }
    final baseUri = Uri.parse('${ApiConstants.baseUrl}/documents/${doc.id}/download');
    final uri = queryParams.isEmpty ? baseUri : baseUri.replace(queryParameters: queryParams);
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to remove "${doc.originalName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final resp = await widget.profRepo.deleteDocument(doc.id);
      if (mounted) {
        if (resp.success) {
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${doc.originalName}"')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resp.message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('manage_cv')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadDocument,
        backgroundColor: AppTheme.primaryColor,
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.upload_file, color: Colors.white),
        label: Text(loc.t('upload_document'), style: const TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'No CVs or certificates uploaded yet.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload your CV in PDF or DOCX format from your disk or device.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickAndUploadDocument,
                        icon: const Icon(Icons.upload),
                        label: Text(loc.t('upload_document')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(220, 44),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1.5,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: _getDocumentColor(doc.documentType).withOpacity(0.12),
                          child: Icon(
                            _getDocumentIcon(doc.documentType),
                            color: _getDocumentColor(doc.documentType),
                          ),
                        ),
                        title: Text(
                          doc.originalName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${doc.documentType.toUpperCase()} • ${doc.formattedSize} • ${doc.createdAt.split('T').first}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Download / View',
                              icon: const Icon(Icons.download_outlined, color: AppTheme.primaryColor),
                              onPressed: () => _downloadOrViewDocument(doc),
                            ),
                            IconButton(
                              tooltip: 'Delete Document',
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteDocument(doc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Color _getDocumentColor(String docType) {
    switch (docType) {
      case 'cv':
        return Colors.red.shade700;
      case 'certificate':
        return Colors.blue.shade700;
      case 'transcript':
        return Colors.purple.shade700;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getDocumentIcon(String docType) {
    switch (docType) {
      case 'cv':
        return Icons.badge_outlined;
      case 'certificate':
        return Icons.verified_outlined;
      case 'transcript':
        return Icons.school_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
