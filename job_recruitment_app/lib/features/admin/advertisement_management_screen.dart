import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/advertisement_model.dart';
import '../../repositories/advertisement_repository.dart';
import 'advertisement_analytics_screen.dart';
import 'advertisement_form_dialog.dart';

class AdvertisementManagementScreen extends StatefulWidget {
  const AdvertisementManagementScreen({super.key});

  @override
  State<AdvertisementManagementScreen> createState() => _AdvertisementManagementScreenState();
}

class _AdvertisementManagementScreenState extends State<AdvertisementManagementScreen> {
  List<AdvertisementModel> _ads = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedPlacement = 'all';

  final List<String> _statuses = ['all', 'active', 'paused', 'scheduled', 'expired'];
  final List<String> _placements = ['all', 'hero', 'dashboard', 'job_list'];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);

    final statusParam = _selectedStatus == 'all' ? null : _selectedStatus;
    final placementParam = _selectedPlacement == 'all' ? null : _selectedPlacement;

    final ads = await adRepo.getAdminAdvertisements(
      status: statusParam,
      placement: placementParam,
    );

    if (mounted) {
      setState(() {
        _ads = ads;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStatus(AdvertisementModel ad) async {
    final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
    final nextStatus = ad.status == 'active' ? 'paused' : 'active';

    final success = await adRepo.toggleStatus(ad.id, nextStatus);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextStatus == 'active'
                ? 'Campaign "${ad.title}" activated!'
                : 'Campaign "${ad.title}" paused.'),
            backgroundColor: nextStatus == 'active' ? const Color(0xFF0D6B4F) : const Color(0xFFD97706),
          ),
        );
        _loadAds();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update campaign status'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteAd(AdvertisementModel ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign?'),
        content: Text('Are you sure you want to delete "${ad.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
      final ok = await adRepo.deleteAdvertisement(ad.id);
      if (mounted) {
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted campaign "${ad.title}"'),
              backgroundColor: const Color(0xFF0D6B4F),
            ),
          );
          _loadAds();
        } else {
          final errorMsg = adRepo.lastErrorMessage ?? 'Failed to delete campaign. Please check permissions.';
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

  void _openCreateOrEditDialog([AdvertisementModel? ad]) async {
    final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
    final saved = await AdvertisementFormDialog.show(
      context,
      adRepo: adRepo,
      initialAd: ad,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ad == null ? 'Campaign published successfully!' : 'Campaign "${ad.title}" updated successfully!'),
          backgroundColor: const Color(0xFF0D6B4F),
        ),
      );
      _loadAds();
    }
  }

  void _previewCampaign(AdvertisementModel ad) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.visibility_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Campaign Banner Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
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
                        ad.imageUrl,
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
                                if (ad.badgeText != null && ad.badgeText!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D6B4F),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      ad.badgeText!,
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
                                  ad.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (ad.subtitle != null && ad.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    ad.subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Campaign CTA [${ad.ctaType.toUpperCase()}]: ${ad.ctaTarget}'),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0D6B4F),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text(ad.ctaText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text('Placement: ${ad.placement}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.grey.shade100,
                  ),
                  Chip(
                    label: Text('Category: ${ad.category}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.grey.shade100,
                  ),
                  Chip(
                    label: Text('Role: ${ad.targetRole}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.grey.shade100,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAd(ad);
            },
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
            label: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _toggleStatus(ad);
            },
            icon: Icon(
              ad.status == 'active' ? Icons.pause_circle_outline : Icons.play_circle_outline,
              size: 16,
              color: ad.status == 'active' ? const Color(0xFFD97706) : const Color(0xFF0D6B4F),
            ),
            label: Text(
              ad.status == 'active' ? 'Pause' : 'Activate',
              style: TextStyle(
                fontSize: 13,
                color: ad.status == 'active' ? const Color(0xFFD97706) : const Color(0xFF0D6B4F),
              ),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: ad.status == 'active' ? const Color(0xFFD97706) : const Color(0xFF0D6B4F),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openCreateOrEditDialog(ad);
            },
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Campaign', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertisement Campaigns'),
        actions: [
          IconButton(
            tooltip: 'View Analytics Dashboard',
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvertisementAnalyticsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAds,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
        onPressed: () => _openCreateOrEditDialog(),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((status) {
                      final isSelected = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(status.toUpperCase()),
                          onSelected: (_) {
                            setState(() => _selectedStatus = status);
                            _loadAds();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _placements.map((placement) {
                      final isSelected = _selectedPlacement == placement;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text('Placement: $placement'),
                          onSelected: (_) {
                            setState(() => _selectedPlacement = placement);
                            _loadAds();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Ads List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text('No advertisement campaigns found.'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _openCreateOrEditDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Campaign'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAds,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _ads.length,
                          itemBuilder: (context, index) {
                            final ad = _ads[index];
                            return _buildAdCard(ad);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(AdvertisementModel ad) {
    final statusColor = _getStatusColor(ad.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Thumbnail and Details
          ListTile(
            onTap: () => _previewCampaign(ad),
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Image.network(
                  ad.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    ad.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ad.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${ad.category.replaceAll('_', ' ')} • Placement: ${ad.placement}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Schedule: ${ad.startDate.substring(0, 10)} to ${ad.endDate.substring(0, 10)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),

          // Live Metrics Bar (Impressions, Clicks, CTR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricMini('Impressions', '${ad.impressionsCount}'),
                _metricMini('Clicks', '${ad.clicksCount}'),
                _metricMini('CTR', '${ad.ctr}%', isHighlight: true),
                _metricMini('Priority', '${ad.priority}'),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _previewCampaign(ad),
                  icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleStatus(ad),
                  icon: Icon(
                    ad.status == 'active' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 16,
                    color: ad.status == 'active' ? const Color(0xFFD97706) : const Color(0xFF0D6B4F),
                  ),
                  label: Text(
                    ad.status == 'active' ? 'Pause' : 'Activate',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ad.status == 'active' ? const Color(0xFFD97706) : const Color(0xFF0D6B4F),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: ad.status == 'active' ? const Color(0xFFD97706) : const Color(0xFF0D6B4F),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(ad),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0D6B4F)),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D6B4F)),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFF0D6B4F)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteAd(ad),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricMini(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isHighlight ? AppTheme.primaryColor : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'paused':
        return Colors.amber.shade800;
      case 'scheduled':
        return Colors.blue;
      case 'expired':
        return Colors.grey;
      case 'pending_approval':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
