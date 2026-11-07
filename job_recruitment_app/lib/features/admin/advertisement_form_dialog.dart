import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/advertisement_model.dart';
import '../../models/job_model.dart';
import '../../repositories/advertisement_repository.dart';

class AdvertisementFormDialog extends StatefulWidget {
  final AdvertisementRepository adRepo;
  final AdvertisementModel? initialAd;
  final JobModel? initialJob;

  const AdvertisementFormDialog({
    super.key,
    required this.adRepo,
    this.initialAd,
    this.initialJob,
  });

  static Future<bool?> show(
    BuildContext context, {
    required AdvertisementRepository adRepo,
    AdvertisementModel? initialAd,
    JobModel? initialJob,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdvertisementFormDialog(
        adRepo: adRepo,
        initialAd: initialAd,
        initialJob: initialJob,
      ),
    );
  }

  @override
  State<AdvertisementFormDialog> createState() => _AdvertisementFormDialogState();
}

class _AdvertisementFormDialogState extends State<AdvertisementFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _titleAmController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _subtitleAmController;
  late final TextEditingController _badgeController;
  late final TextEditingController _badgeAmController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _ctaTextController;
  late final TextEditingController _ctaTextAmController;
  late final TextEditingController _ctaTargetController;
  late final TextEditingController _priorityController;

  late String _category;
  late String _placement;
  late String _targetRole;
  late String _ctaType;
  late String _status;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _isSubmitting = false;

  final List<String> _categories = [
    'featured_jobs',
    'company_promotions',
    'recruitment_campaigns',
    'sponsored_vacancies',
    'announcements',
  ];

  final List<String> _placements = [
    'hero',
    'dashboard',
    'job_list',
    'category_specific',
  ];

  final List<String> _targetRoles = [
    'all',
    'job_seeker',
    'employer',
  ];

  final List<String> _ctaTypes = [
    'apply_now',
    'view_details',
    'explore_jobs',
    'register',
    'visit_company',
    'external_link',
  ];

  final List<String> _statuses = [
    'active',
    'scheduled',
    'paused',
    'expired',
    'pending_approval',
  ];

  // Preset curated high-resolution campaign banner images
  final Map<String, String> _imagePresets = {
    'Tech & Cloud': 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80',
    'Aviation': 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=1200&q=80',
    'Banking': 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1200&q=80',
    'Engineering': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=80',
    'Healthcare': 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=1200&q=80',
    'Telecom': 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1200&q=80',
  };

  @override
  void initState() {
    super.initState();
    final ad = widget.initialAd;
    final job = widget.initialJob;

    final defaultTitle = ad?.title ?? (job != null ? 'Featured Vacancy: ${job.title}' : '');
    final defaultSubtitle = ad?.subtitle ?? (job != null ? '${job.employmentType} position in ${job.location}' : '');
    final defaultBadge = ad?.badgeText ?? (job != null ? 'SPONSORED VACANCY' : '');
    final defaultBadgeAm = ad?.badgeTextAm ?? (job != null ? 'ስፖንሰር የተደረገ የስራ መደብ' : '');
    final defaultImage = ad?.imageUrl ?? 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80';
    final defaultCtaText = ad?.ctaText ?? (job != null ? 'Apply Now' : 'Explore Openings');
    final defaultCtaTextAm = ad?.ctaTextAm ?? (job != null ? 'አሁን ያመልክቱ' : 'ክፍት ቦታዎችን ይመልከቱ');
    final defaultCtaTarget = ad?.ctaTarget ?? (job != null ? '/jobs/${job.id}' : '/jobs');
    final defaultCategory = ad?.category ?? (job != null ? 'sponsored_vacancies' : 'featured_jobs');
    final defaultCtaType = ad?.ctaType ?? (job != null ? 'apply_now' : 'explore_jobs');

    _titleController = TextEditingController(text: defaultTitle);
    _titleAmController = TextEditingController(text: ad?.titleAm ?? '');
    _subtitleController = TextEditingController(text: defaultSubtitle);
    _subtitleAmController = TextEditingController(text: ad?.subtitleAm ?? '');
    _badgeController = TextEditingController(text: defaultBadge);
    _badgeAmController = TextEditingController(text: defaultBadgeAm);
    _imageUrlController = TextEditingController(text: defaultImage);
    _ctaTextController = TextEditingController(text: defaultCtaText);
    _ctaTextAmController = TextEditingController(text: defaultCtaTextAm);
    _ctaTargetController = TextEditingController(text: defaultCtaTarget);
    _priorityController = TextEditingController(text: (ad?.priority ?? 10).toString());

    _category = defaultCategory;
    _placement = ad?.placement ?? 'hero';
    _targetRole = ad?.targetRole ?? 'all';
    _ctaType = defaultCtaType;
    _status = ad?.status ?? 'active';

    if (!_categories.contains(_category)) _category = _categories.first;
    if (!_placements.contains(_placement)) _placement = _placements.first;
    if (!_targetRoles.contains(_targetRole)) _targetRole = _targetRoles.first;
    if (!_ctaTypes.contains(_ctaType)) _ctaType = _ctaTypes.first;
    if (!_statuses.contains(_status)) _status = _statuses.first;

    _startDate = ad != null && ad.startDate.isNotEmpty
        ? DateTime.tryParse(ad.startDate) ?? DateTime.now()
        : DateTime.now();
    _endDate = ad != null && ad.endDate.isNotEmpty
        ? DateTime.tryParse(ad.endDate) ?? DateTime.now().add(const Duration(days: 30))
        : DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleAmController.dispose();
    _subtitleController.dispose();
    _subtitleAmController.dispose();
    _badgeController.dispose();
    _badgeAmController.dispose();
    _imageUrlController.dispose();
    _ctaTextController.dispose();
    _ctaTextAmController.dispose();
    _ctaTargetController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'title': _titleController.text.trim(),
      'title_am': _titleAmController.text.trim().isNotEmpty ? _titleAmController.text.trim() : null,
      'subtitle': _subtitleController.text.trim().isNotEmpty ? _subtitleController.text.trim() : null,
      'subtitle_am': _subtitleAmController.text.trim().isNotEmpty ? _subtitleAmController.text.trim() : null,
      'badge_text': _badgeController.text.trim().isNotEmpty ? _badgeController.text.trim() : null,
      'badge_text_am': _badgeAmController.text.trim().isNotEmpty ? _badgeAmController.text.trim() : null,
      'image_url': _imageUrlController.text.trim(),
      'category': _category,
      'placement': _placement,
      'target_role': _targetRole,
      'cta_type': _ctaType,
      'cta_text': _ctaTextController.text.trim(),
      'cta_text_am': _ctaTextAmController.text.trim().isNotEmpty ? _ctaTextAmController.text.trim() : null,
      'cta_target': _ctaTargetController.text.trim(),
      'priority': int.tryParse(_priorityController.text.trim()) ?? 10,
      'status': _status,
      'start_date': _startDate.toIso8601String().substring(0, 10),
      'end_date': _endDate.toIso8601String().substring(0, 10),
      if (widget.initialJob != null) 'job_id': widget.initialJob!.id,
    };

    bool success = false;
    if (widget.initialAd != null) {
      final res = await widget.adRepo.updateAdvertisement(widget.initialAd!.id, payload);
      success = res != null;
    } else {
      final res = await widget.adRepo.createAdvertisement(payload);
      success = res != null;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        final errorMsg = widget.adRepo.lastErrorMessage ?? 'Failed to save advertisement campaign. Please check inputs.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteFromDialog() async {
    final ad = widget.initialAd;
    if (ad == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: Text('Are you sure you want to permanently delete "${ad.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSubmitting = true);
      final ok = await widget.adRepo.deleteAdvertisement(ad.id);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${ad.title}"'),
              backgroundColor: const Color(0xFF0D6B4F),
            ),
          );
          Navigator.pop(context, true);
        } else {
          final errorMsg = widget.adRepo.lastErrorMessage ?? 'Failed to delete campaign.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _showLivePreview() {
    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : 'Campaign Title';
    final subtitle = _subtitleController.text.trim();
    final badge = _badgeController.text.trim();
    final image = _imageUrlController.text.trim().isNotEmpty
        ? _imageUrlController.text.trim()
        : 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80';
    final cta = _ctaTextController.text.trim().isNotEmpty ? _ctaTextController.text.trim() : 'Learn More';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.visibility, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Live Banner Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => Container(
                      color: const Color(0xFF0D6B4F),
                      child: const Icon(Icons.campaign, size: 60, color: Colors.white24),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.85),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (badge.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D6B4F),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  badge,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Promoted', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                              ),
                            ],
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                final target = _ctaTargetController.text.trim().isNotEmpty
                                    ? _ctaTargetController.text.trim()
                                    : 'https://example.com';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Preview CTA target: $target')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D6B4F),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(cta, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back to Editing'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialAd != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Advertisement Campaign' : 'Create Advertisement Campaign',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, color: Color(0xFF2563EB)),
                          tooltip: 'Live Preview Banner',
                          onPressed: _showLivePreview,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),

                // Scrollable fields
                Expanded(
                  child: ListView(
                    children: [
                      if (widget.initialJob != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D6B4F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0D6B4F).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.stars, color: Color(0xFF0D6B4F)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Sponsoring Vacancy',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D6B4F), fontSize: 13),
                                    ),
                                    Text(
                                      '${widget.initialJob!.title} • ${widget.initialJob!.location}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // English & Amharic Titles
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Campaign Title (English) *',
                          hintText: 'e.g. Ethiopian Airlines Aviation Academy',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleAmController,
                        decoration: const InputDecoration(
                          labelText: 'Campaign Title (Amharic / አማርኛ)',
                          hintText: 'ምሳሌ፡ የኢትዮጵያ አየር መንገድ የአቪዬሽን አካዳሚ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      TextFormField(
                        controller: _subtitleController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle / Description (English)',
                          hintText: 'Short compelling promotional text',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subtitleAmController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle / Description (Amharic / አማርኛ)',
                          hintText: 'አጭር የማስተዋወቂያ ማብራሪያ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Promotional Badge
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _badgeController,
                              decoration: const InputDecoration(
                                labelText: 'Badge (English)',
                                hintText: 'Featured / 20% Off',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _badgeAmController,
                              decoration: const InputDecoration(
                                labelText: 'Badge (Amharic)',
                                hintText: 'ተመራጭ / ቅናሽ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Image URL & Quick Presets
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Banner Image URL *',
                          hintText: 'https://images.unsplash.com/...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Image URL is required' : null,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '💡 Quick Banner Image Presets (Tap to select):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _imagePresets.entries.map((entry) {
                          final isSelected = _imageUrlController.text == entry.value;
                          return ChoiceChip(
                            label: Text(entry.key, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0D6B4F).withOpacity(0.18),
                            onSelected: (_) {
                              setState(() {
                                _imageUrlController.text = entry.value;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Category & Placement
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _category = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _placement,
                              decoration: const InputDecoration(
                                labelText: 'Placement',
                                border: OutlineInputBorder(),
                              ),
                              items: _placements.map((p) {
                                return DropdownMenuItem(value: p, child: Text(p.replaceAll('_', ' ')));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _placement = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Target Role & Status
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _targetRole,
                              decoration: const InputDecoration(
                                labelText: 'Target Role',
                                border: OutlineInputBorder(),
                              ),
                              items: _targetRoles.map((r) {
                                return DropdownMenuItem(value: r, child: Text(r));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _targetRole = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                              ),
                              items: _statuses.map((s) {
                                return DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _status = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // CTA Type & CTA Target
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _ctaType,
                              decoration: const InputDecoration(
                                labelText: 'CTA Action Type',
                                border: OutlineInputBorder(),
                              ),
                              items: _ctaTypes.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _ctaType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _ctaTargetController,
                              decoration: const InputDecoration(
                                labelText: 'CTA Target (URL or ID) *',
                                hintText: 'https://ethiopianairlines.com',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'CTA Target is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // CTA Text (EN & AM)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ctaTextController,
                              decoration: const InputDecoration(
                                labelText: 'CTA Text (EN) *',
                                hintText: 'Apply Now / View Details',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _ctaTextAmController,
                              decoration: const InputDecoration(
                                labelText: 'CTA Text (AM)',
                                hintText: 'አሁን ያመልክቱ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Priority & Dates
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priorityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Priority (0-100)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isStart: true),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text('Start: ${_startDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickDate(isStart: false),
                              icon: const Icon(Icons.event, size: 16),
                              label: Text('End: ${_endDate.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isEdit)
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _confirmDeleteFromDialog,
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 18),
                        label: const Text('Delete Campaign', style: TextStyle(color: Color(0xFFDC2626))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDC2626)),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(isEdit ? 'Save Changes' : 'Publish Campaign'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
