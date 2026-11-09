import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/advertising_package_model.dart';
import '../../repositories/advertisement_repository.dart';

class AdvertisingPackageManagerScreen extends StatefulWidget {
  const AdvertisingPackageManagerScreen({super.key});

  @override
  State<AdvertisingPackageManagerScreen> createState() =>
      _AdvertisingPackageManagerScreenState();
}

class _AdvertisingPackageManagerScreenState
    extends State<AdvertisingPackageManagerScreen> {
  List<AdvertisingPackageModel> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages({bool isRefresh = false}) async {
    if (!isRefresh && _packages.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final repo = Provider.of<AdvertisementRepository>(context, listen: false);
      final list = await repo.getAdminAdvertisingPackages();
      if (mounted) {
        setState(() {
          _packages = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleStatus(AdvertisingPackageModel pkg) async {
    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final success = await repo.toggleAdvertisingPackageStatus(pkg.id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !pkg.isActive
                  ? 'Package "${pkg.name}" activated!'
                  : 'Package "${pkg.name}" deactivated.',
            ),
            backgroundColor: !pkg.isActive
                ? const Color(0xFF0D6B4F)
                : const Color(0xFFD97706),
          ),
        );
        _loadPackages(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Failed to toggle package status.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deletePackage(AdvertisingPackageModel pkg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text(
          'Are you sure you want to delete package "${pkg.name}"? If campaigns have already used this package, deactivation is recommended instead.',
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

    if (confirm != true || !mounted) return;

    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final success = await repo.deleteAdvertisingPackage(pkg.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Package "${pkg.name}" deleted successfully.'),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
        _loadPackages(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Failed to delete package.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _openPackageFormDialog({AdvertisingPackageModel? packageToEdit}) {
    showDialog(
      context: context,
      builder: (ctx) => _PackageFormDialog(
        package: packageToEdit,
        onSaved: () => _loadPackages(isRefresh: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertising Packages & Rates'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPackageFormDialog(),
        backgroundColor: const Color(0xFF0D6B4F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Package'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D6B4F)),
      );
    }

    if (_packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No advertising packages configured.',
              style: TextStyle(fontSize: 16, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _openPackageFormDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Create First Package'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPackages(isRefresh: true),
      color: const Color(0xFF0D6B4F),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _packages.length,
        itemBuilder: (ctx, index) {
          final pkg = _packages[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: pkg.isActive
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFFCA5A5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title & Active Switch
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pkg.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (pkg.badgeLabel != null &&
                                    pkg.badgeLabel!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6B4F).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      pkg.badgeLabel!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D6B4F),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: ${pkg.durationText} | Slug: ${pkg.slug}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: pkg.isActive,
                        activeColor: const Color(0xFF0D6B4F),
                        onChanged: (_) => _toggleStatus(pkg),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Price and Usage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            pkg.priceEtb.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0D6B4F),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'ETB',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D6B4F),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pkg.advertisementsCount} active campaigns',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (pkg.description != null && pkg.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      pkg.description!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 8),

                  // Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _deletePackage(pkg),
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openPackageFormDialog(packageToEdit: pkg),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Edit Rate & Terms'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
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

class _PackageFormDialog extends StatefulWidget {
  final AdvertisingPackageModel? package;
  final VoidCallback onSaved;

  const _PackageFormDialog({this.package, required this.onSaved});

  @override
  State<_PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends State<_PackageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priorityCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _badgeCtrl;
  late TextEditingController _benefitsCtrl;

  List<String> _selectedPlacements = [];
  List<String> _selectedCategories = [];
  bool _isActive = true;
  bool _isSubmitting = false;

  final List<Map<String, String>> _allPlacements = [
    {'key': 'hero', 'label': '★ Top Hero Carousel'},
    {'key': 'dashboard', 'label': 'Dashboard Billboard'},
    {'key': 'job_list', 'label': 'Job Feed Highlight'},
    {'key': 'sidebar', 'label': 'Sidebar Widget'},
    {'key': 'search_sponsored', 'label': 'Sponsored Search'},
    {'key': 'category_specific', 'label': 'Category Radar'},
  ];

  final List<Map<String, String>> _allCategories = [
    {'key': 'featured_jobs', 'label': 'Featured Vacancies'},
    {'key': 'company_promotions', 'label': 'Company & Brand'},
    {'key': 'recruitment_campaigns', 'label': 'Recruitment Campaigns'},
    {'key': 'sponsored_vacancies', 'label': 'Sponsored Vacancies'},
    {'key': 'announcements', 'label': 'Announcements'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(
      text: p != null ? p.priceEtb.toStringAsFixed(2) : '2500.00',
    );
    _durationCtrl = TextEditingController(
      text: p != null ? p.durationDays.toString() : '15',
    );
    _priorityCtrl = TextEditingController(
      text: p != null ? p.priorityLevel.toString() : '0',
    );
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _badgeCtrl = TextEditingController(text: p?.badgeLabel ?? '');
    _benefitsCtrl = TextEditingController(text: p?.benefits.join('\n') ?? '');

    _selectedPlacements = p != null && p.allowedPlacements.isNotEmpty
        ? List.from(p.allowedPlacements)
        : ['dashboard', 'job_list'];
    _selectedCategories = p != null && p.allowedCategories.isNotEmpty
        ? List.from(p.allowedCategories)
        : ['featured_jobs', 'sponsored_vacancies'];
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _priorityCtrl.dispose();
    _descCtrl.dispose();
    _badgeCtrl.dispose();
    _benefitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlacements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one authorized app placement.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one eligible campaign category.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final benefitsList = _benefitsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final cleanPrice = _priceCtrl.text.replaceAll(',', '').replaceAll(' ', '').trim();
    final cleanDuration = _durationCtrl.text.replaceAll(',', '').replaceAll(' ', '').trim();
    final cleanPriority = _priorityCtrl.text.replaceAll(',', '').replaceAll(' ', '').trim();

    final data = {
      'name': _nameCtrl.text.trim(),
      'price_etb': double.tryParse(cleanPrice) ?? 0.0,
      'duration_days': int.tryParse(cleanDuration) ?? 15,
      'priority_level': int.tryParse(cleanPriority) ?? 0,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'badge_label': _badgeCtrl.text.trim().isNotEmpty
          ? _badgeCtrl.text.trim()
          : null,
      'allowed_placements': _selectedPlacements,
      'allowed_categories': _selectedCategories,
      'benefits': benefitsList,
      'is_active': _isActive,
    };

    final repo = Provider.of<AdvertisementRepository>(context, listen: false);

    bool ok = false;
    if (widget.package != null) {
      final updated = await repo.updateAdvertisingPackage(widget.package!.id, data);
      ok = updated != null;
    } else {
      final created = await repo.createAdvertisingPackage(data);
      ok = created != null;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.package != null
                  ? 'Package updated successfully!'
                  : 'New package created successfully!',
            ),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Operation failed.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.package != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Package Rate & Terms' : 'Create Advertising Package'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Package Name *',
                    hintText: 'e.g. Standard 15-Day Blast',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price (ETB) *',
                          prefixText: 'ETB ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final cleaned = v.replaceAll(',', '').replaceAll(' ', '').trim();
                          final num = double.tryParse(cleaned);
                          if (num == null || num < 0) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration *',
                          suffixText: 'days',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final cleaned = v.replaceAll(',', '').replaceAll(' ', '').trim();
                          final num = int.tryParse(cleaned);
                          if (num == null || num <= 0 || num > 365) return '1-365 days';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _priorityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          hintText: '0-100',
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final num = int.tryParse(v.trim());
                            if (num == null || num < 0 || num > 100) return '0-100';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _badgeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Badge Label (Optional)',
                    hintText: 'e.g. Popular, Starter, Best Value, Fast Hire',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Summary Description',
                    hintText: 'Brief marketing blurb explaining the package reach',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Allowed Placements *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allPlacements.map((item) {
                    final p = item['key']!;
                    final label = item['label']!;
                    final selected = _selectedPlacements.contains(p);
                    return FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      selected: selected,
                      selectedColor: const Color(0xFF0D6B4F).withOpacity(0.18),
                      checkmarkColor: const Color(0xFF0D6B4F),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedPlacements.add(p);
                          } else {
                            _selectedPlacements.remove(p);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Eligible Campaign Categories *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allCategories.map((item) {
                    final c = item['key']!;
                    final label = item['label']!;
                    final selected = _selectedCategories.contains(c);
                    return FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      selected: selected,
                      selectedColor: const Color(0xFF2563EB).withOpacity(0.18),
                      checkmarkColor: const Color(0xFF2563EB),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedCategories.add(c);
                          } else {
                            _selectedCategories.remove(c);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Key Benefits / Inclusions (one per line):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _benefitsCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        "15 Days prominent listing\nTop search priority\nReal-time telemetry",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active for purchase'),
                  subtitle: const Text('Visible to employers when creating campaigns'),
                  value: _isActive,
                  activeColor: const Color(0xFF0D6B4F),
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D6B4F),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Save Changes' : 'Create Package'),
        ),
      ],
    );
  }
}
