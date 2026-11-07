import 'package:flutter/material.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';

class EducationManagementScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const EducationManagementScreen({super.key, required this.profRepo});

  @override
  State<EducationManagementScreen> createState() => _EducationManagementScreenState();
}

class _EducationManagementScreenState extends State<EducationManagementScreen> {
  List<dynamic> _records = [];
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
        _records = profile?['education_records'] ?? [];
        _isLoading = false;
      });
    }
  }

  void _showAddDialog() {
    final instController = TextEditingController();
    final qualController = TextEditingController();
    final fieldController = TextEditingController();
    final gradeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Education Record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: instController,
                decoration: const InputDecoration(labelText: 'Institution Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qualController,
                decoration: const InputDecoration(labelText: 'Qualification / Degree'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fieldController,
                decoration: const InputDecoration(labelText: 'Field of Study'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: gradeController,
                decoration: const InputDecoration(labelText: 'GPA / Grade'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (instController.text.isNotEmpty && qualController.text.isNotEmpty) {
                Navigator.pop(ctx);
                await widget.profRepo.addEducation({
                  'institution_name': instController.text.trim(),
                  'qualification': qualController.text.trim(),
                  'field_of_study': fieldController.text.trim(),
                  'grade': gradeController.text.trim(),
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
        title: Text(loc.t('my_education')),
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
        label: Text(loc.t('add_education'), style: const TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(child: Text('No education records added yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final item = _records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE2E8F0),
                          child: Icon(Icons.school, color: Color(0xFF0D6B4F)),
                        ),
                        title: Text(
                          item['qualification'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item['institution_name'] ?? ''} • ${item['field_of_study'] ?? ''}${item['grade'] != null ? " (GPA: ${item['grade']})" : ""}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                          onPressed: () async {
                            await widget.profRepo.removeEducation(item['id']);
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
