import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/advertisement_model.dart';
import '../../repositories/advertisement_repository.dart';
import '../advertising/campaign_preview_widget.dart';

class AdminCampaignReviewScreen extends StatefulWidget {
  const AdminCampaignReviewScreen({super.key});

  @override
  State<AdminCampaignReviewScreen> createState() =>
      _AdminCampaignReviewScreenState();
}

class _AdminCampaignReviewScreenState extends State<AdminCampaignReviewScreen> {
  List<AdvertisementModel> _campaigns = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending_approval';

  final List<String> _filters = [
    'pending_approval',
    'approved',
    'active',
    'rejected',
    'paused',
    'all',
  ];

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns({bool isRefresh = false}) async {
    if (!isRefresh && _campaigns.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final repo = Provider.of<AdvertisementRepository>(context, listen: false);
      final list = await repo.getAdminCampaigns(
        approvalStatus: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      if (mounted) {
        setState(() {
          _campaigns = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveCampaign(AdvertisementModel campaign) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Campaign'),
        content: Text(
          'Are you sure you want to approve "${campaign.title}"? The employer will be notified and the campaign will be published according to its schedule and verified payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6B4F),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve Campaign'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final ok = await repo.approveCampaign(campaign.id);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campaign "${campaign.title}" approved!'),
            backgroundColor: const Color(0xFF0D6B4F),
          ),
        );
        _loadCampaigns(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Approval failed.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _rejectCampaign(AdvertisementModel campaign) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Reject Campaign'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide clear administrative notes detailing why this campaign was rejected so the employer can revise it:',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'e.g. Blurry creative banner, misleading headline, or improper destination URL.',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'A reason with at least 5 characters is required.';
                  }
                  return null;
                },
              ),
            ],
          ),
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reject & Notify Employer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final ok = await repo.rejectCampaign(campaign.id, reasonCtrl.text.trim());

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campaign "${campaign.title}" rejected.'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
        _loadCampaigns(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Rejection failed.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showPreviewSheet(AdvertisementModel campaign) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Inspection: ${campaign.title}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CampaignPreviewWidget(campaign: campaign),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaign Approval Center'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final isSelected = f == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        f.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D6B4F),
                      backgroundColor: const Color(0xFFF3F4F6),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = f);
                          _loadCampaigns();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D6B4F)),
      );
    }

    if (_campaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No campaigns found in $_selectedFilter queue.',
              style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCampaigns(isRefresh: true),
      color: const Color(0xFF0D6B4F),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _campaigns.length,
        itemBuilder: (ctx, index) {
          final c = _campaigns[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Organization & Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6B4F).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.employerName ?? 'Verified Organization',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D6B4F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (c.package != null)
                        Text(
                          '${c.package!.name} (${c.package!.displayPrice})',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      const Spacer(),
                      _buildApprovalBadge(c),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Headline
                  Text(
                    c.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (c.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.subtitle!,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF4B5563)),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Target Locations & Dates
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.targetLocations.isNotEmpty
                              ? c.targetLocations.join(', ')
                              : 'All Ethiopia',
                          style: const TextStyle(
                              fontSize: 11.5, color: Color(0xFF4B5563)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.date_range,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${c.startDate.split('T').first} to ${c.endDate.split('T').first}',
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF4B5563)),
                      ),
                      const Spacer(),
                      Text(
                        'Placements: ${c.placements.isNotEmpty ? c.placements.join(', ') : c.placement}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 8),

                  // Action Buttons
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showPreviewSheet(c),
                        icon:
                            const Icon(Icons.remove_red_eye_outlined, size: 15),
                        label: const Text('Inspect Creative'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      if (c.approvalStatus == 'pending_approval') ...[
                        OutlinedButton(
                          onPressed: () => _rejectCampaign(c),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Reject',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _approveCampaign(c),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6B4F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Approve',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ] else if (c.approvalStatus == 'rejected') ...[
                        Text(
                          'Rejected: ${c.rejectionReason ?? ""}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFDC2626)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  Widget _buildApprovalBadge(AdvertisementModel c) {
    Color bg;
    Color fg;
    String label = c.approvalStatus.toUpperCase();

    switch (c.approvalStatus) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'pending_approval':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'PENDING';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
