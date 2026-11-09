import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/advertisement_model.dart';
import '../../models/advertising_package_model.dart';
import '../../repositories/advertisement_repository.dart';
import 'campaign_preview_widget.dart';
import 'package_card_widget.dart';

class CampaignCreationWizardScreen extends StatefulWidget {
  final AdvertisementModel? campaignToEdit;
  final int? preselectedPackageId;

  const CampaignCreationWizardScreen({
    super.key,
    this.campaignToEdit,
    this.preselectedPackageId,
  });

  @override
  State<CampaignCreationWizardScreen> createState() =>
      _CampaignCreationWizardScreenState();
}

class _CampaignCreationWizardScreenState
    extends State<CampaignCreationWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Data lists from backend APIs
  List<AdvertisingPackageModel> _packages = [];
  List<String> _ethiopianLocations = [];

  // Wizard state & form controllers
  AdvertisingPackageModel? _selectedPackage;

  final _formKeyInfo = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _titleAmCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _subtitleAmCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController(text: 'FEATURED');
  final _ctaTextCtrl = TextEditingController(text: 'Apply Now');
  final _ctaTargetCtrl = TextEditingController(text: '/jobs');
  final _imageUrlCtrl = TextEditingController(
    text:
        'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80',
  );

  String _ctaType = 'apply_now';
  String _category = 'featured_jobs';
  List<String> _selectedPlacements = [];
  List<String> _selectedLocations = ['All Ethiopia'];
  String _targetRole = 'all';

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  final List<String> _ctaOptions = [
    'apply_now',
    'view_details',
    'explore_jobs',
    'register',
    'visit_company',
    'external_link',
  ];

  @override
  void initState() {
    super.initState();
    _initWizard();
  }

  Future<void> _initWizard() async {
    setState(() => _isLoading = true);
    final repo = Provider.of<AdvertisementRepository>(context, listen: false);

    try {
      final pkgs = await repo.getAdvertisingPackages();
      final locData = await repo.getCampaignLocations();

      List<String> locs = ['All Ethiopia', 'Bole', 'Kirkos', 'Yeka', 'Arada', 'Lideta', 'Hawassa', 'Adama', 'Bahir Dar'];
      if (locData != null && locData['all_locations'] is List) {
        locs = (locData['all_locations'] as List).map((e) => e.toString()).toList();
      }

      AdvertisingPackageModel? chosenPkg;
      if (widget.campaignToEdit != null && widget.campaignToEdit!.packageId != null) {
        chosenPkg = pkgs.firstWhere(
          (p) => p.id == widget.campaignToEdit!.packageId,
          orElse: () => pkgs.isNotEmpty ? pkgs.first : throw Exception('No packages'),
        );
      } else if (widget.preselectedPackageId != null) {
        chosenPkg = pkgs.firstWhere(
          (p) => p.id == widget.preselectedPackageId,
          orElse: () => pkgs.isNotEmpty ? pkgs.first : throw Exception('No packages'),
        );
      } else if (pkgs.isNotEmpty) {
        chosenPkg = pkgs.firstWhere(
          (p) => p.badgeLabel?.toLowerCase().contains('popular') == true,
          orElse: () => pkgs.first,
        );
      }

      // Populate if editing draft
      if (widget.campaignToEdit != null) {
        final c = widget.campaignToEdit!;
        _titleCtrl.text = c.title;
        _titleAmCtrl.text = c.titleAm ?? '';
        _subtitleCtrl.text = c.subtitle ?? '';
        _subtitleAmCtrl.text = c.subtitleAm ?? '';
        _descCtrl.text = c.description ?? '';
        _badgeCtrl.text = c.badgeText ?? 'FEATURED';
        _ctaTextCtrl.text = c.ctaText;
        _ctaTargetCtrl.text = c.ctaTarget;
        _imageUrlCtrl.text = c.imageUrl;
        _ctaType = c.ctaType;
        _category = c.category;
        _selectedPlacements = List.from(c.placements.isNotEmpty ? c.placements : [c.placement]);
        _selectedLocations = List.from(c.targetLocations.isNotEmpty ? c.targetLocations : ['All Ethiopia']);
        _targetRole = c.targetRole;

        try {
          _startDate = DateTime.parse(c.startDate);
          _endDate = DateTime.parse(c.endDate);
        } catch (_) {}
      } else if (chosenPkg != null) {
        _category = chosenPkg.allowedCategories.first;
        _selectedPlacements = [chosenPkg.allowedPlacements.first];
        _endDate = _startDate.add(Duration(days: chosenPkg.durationDays - 1));
      }

      if (mounted) {
        setState(() {
          _packages = pkgs;
          _selectedPackage = chosenPkg;
          _ethiopianLocations = locs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPackageSelected(AdvertisingPackageModel pkg) {
    setState(() {
      _selectedPackage = pkg;
      if (!pkg.allowedCategories.contains(_category)) {
        _category = pkg.allowedCategories.first;
      }
      _selectedPlacements = _selectedPlacements
          .where((p) => pkg.allowedPlacements.contains(p))
          .toList();
      if (_selectedPlacements.isEmpty) {
        _selectedPlacements = [pkg.allowedPlacements.first];
      }
      // Re-adjust end date to package duration limit
      final maxEnd = _startDate.add(Duration(days: pkg.durationDays - 1));
      if (_endDate.isAfter(maxEnd) || _endDate.isBefore(_startDate)) {
        _endDate = maxEnd;
      }
    });
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_selectedPackage == null) {
          _showToast('Please select an advertising package to proceed.');
          return false;
        }
        return true;
      case 1:
        if (_titleCtrl.text.trim().isEmpty) {
          _showToast('Campaign Title is required.');
          return false;
        }
        if (_ctaTextCtrl.text.trim().isEmpty || _ctaTargetCtrl.text.trim().isEmpty) {
          _showToast('Call To Action text and target destination are required.');
          return false;
        }
        return true;
      case 2:
        if (_selectedPackage != null &&
            !_selectedPackage!.allowedCategories.contains(_category)) {
          _showToast('Selected category is not allowed by this package.');
          return false;
        }
        return true;
      case 3:
        if (_selectedPlacements.isEmpty) {
          _showToast('Please select at least one authorized app placement.');
          return false;
        }
        return true;
      case 4:
        if (_selectedLocations.isEmpty) {
          _showToast('Please specify at least one geographic target location.');
          return false;
        }
        return true;
      case 5:
        if (_endDate.isBefore(_startDate)) {
          _showToast('End date cannot be prior to start date.');
          return false;
        }
        final days = _endDate.diffInDays(_startDate) + 1;
        if (_selectedPackage != null && days > _selectedPackage!.durationDays) {
          _showToast('Duration exceeds package limit of ${_selectedPackage!.durationDays} days.');
          return false;
        }
        return true;
      case 6:
        if (_imageUrlCtrl.text.trim().isEmpty) {
          _showToast('Please enter an advertisement image banner URL.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < 8) {
        setState(() => _currentStep++);
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitCampaign({required bool isDraft}) async {
    setState(() => _isSubmitting = true);

    final payload = {
      'package_id': _selectedPackage!.id,
      'title': _titleCtrl.text.trim(),
      'title_am': _titleAmCtrl.text.trim().isNotEmpty ? _titleAmCtrl.text.trim() : null,
      'subtitle': _subtitleCtrl.text.trim().isNotEmpty ? _subtitleCtrl.text.trim() : null,
      'subtitle_am': _subtitleAmCtrl.text.trim().isNotEmpty ? _subtitleAmCtrl.text.trim() : null,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'badge_text': _badgeCtrl.text.trim().isNotEmpty ? _badgeCtrl.text.trim() : null,
      'image_url': _imageUrlCtrl.text.trim(),
      'category': _category,
      'placement': _selectedPlacements.isNotEmpty ? _selectedPlacements.first : 'hero',
      'placements': _selectedPlacements,
      'target_role': _targetRole,
      'target_locations': _selectedLocations,
      'cta_type': _ctaType,
      'cta_text': _ctaTextCtrl.text.trim(),
      'cta_target': _ctaTargetCtrl.text.trim(),
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      'is_draft': isDraft,
    };

    final repo = Provider.of<AdvertisementRepository>(context, listen: false);

    AdvertisementModel? result;
    if (widget.campaignToEdit != null) {
      result = await repo.updateCampaign(widget.campaignToEdit!.id, payload);
    } else {
      result = await repo.createCampaign(payload);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result != null) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDraft
                  ? 'Campaign saved as draft successfully!'
                  : 'Campaign submitted for administrative review!',
            ),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
      } else {
        _showToast(repo.lastErrorMessage ?? 'Failed to save campaign.');
      }
    }
  }

  AdvertisementModel _buildCurrentPreviewModel() {
    return AdvertisementModel(
      id: widget.campaignToEdit?.id ?? 0,
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Sample Campaign Headline',
      titleAm: _titleAmCtrl.text.trim().isNotEmpty ? _titleAmCtrl.text.trim() : null,
      subtitle: _subtitleCtrl.text.trim().isNotEmpty
          ? _subtitleCtrl.text.trim()
          : 'Connecting top Ethiopian talent with enterprise opportunities.',
      subtitleAm: _subtitleAmCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      badgeText: _badgeCtrl.text.trim().isNotEmpty ? _badgeCtrl.text.trim() : 'SPONSORED',
      imageUrl: _imageUrlCtrl.text.trim().isNotEmpty
          ? _imageUrlCtrl.text.trim()
          : 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=1200&q=80',
      category: _category,
      placement: _selectedPlacements.isNotEmpty ? _selectedPlacements.first : 'hero',
      placements: _selectedPlacements,
      targetRole: _targetRole,
      targetLocations: _selectedLocations,
      ctaType: _ctaType,
      ctaText: _ctaTextCtrl.text.trim().isNotEmpty ? _ctaTextCtrl.text.trim() : 'Apply Now',
      ctaTarget: _ctaTargetCtrl.text.trim(),
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      status: 'draft',
      approvalStatus: 'draft',
      packageId: _selectedPackage?.id,
      package: _selectedPackage,
      pricePaid: _selectedPackage?.priceEtb ?? 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campaignToEdit != null ? 'Edit Campaign Draft' : 'Create Advertising Campaign'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D6B4F)))
          : Column(
              children: [
                _buildStepProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildCurrentStepContent(),
                  ),
                ),
                _buildBottomNavigationBar(),
              ],
            ),
    );
  }

  Widget _buildStepProgressBar() {
    final stepTitles = [
      'Package',
      'Info',
      'Category',
      'Placements',
      'Targeting',
      'Schedule',
      'Creative',
      'Preview',
      'Submit',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 9: ${stepTitles[_currentStep]}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D6B4F),
                ),
              ),
              if (_selectedPackage != null)
                Text(
                  '${_selectedPackage!.name} (${_selectedPackage!.displayPrice})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 9,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D6B4F)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Package();
      case 1:
        return _buildStep2Info();
      case 2:
        return _buildStep3Category();
      case 3:
        return _buildStep4Placements();
      case 4:
        return _buildStep5Targeting();
      case 5:
        return _buildStep6Schedule();
      case 6:
        return _buildStep7Creative();
      case 7:
        return _buildStep8Preview();
      case 8:
      default:
        return _buildStep9ReviewSubmit();
    }
  }

  // STEP 1: Select Package
  Widget _buildStep1Package() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Advertising Package',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the exposure level and duration that fits your recruitment campaign.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        ..._packages.map((pkg) {
          final isSelected = _selectedPackage?.id == pkg.id;
          return PackageCardWidget(
            package: pkg,
            isSelected: isSelected,
            onSelect: () => _onPackageSelected(pkg),
          );
        }),
      ],
    );
  }

  // STEP 2: Campaign Information
  Widget _buildStep2Info() {
    return Form(
      key: _formKeyInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campaign Headline & Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Campaign Title *',
              hintText: 'e.g. Senior Mobile Engineers Wanted',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleAmCtrl,
            decoration: const InputDecoration(
              labelText: 'Amharic Title (Optional)',
              hintText: 'የከፍተኛ ሞባይል መሐንዲሶች የቅጥር ጥሪ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subtitleCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Subtitle / Value Proposition',
              hintText: 'Competitive salary, modern office in Bole, global projects.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _badgeCtrl,
            decoration: const InputDecoration(
              labelText: 'Badge Ribbon Text',
              hintText: 'SPONSORED, HIRING NOW, URGENT',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Call to Action (CTA) Button Configuration',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _ctaType,
            decoration: const InputDecoration(
              labelText: 'CTA Action Type',
              border: OutlineInputBorder(),
            ),
            items: _ctaOptions.map((opt) {
              return DropdownMenuItem(
                value: opt,
                child: Text(opt.replaceAll('_', ' ').toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _ctaType = val;
                  if (val == 'apply_now') _ctaTextCtrl.text = 'Apply Now';
                  if (val == 'explore_jobs') _ctaTextCtrl.text = 'Explore Jobs';
                  if (val == 'visit_company') _ctaTextCtrl.text = 'Visit Company';
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ctaTextCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Button Label *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ctaTargetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination Route / URL *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 3: Advertisement Category
  Widget _buildStep3Category() {
    final allowed = _selectedPackage?.allowedCategories ?? [
      'featured_jobs',
      'company_promotions',
      'recruitment_campaigns',
      'sponsored_vacancies',
      'announcements',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Advertisement Category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Constrained by ${_selectedPackage?.name ?? "selected package"}.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        ...allowed.map((cat) {
          return RadioListTile<String>(
            title: Text(
              cat.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(_getCategorySubtitle(cat)),
            value: cat,
            groupValue: _category,
            activeColor: const Color(0xFF0D6B4F),
            onChanged: (val) {
              if (val != null) setState(() => _category = val);
            },
          );
        }),
      ],
    );
  }

  String _getCategorySubtitle(String cat) {
    switch (cat) {
      case 'featured_jobs':
        return 'Promote a single or urgent vacancy with gold badge and search priority.';
      case 'company_promotions':
        return 'Highlight your enterprise employer brand and corporate culture.';
      case 'recruitment_campaigns':
        return 'Multi-vacancy graduate drive or high-volume hiring event.';
      case 'sponsored_vacancies':
        return 'Sponsored spot directly inside job feeds and category filters.';
      case 'announcements':
        return 'Corporate news, walk-in interview fairs, or scholarship programs.';
      default:
        return '';
    }
  }

  // STEP 4: Placements Selection
  Widget _buildStep4Placements() {
    final allowed = _selectedPackage?.allowedPlacements ?? ['dashboard', 'job_list'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Authorized App Placements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose where your advertisement will rotate. Allowed by ${_selectedPackage?.name ?? "package"}:',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        ...allowed.map((p) {
          final isChecked = _selectedPlacements.contains(p);
          return CheckboxListTile(
            title: Text(
              _formatPlacementName(p),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(_formatPlacementDesc(p)),
            value: isChecked,
            activeColor: const Color(0xFF0D6B4F),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedPlacements.add(p);
                } else if (_selectedPlacements.length > 1) {
                  _selectedPlacements.remove(p);
                } else {
                  _showToast('At least one placement must remain selected.');
                }
              });
            },
          );
        }),
      ],
    );
  }

  String _formatPlacementName(String p) {
    switch (p) {
      case 'hero':
        return '★ Top Hero Carousel (Billboard)';
      case 'dashboard':
        return 'Dashboard Highlight';
      case 'job_list':
        return 'Job Feed Inline Sponsored';
      case 'sidebar':
        return 'Sidebar Widget';
      case 'search_sponsored':
        return 'Top Search Results';
      case 'category_specific':
        return 'Category Radar';
      default:
        return p;
    }
  }

  String _formatPlacementDesc(String p) {
    switch (p) {
      case 'hero':
        return 'First visual element users see on app open. Maximum brand prestige.';
      case 'dashboard':
        return 'Prominent card displayed on employer and candidate home dashboards.';
      case 'job_list':
        return 'Integrated seamlessly inside the infinite scroll job vacancy list.';
      case 'sidebar':
        return 'Compact high-frequency display across tablet and web layouts.';
      case 'search_sponsored':
        return 'Pinned at the very top of candidate keyword searches.';
      case 'category_specific':
        return 'Displayed when candidates explore specific Ethiopian industry sectors.';
      default:
        return '';
    }
  }

  // STEP 5: Geographic & Audience Targeting
  Widget _buildStep5Targeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ethiopian Geographic Targeting',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select Ethiopian regions, subcities or nationwide targeting:',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),

        // Selected Locations Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedLocations.map((loc) {
            return Chip(
              label: Text(loc),
              backgroundColor: const Color(0xFFECFDF5),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                if (_selectedLocations.length > 1) {
                  setState(() => _selectedLocations.remove(loc));
                } else {
                  _showToast('At least one location target is required.');
                }
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        const Text(
          'Add Location Targets:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _ethiopianLocations.take(20).map((loc) {
            final isAdded = _selectedLocations.contains(loc);
            return ActionChip(
              label: Text(loc, style: const TextStyle(fontSize: 11.5)),
              avatar: Icon(
                isAdded ? Icons.check : Icons.add_location_alt_outlined,
                size: 14,
                color: isAdded ? const Color(0xFF0D6B4F) : Colors.grey,
              ),
              backgroundColor: isAdded ? const Color(0xFFD1FAE5) : Colors.white,
              onPressed: () {
                setState(() {
                  if (isAdded && _selectedLocations.length > 1) {
                    _selectedLocations.remove(loc);
                  } else if (!isAdded) {
                    _selectedLocations.add(loc);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const Text(
          'Audience Role Targeting',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All Users')),
            ButtonSegment(value: 'job_seeker', label: Text('Job Seekers')),
            ButtonSegment(value: 'employer', label: Text('Employers')),
          ],
          selected: {_targetRole},
          onSelectionChanged: (val) {
            setState(() => _targetRole = val.first);
          },
        ),
      ],
    );
  }

  // STEP 6: Campaign Schedule
  Widget _buildStep6Schedule() {
    final maxDays = _selectedPackage?.durationDays ?? 15;
    final currentDuration = _endDate.diffInDays(_startDate) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campaign Schedule & Duration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0D6B4F)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Package limit: Maximum $maxDays days duration for ${_selectedPackage?.name ?? "package"}. Current: $currentDuration days.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          leading: const Icon(Icons.calendar_today, color: Color(0xFF0D6B4F)),
          title: const Text('Campaign Start Date'),
          subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_startDate)),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 180)),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked;
                _endDate = picked.add(Duration(days: maxDays - 1));
              });
            }
          },
        ),
        const SizedBox(height: 12),

        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          leading: const Icon(Icons.event_available, color: Color(0xFF0D6B4F)),
          title: const Text('Campaign End Date'),
          subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_endDate)),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () async {
            final maxEnd = _startDate.add(Duration(days: maxDays - 1));
            final picked = await showDatePicker(
              context: context,
              initialDate: _endDate,
              firstDate: _startDate,
              lastDate: maxEnd,
            );
            if (picked != null) {
              setState(() => _endDate = picked);
            }
          },
        ),
      ],
    );
  }

  // STEP 7: Creative Banner Upload
  Widget _buildStep7Creative() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Advertisement Creative & Banner',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provide a high-resolution 1200x630 or 16:9 banner image for your campaign.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _imageUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'Image Creative URL *',
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Live Thumbnail
        const Text(
          'Image Preview:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _imageUrlCtrl.text.trim(),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 140,
                color: const Color(0xFFF3F4F6),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 36, color: Colors.grey),
                      SizedBox(height: 6),
                      Text('Enter a valid image URL to preview',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // STEP 8: Live Placement Preview
  Widget _buildStep8Preview() {
    final previewAd = _buildCurrentPreviewModel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interactive Placement Previews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Inspect how candidates and employers will view your ad across different screens:',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        CampaignPreviewWidget(campaign: previewAd),
      ],
    );
  }

  // STEP 9: Review & Submit
  Widget _buildStep9ReviewSubmit() {
    final pkg = _selectedPackage!;
    final days = _endDate.diffInDays(_startDate) + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Confirmation',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Package:',
                      style: TextStyle(color: Color(0xFF6B7280))),
                  Text(pkg.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Package Price:',
                      style: TextStyle(color: Color(0xFF6B7280))),
                  Text(
                    pkg.displayPrice,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D6B4F),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Schedule & Duration:',
                      style: TextStyle(color: Color(0xFF6B7280))),
                  Text(
                    '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)} ($days days)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target Locations:',
                      style: TextStyle(color: Color(0xFF6B7280))),
                  Expanded(
                    child: Text(
                      _selectedLocations.join(', '),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Authorized Placements:',
                      style: TextStyle(color: Color(0xFF6B7280))),
                  Expanded(
                    child: Text(
                      _selectedPlacements.join(', ').toUpperCase(),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // Action Submission Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => _submitCampaign(isDraft: true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF4B5563)),
                ),
                child: const Text('Save as Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed:
                    _isSubmitting ? null : () => _submitCampaign(isDraft: false),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit for Approval',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
              )
            else
              const SizedBox.shrink(),
            if (_currentStep < 8)
              ElevatedButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next Step'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension DateTimeDiffExtension on DateTime {
  int diffInDays(DateTime other) {
    final d1 = DateTime(year, month, day);
    final d2 = DateTime(other.year, other.month, other.day);
    return (d1.difference(d2).inHours / 24).round();
  }
}
