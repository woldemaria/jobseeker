import 'package:flutter/material.dart';

import '../../models/job_model.dart';
import '../../models/skill_model.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/location_map_modal.dart';
import '../../data/ethiopian_job_titles_data.dart';

class CreateJobScreen extends StatefulWidget {
  final JobRepository jobRepo;
  final ProfileRepository profRepo;
  final JobModel? initialJob;
  final VoidCallback? onSuccess;

  const CreateJobScreen({
    super.key,
    required this.jobRepo,
    required this.profRepo,
    this.initialJob,
    this.onSuccess,
  });

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _respController = TextEditingController();
  final _reqController = TextEditingController();
  final _locationController = TextEditingController(text: 'Addis Ababa');
  final _expController = TextEditingController(text: '2.0');
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _deadlineController = TextEditingController();

  String _employmentType = 'Full-time';
  String _status = 'published';
  String _selectedCategory = 'Information Technology';
  List<SkillModel> _allSkills = [];
  final Set<int> _selectedRequiredSkillIds = {};
  final Set<int> _selectedPreferredSkillIds = {};
  bool _isLoadingSkills = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initialJob != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final job = widget.initialJob!;
      _titleController.text = job.title;
      _descController.text = job.description;
      _respController.text = job.responsibilities ?? '';
      _reqController.text = job.requirements ?? '';
      _locationController.text = job.location;
      _employmentType = job.employmentType;
      _status = job.status;
      if (job.category != null && job.category!.isNotEmpty) {
        _selectedCategory = job.category!;
      } else {
        final inferred = EthiopianJobCatalogue.findCategoryForTitle(job.title);
        if (inferred != null) _selectedCategory = inferred.name;
      }
      if (job.experienceRequired != null) {
        _expController.text = job.experienceRequired!.toString();
      }
      if (job.salaryMin != null) {
        _salaryMinController.text = job.salaryMin!.toStringAsFixed(0);
      }
      if (job.salaryMax != null) {
        _salaryMaxController.text = job.salaryMax!.toStringAsFixed(0);
      }
      _deadlineController.text = job.deadline;

      for (var skill in job.skills) {
        if (skill.importance == 'preferred') {
          _selectedPreferredSkillIds.add(skill.id);
        } else {
          _selectedRequiredSkillIds.add(skill.id);
        }
      }
    } else {
      final defaultDate = DateTime.now().add(const Duration(days: 30));
      _deadlineController.text =
          '${defaultDate.year}-${defaultDate.month.toString().padLeft(2, '0')}-${defaultDate.day.toString().padLeft(2, '0')}';
    }
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    try {
      final skills = await widget.profRepo.getAllSkills();
      if (mounted) {
        setState(() {
          _allSkills = skills;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingSkills = false);
      }
    }
  }

  Future<void> _submitJob() async {
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter job title and description.'),
        ),
      );
      return;
    }

    final double? salaryMin = double.tryParse(_salaryMinController.text.trim());
    final double? salaryMax = double.tryParse(_salaryMaxController.text.trim());

    if (salaryMin != null && salaryMax != null && salaryMax < salaryMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum salary cannot be less than minimum salary.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final List<Map<String, dynamic>> skillsPayload = [];
    for (var id in _selectedRequiredSkillIds) {
      skillsPayload.add({'skill_id': id, 'importance': 'required'});
    }
    for (var id in _selectedPreferredSkillIds) {
      skillsPayload.add({'skill_id': id, 'importance': 'preferred'});
    }

    final Map<String, dynamic> payload = {
      'category': _selectedCategory,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'responsibilities': _respController.text.trim(),
      'requirements': _reqController.text.trim(),
      'location': _locationController.text.trim(),
      'employment_type': _employmentType,
      'experience_required': double.tryParse(_expController.text.trim()) ?? 0.0,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'deadline': _deadlineController.text.trim(),
      'status': _status,
      'skills': skillsPayload,
    };

    final resp = _isEditing
        ? await widget.jobRepo.updateJob(widget.initialJob!.id, payload)
        : await widget.jobRepo.createJob(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (resp.success) {
        final jobData = resp.data is Map ? resp.data as Map : null;
        final bool isQuarantined =
            jobData?['moderation_status'] == 'under_review';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isQuarantined
                  ? 'Vacancy submitted for security review (quarantined) due to policy triggers.'
                  : (_isEditing
                        ? 'Vacancy updated successfully!'
                        : 'Vacancy published successfully!'),
            ),
            backgroundColor: isQuarantined
                ? Colors.amber.shade900
                : const Color(0xFF0D6B4F),
          ),
        );

        widget.onSuccess?.call();

        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          _clearForm();
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resp.message)));
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descController.clear();
    _respController.clear();
    _reqController.clear();
    _salaryMinController.clear();
    _salaryMaxController.clear();
    final defaultDate = DateTime.now().add(const Duration(days: 30));
    _deadlineController.text =
        '${defaultDate.year}-${defaultDate.month.toString().padLeft(2, '0')}-${defaultDate.day.toString().padLeft(2, '0')}';
    setState(() {
      _status = 'published';
      _selectedRequiredSkillIds.clear();
      _selectedPreferredSkillIds.clear();
    });
  }

  Future<void> _deleteVacancy() async {
    if (!_isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vacancy'),
        content: Text(
          'Are you sure you want to permanently delete / archive "${widget.initialJob!.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSubmitting = true);
      final resp = await widget.jobRepo.archiveJob(widget.initialJob!.id);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (resp.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vacancy deleted successfully.'),
              backgroundColor: Color(0xFF0D6B4F),
            ),
          );
          widget.onSuccess?.call();
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resp.message.isNotEmpty
                    ? resp.message
                    : 'Failed to delete vacancy.',
              ),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _respController.dispose();
    _reqController.dispose();
    _locationController.dispose();
    _expController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Vacancy' : loc.t('create_job')),
      ),
      body: _isLoadingSkills
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Ethiopian Industry / Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Industry Sector / Category *',
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: Color(0xFF0D6B4F),
                    ),
                  ),
                  isExpanded: true,
                  items: EthiopianJobCatalogue.categories.map((c) {
                    return DropdownMenuItem(
                      value: c.name,
                      child: Row(
                        children: [
                          Icon(
                            c.icon,
                            size: 16,
                            color: const Color(0xFF0D6B4F),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c.name} (${c.titles.length} titles)',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                // Job Title Autocomplete Field
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _titleController.text),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return EthiopianJobCatalogue.searchTitles(
                        '',
                        categoryName: _selectedCategory,
                        limit: 6,
                      );
                    }
                    return EthiopianJobCatalogue.searchTitles(
                      textEditingValue.text,
                      categoryName: _selectedCategory,
                      limit: 8,
                    );
                  },
                  onSelected: (String selection) {
                    _titleController.text = selection;
                    final cat = EthiopianJobCatalogue.findCategoryForTitle(
                      selection,
                    );
                    if (cat != null) {
                      setState(() => _selectedCategory = cat.name);
                    }
                  },
                  fieldViewBuilder:
                      (
                        context,
                        fieldTextEditingController,
                        fieldFocusNode,
                        onFieldSubmitted,
                      ) {
                        if (_titleController.text.isNotEmpty &&
                            fieldTextEditingController.text !=
                                _titleController.text) {
                          fieldTextEditingController.text =
                              _titleController.text;
                        }
                        return TextField(
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Job Title *',
                            hintText: 'e.g. Flutter Developer, Agronomist, Civil Engineer...',
                            helperText: 'Select from 475 Ethiopian standard titles or type custom',
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF0D6B4F),
                            ),
                          ),
                          onChanged: (text) => _titleController.text = text,
                        );
                      },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: loc.t('location'),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.map_outlined,
                              color: Color(0xFF0D6B4F),
                            ),
                            tooltip: 'Preview on OpenStreetMap / Google Maps',
                            onPressed: () {
                              final text = _locationController.text.trim();
                              if (text.isNotEmpty) {
                                LocationMapModal.show(
                                  context,
                                  title: 'Workplace Location',
                                  address: text,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _employmentType,
                        decoration: InputDecoration(
                          labelText: loc.t('employment_type'),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Full-time',
                            child: Text('Full-time'),
                          ),
                          DropdownMenuItem(
                            value: 'Part-time',
                            child: Text('Part-time'),
                          ),
                          DropdownMenuItem(
                            value: 'Contract',
                            child: Text('Contract'),
                          ),
                          DropdownMenuItem(
                            value: 'Internship',
                            child: Text('Internship'),
                          ),
                          DropdownMenuItem(
                            value: 'Remote',
                            child: Text('Remote'),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _employmentType = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Vacancy Status',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('Published'),
                          ),
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('Draft'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('Closed'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _status = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _expController,
                        decoration: const InputDecoration(
                          labelText: 'Experience (Years)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _salaryMinController,
                        decoration: const InputDecoration(
                          labelText: 'Min Salary (ETB)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _salaryMaxController,
                        decoration: const InputDecoration(
                          labelText: 'Max Salary (ETB)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deadlineController,
                  readOnly: true,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 30)),
                      firstDate: now.add(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      _deadlineController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                  decoration: InputDecoration(
                    labelText: loc.t('deadline'),
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: '${loc.t('job_description')} *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _respController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: loc.t('responsibilities'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reqController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: loc.t('requirements')),
                ),
                const SizedBox(height: 16),

                // Skill requirements section
                const Text(
                  'Select Required Skills (Critical for Matching):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allSkills.map((s) {
                    final isSelected = _selectedRequiredSkillIds.contains(s.id);
                    return FilterChip(
                      label: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D6B4F),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedRequiredSkillIds.add(s.id);
                            _selectedPreferredSkillIds.remove(s.id);
                          } else {
                            _selectedRequiredSkillIds.remove(s.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Select Preferred Skills (Bonus Points):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allSkills.map((s) {
                    final isSelected = _selectedPreferredSkillIds.contains(
                      s.id,
                    );
                    return FilterChip(
                      label: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFD97706),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedPreferredSkillIds.add(s.id);
                            _selectedRequiredSkillIds.remove(s.id);
                          } else {
                            _selectedPreferredSkillIds.remove(s.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _deleteVacancy,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Delete Vacancy',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitJob,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6B4F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Update Vacancy',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            loc.t('create_job'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
