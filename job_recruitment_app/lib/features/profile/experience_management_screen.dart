import 'package:flutter/material.dart';

import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../data/ethiopian_job_titles_data.dart';

class ExperienceManagementScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const ExperienceManagementScreen({super.key, required this.profRepo});

  @override
  State<ExperienceManagementScreen> createState() =>
      _ExperienceManagementScreenState();
}

class _ExperienceManagementScreenState
    extends State<ExperienceManagementScreen> {
  List<dynamic> _experiences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await widget.profRepo.getProfile();
      if (mounted) {
        setState(() {
          _experiences = profile?['work_experiences'] ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddDialog([Map<String, dynamic>? existingItem]) {
    final bool isEditing = existingItem != null;
    final companyController = TextEditingController(
      text: existingItem?['company_name'] ?? '',
    );
    final titleController = TextEditingController(
      text: existingItem?['job_title'] ?? '',
    );
    final typeController = TextEditingController(
      text: existingItem?['employment_type'] ?? 'Full-time',
    );
    final descController = TextEditingController(
      text: existingItem?['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Work Experience' : 'Add Work Experience'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company / Organization Name',
                ),
              ),
              const SizedBox(height: 10),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: titleController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return EthiopianJobCatalogue.searchTitles(
                    textEditingValue.text,
                    limit: 6,
                  );
                },
                onSelected: (String selection) {
                  titleController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      fieldTextEditingController,
                      fieldFocusNode,
                      onFieldSubmitted,
                    ) {
                      if (fieldTextEditingController.text.isEmpty &&
                          titleController.text.isNotEmpty) {
                        fieldTextEditingController.text = titleController.text;
                      }
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Job Title',
                          hintText: 'e.g. Flutter Developer, Accountant...',
                          helperText:
                              'Auto-suggested from Ethiopian job titles',
                        ),
                        onChanged: (text) => titleController.text = text,
                      );
                    },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Employment Type (e.g. Full-time)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Responsibilities Summary',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (companyController.text.isNotEmpty &&
                  titleController.text.isNotEmpty) {
                Navigator.pop(ctx);
                final payload = {
                  'company_name': companyController.text.trim(),
                  'job_title': titleController.text.trim(),
                  'employment_type': typeController.text.trim(),
                  'description': descController.text.trim(),
                };
                if (isEditing) {
                  await widget.profRepo.updateExperience(
                    existingItem['id'],
                    payload,
                  );
                } else {
                  await widget.profRepo.addExperience(payload);
                }
                _load();
              }
            },
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Work Experience?'),
        content: const Text(
          'Are you sure you want to remove this experience record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.profRepo.removeExperience(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('my_experience')),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF0D6B4F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          loc.t('add_experience'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _experiences.isEmpty
          ? const Center(child: Text('No work experience records added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _experiences.length,
              itemBuilder: (context, index) {
                final item = _experiences[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE2E8F0),
                      child: Icon(Icons.work, color: Color(0xFF0D6B4F)),
                    ),
                    title: Text(
                      item['job_title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item['company_name'] ?? ''} • ${item['employment_type'] ?? ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF0D6B4F),
                          ),
                          tooltip: 'Edit Experience',
                          onPressed: () =>
                              _showAddDialog(Map<String, dynamic>.from(item)),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          tooltip: 'Delete Experience',
                          onPressed: () => _confirmDelete(item['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
