import 'package:flutter/material.dart';
import '../../models/skill_model.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';

class SkillsManagementScreen extends StatefulWidget {
  final ProfileRepository profRepo;

  const SkillsManagementScreen({super.key, required this.profRepo});

  @override
  State<SkillsManagementScreen> createState() => _SkillsManagementScreenState();
}

class _SkillsManagementScreenState extends State<SkillsManagementScreen> {
  List<SkillModel> _userSkills = [];
  List<SkillModel> _allSkills = [];
  List<Map<String, dynamic>> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final userSkills = await widget.profRepo.getUserSkills();
    final allSkills = await widget.profRepo.getAllSkills();
    final badges = await widget.profRepo.getUserBadges();
    if (mounted) {
      setState(() {
        _userSkills = userSkills;
        _allSkills = allSkills;
        _badges = badges;
        _isLoading = false;
      });
    }
  }

  void _showBadgesModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.military_tech, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Verified Skills & Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Badges earned through Ethiopian skill assessment quizzes and evaluations:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const Divider(height: 20),
            if (_badges.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No verified badges earned yet. Complete skill assessments to earn badges!')),
              )
            else
              ..._badges.map((b) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.verified, color: Color(0xFFD97706)),
                    ),
                    title: Text(b['skill']?['name'] ?? 'Skill Badge', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Score: ${b['score']}% • Verified on ${b['verified_at'] ?? "Recent"}'),
                    trailing: const Chip(
                      label: Text('Verified', style: TextStyle(fontSize: 11, color: Color(0xFF0D6B4F))),
                      backgroundColor: Color(0xFFE8F5E9),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    int? selectedSkillId;
    String selectedProficiency = 'intermediate';
    double yearsExp = 1.0;

    // Filter available skills that user hasn't added yet
    final existingIds = _userSkills.map((s) => s.id).toSet();
    final available = _allSkills.where((s) => !existingIds.contains(s.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All predefined skills have been added.')),
      );
      return;
    }

    selectedSkillId = available.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Professional Skill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedSkillId,
                decoration: const InputDecoration(labelText: 'Select Skill'),
                items: available.map((s) {
                  return DropdownMenuItem(value: s.id, child: Text(s.name));
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedSkillId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedProficiency,
                decoration: const InputDecoration(labelText: 'Proficiency Level'),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                  DropdownMenuItem(value: 'expert', child: Text('Expert')),
                ],
                onChanged: (val) => setDialogState(() => selectedProficiency = val!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '1.0',
                decoration: const InputDecoration(labelText: 'Years of Experience'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => yearsExp = double.tryParse(val) ?? 1.0,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedSkillId != null) {
                  Navigator.pop(ctx);
                  await widget.profRepo.addSkill(selectedSkillId!, selectedProficiency, yearsExp);
                  _load();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('my_skills')),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_outlined),
            tooltip: 'Verified Badges',
            onPressed: _showBadgesModal,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Skill',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF0D6B4F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(loc.t('add_skill'), style: const TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userSkills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No skills added yet.'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showAddDialog,
                        child: Text(loc.t('add_skill')),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userSkills.length,
                  itemBuilder: (context, index) {
                    final skill = _userSkills[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE2E8F0),
                          child: Icon(Icons.code, color: Color(0xFF0D6B4F), size: 20),
                        ),
                        title: Text(skill.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Level: ${(skill.proficiencyLevel ?? "intermediate").toUpperCase()} • ${skill.yearsExperience} yrs',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                          onPressed: () async {
                            await widget.profRepo.removeSkill(skill.id);
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
