import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/advertisement_model.dart';
import '../../repositories/advertisement_repository.dart';
import '../advertising/campaign_creation_wizard_screen.dart';
import '../advertising/campaign_preview_widget.dart';
import '../payment/checkout_screen.dart';
import '../payment/transaction_history_screen.dart';

class EmployerCampaignsScreen extends StatefulWidget {
  const EmployerCampaignsScreen({super.key});

  @override
  State<EmployerCampaignsScreen> createState() =>
      _EmployerCampaignsScreenState();
}

class _EmployerCampaignsScreenState extends State<EmployerCampaignsScreen> {
  List<AdvertisementModel> _campaigns = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  final List<String> _filterTabs = [
    'all',
    'pending_approval',
    'approved',
    'active',
    'draft',
    'paused',
    'rejected',
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
      final list = await repo.getAdvertiserCampaigns(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
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

  Future<void> _submitDraft(AdvertisementModel campaign) async {
    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final ok = await repo.submitCampaign(campaign.id);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign submitted for administrative review!'),
            backgroundColor: Color(0xFF0D6B4F),
          ),
        );
        _loadCampaigns(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Failed to submit campaign.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _pauseCampaign(AdvertisementModel campaign) async {
    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final ok = await repo.pauseCampaign(campaign.id);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign has been paused.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        _loadCampaigns(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(repo.lastErrorMessage ?? 'Failed to pause campaign.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _resumeCampaign(AdvertisementModel campaign) async {
    final repo = Provider.of<AdvertisementRepository>(context, listen: false);
    final ok = await repo.resumeCampaign(campaign.id);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Campaign resumed and is now active!'),
            backgroundColor: Color(0xFF0D6B4F),
          ),
        );
        _loadCampaigns(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              repo.lastErrorMessage ??
                  'Cannot resume campaign: Ensure campaign is approved and payment is verified.',
            ),
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
          initialChildSize: 0.8,
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
                        campaign.title,
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

  void _showRejectionReasonDialog(AdvertisementModel campaign) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.report_problem, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Revision Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your campaign was returned with the following administrative notes:',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                campaign.rejectionReason ?? 'No detailed notes provided.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openWizard(campaignToEdit: campaign);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6B4F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Edit & Fix'),
          ),
        ],
      ),
    );
  }

  void _openWizard({AdvertisementModel? campaignToEdit}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignCreationWizardScreen(
          campaignToEdit: campaignToEdit,
        ),
      ),
    );

    if (result == true) {
      _loadCampaigns(isRefresh: true);
    }
  }

  void _openCheckout(AdvertisementModel campaign) async {
    if (campaign.package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'This campaign has no advertising package attached, so the payable amount is unknown. Please recreate the campaign or contact support.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          campaign: campaign,
          package: campaign.package!,
        ),
      ),
    );

    if (result == true) {
      _loadCampaigns(isRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertising Campaigns'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Payment History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWizard(),
        backgroundColor: const Color(0xFF0D6B4F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
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
                children: _filterTabs.map((tab) {
                  final isSelected = tab == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        tab.replaceAll('_', ' ').toUpperCase(),
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
                          setState(() => _selectedFilter = tab);
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign_outlined, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'No campaigns found in this category.',
                style: TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openWizard(),
                icon: const Icon(Icons.add),
                label: const Text('Create Advertising Campaign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
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
          return _buildCampaignCard(c);
        },
      ),
    );
  }

  Widget _buildCampaignCard(AdvertisementModel campaign) {
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
            // Status and Package Pill
            Row(
              children: [
                _buildStatusBadge(campaign),
                const SizedBox(width: 6),
                _buildPaymentBadge(campaign),
                const SizedBox(width: 8),
                if (campaign.package != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      campaign.package!.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${campaign.impressionsCount} views • ${campaign.clicksCount} clicks',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              campaign.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            if (campaign.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                campaign.subtitle!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),

            // Dates & Placements
            Row(
              children: [
                const Icon(Icons.date_range_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${campaign.startDate.split('T').first} - ${campaign.endDate.split('T').first}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const Spacer(),
                if (campaign.targetLocations.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 13, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        campaign.targetLocations.first,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),

            // Actions Bar
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showPreviewSheet(campaign),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                  label: const Text('Live Preview'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    textStyle: const TextStyle(fontSize: 11.5),
                  ),
                ),
                const Spacer(),
                if (!campaign.isPaid) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _openCheckout(campaign),
                    icon: const Icon(Icons.payment, size: 14),
                    label:
                        const Text('Pay Now', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                ],
                if (campaign.isDraft) ...[
                  TextButton(
                    onPressed: () => _openWizard(campaignToEdit: campaign),
                    child: const Text('Edit Draft',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onPressed: () => _submitDraft(campaign),
                    child: const Text('Submit for Review',
                        style: TextStyle(fontSize: 11.5)),
                  ),
                ] else if (campaign.isRejected) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _showRejectionReasonDialog(campaign),
                    icon: const Icon(Icons.warning_amber_rounded, size: 14),
                    label: const Text('View Reason & Fix',
                        style: TextStyle(fontSize: 11)),
                  ),
                ] else if (campaign.isActive) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFD97706)),
                    ),
                    onPressed: () => _pauseCampaign(campaign),
                    icon: const Icon(Icons.pause, size: 14),
                    label:
                        const Text('Pause', style: TextStyle(fontSize: 11)),
                  ),
                ] else if (campaign.isPaused) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _resumeCampaign(campaign),
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label:
                        const Text('Resume', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(AdvertisementModel campaign) {
    final isPaid = campaign.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPaid ? Colors.green.shade200 : Colors.amber.shade300,
        ),
      ),
      child: Text(
        isPaid ? 'PAID' : 'UNPAID',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPaid ? Colors.green.shade800 : Colors.amber.shade900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AdvertisementModel campaign) {
    Color bg;
    Color fg;
    String label;

    if (campaign.isApproved) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = campaign.isActive ? 'ACTIVE' : 'APPROVED';
    } else if (campaign.isPendingApproval) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = 'UNDER REVIEW';
    } else if (campaign.isRejected) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      label = 'REJECTED';
    } else if (campaign.isPaused) {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
      label = 'PAUSED';
    } else if (campaign.isExpired) {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF6B7280);
      label = 'EXPIRED';
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF4B5563);
      label = 'DRAFT';
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
