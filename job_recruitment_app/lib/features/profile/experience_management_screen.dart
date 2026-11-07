import 'package:flutter/material.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../data/ethiopian_job_titles_data.dart';

class ExperienceManagementScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const ExperienceManagementScreen({super.key, required this.profRepo});

  @override
  State<ExperienceManagementScreen> createState() => _ExperienceManagementScreenState();
}

class _ExperienceManagementScreenState extends State<ExperienceManagementScreen> {
  List<dynamic> _experiences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final profile = await widget.profRepo.getProfile();
    if (mounted) {
      setState(() {
        _experiences = profile?['work_experiences'] ?? [];
        _isLoading = false;
      });
    }
  }

  void _showAddDialog() {
    final companyController = TextEditingController();
    final titleController = TextEditingController();
    final typeController = TextEditingController(text: 'Full-time');
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Work Experience'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyController,
                decoration: const InputDecoration(labelText: 'Company / Organization Name'),
              ),
              const SizedBox(height: 10),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return EthiopianJobCatalogue.searchTitles(textEditingValue.text, limit: 6);
                },
                onSelected: (String selection) {
                  titleController.text = selection;
                },
                fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                  return TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Job Title',
                      hintText: 'e.g. Flutter Developer, Accountant...',
                      helperText: 'Auto-suggested from Ethiopian job titles',
                    ),
                    onChanged: (text) => titleController.text = text,
                  );
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Employment Type (e.g. Full-time)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Responsibilities Summary'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (companyController.text.isNotEmpty && titleController.text.isNotEmpty) {
                Navigator.pop(ctx);
                await widget.profRepo.addExperience({
                  'company_name': companyController.text.trim(),
                  'job_title': titleController.text.trim(),
                  'employment_type': typeController.text.trim(),
                  'description': descController.text.trim(),
                });
                _load();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('my_experience')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF0D6B4F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(loc.t('add_experience'), style: const TextStyle(color: Colors.white)),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                          onPressed: () async {
                            await widget.profRepo.removeExperience(item['id']);
                            _load();
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
