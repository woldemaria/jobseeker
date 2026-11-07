import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/advertisement_repository.dart';
import 'advertisement_management_screen.dart';

class AdvertisementAnalyticsScreen extends StatefulWidget {
  const AdvertisementAnalyticsScreen({super.key});

  @override
  State<AdvertisementAnalyticsScreen> createState() => _AdvertisementAnalyticsScreenState();
}

class _AdvertisementAnalyticsScreenState extends State<AdvertisementAnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
    final data = await adRepo.getAnalytics();
    if (mounted) {
      setState(() {
        _analytics = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertising Analytics & CTR'),
        actions: [
          IconButton(
            tooltip: 'Campaigns',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdvertisementManagementScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Could not load advertising metrics'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAnalytics, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildCtrMeter(),
                      const SizedBox(height: 24),
                      _buildCategoryBreakdown(),
                      const SizedBox(height: 24),
                      _buildPlacementBreakdown(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _analytics?['summary'] as Map<String, dynamic>? ?? {};
    final total = summary['total_campaigns'] ?? 0;
    final active = summary['active_campaigns'] ?? 0;
    final impressions = summary['total_impressions'] ?? 0;
    final clicks = summary['total_clicks'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campaign Performance Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricCard('Total Campaigns', '$total', Icons.campaign, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('Active Now', '$active', Icons.check_circle, Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricCard('Total Impressions', '$impressions', Icons.visibility, Colors.purple)),
            const SizedBox(width: 12),
            Expanded(child: _metricCard('Total Clicks', '$clicks', Icons.touch_app, Colors.orange)),
          ],
        ),
      ],
    );
  }

  Widget _buildCtrMeter() {
    final summary = _analytics?['summary'] as Map<String, dynamic>? ?? {};
    final ctr = (summary['overall_ctr'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'Overall Click-Through Rate (CTR)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '$ctr%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (ctr / 20.0).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calculated dynamically as: (Clicks / Impressions) * 100 based on verified ad events.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final list = _analytics?['by_category'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance by Category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Text('No category statistics yet.')
          else
            ...list.map((item) {
              final cat = item['category']?.toString() ?? 'Unknown';
              final count = item['count'] ?? 0;
              final imp = (item['impressions'] as num?)?.toInt() ?? 0;
              final clk = (item['clicks'] as num?)?.toInt() ?? 0;
              final catCtr = imp > 0 ? ((clk / imp) * 100).toStringAsFixed(1) : '0.0';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        cat.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$count ads', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$imp views', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('$clk clicks', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$catCtr% CTR',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPlacementBreakdown() {
    final list = _analytics?['by_placement'] as List? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance by Placement Channel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Text('No placement statistics recorded.')
          else
            ...list.map((item) {
              final placement = item['placement']?.toString() ?? 'General';
              final imp = (item['impressions'] as num?)?.toInt() ?? 0;
              final clk = (item['clicks'] as num?)?.toInt() ?? 0;
              final pCtr = imp > 0 ? ((clk / imp) * 100).toStringAsFixed(1) : '0.0';

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                  child: Icon(_getPlacementIcon(placement), size: 16, color: AppTheme.primaryColor),
                ),
                title: Text(placement.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$imp impressions • $clk clicks'),
                trailing: Text(
                  '$pCtr% CTR',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              );
            }),
        ],
      ),
    );
  }

  IconData _getPlacementIcon(String placement) {
    switch (placement) {
      case 'hero':
        return Icons.view_carousel;
      case 'dashboard':
        return Icons.dashboard;
      case 'job_list':
        return Icons.view_list;
      default:
        return Icons.ad_units;
    }
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
