import 'package:flutter/material.dart';

import '../../models/advertisement_model.dart';

class CampaignPreviewWidget extends StatefulWidget {
  final AdvertisementModel campaign;
  final String? initialPlacement;
  final bool showPlacementSelector;

  const CampaignPreviewWidget({
    super.key,
    required this.campaign,
    this.initialPlacement,
    this.showPlacementSelector = true,
  });

  @override
  State<CampaignPreviewWidget> createState() => _CampaignPreviewWidgetState();
}

class _CampaignPreviewWidgetState extends State<CampaignPreviewWidget> {
  late String _activePlacement;

  final List<String> _supportedPlacements = [
    'hero',
    'dashboard',
    'job_list',
    'sidebar',
    'search_sponsored',
    'category_specific',
  ];

  @override
  void initState() {
    super.initState();
    _activePlacement = widget.initialPlacement ??
        (widget.campaign.placements.isNotEmpty
            ? widget.campaign.placements.first
            : widget.campaign.placement);
  }

  @override
  void didUpdateWidget(covariant CampaignPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPlacement != null &&
        widget.initialPlacement != _activePlacement) {
      _activePlacement = widget.initialPlacement!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Placement Tab Bar
        if (widget.showPlacementSelector) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _supportedPlacements.map((p) {
                  final isSelected = p == _activePlacement;
                  final isIncludedInPackage = widget.campaign.placements.isEmpty ||
                      widget.campaign.placements.contains(p) ||
                      widget.campaign.placement == p;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        _placementTitle(p),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isIncludedInPackage
                                  ? const Color(0xFF374151)
                                  : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D6B4F),
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _activePlacement = p);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Preview Watermark Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined,
                  size: 14, color: Color(0xFF92400E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Live Preview: Displaying ${_placementTitle(_activePlacement)} rendering simulation.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Rendered Container
        _buildPlacementView(_activePlacement),
      ],
    );
  }

  Widget _buildPlacementView(String placement) {
    switch (placement) {
      case 'hero':
        return _buildHeroPreview();
      case 'dashboard':
        return _buildDashboardPreview();
      case 'sidebar':
        return _buildSidebarPreview();
      case 'search_sponsored':
        return _buildSearchSponsoredPreview();
      case 'category_specific':
        return _buildCategorySpecificPreview();
      case 'job_list':
      default:
        return _buildJobListPreview();
    }
  }

  // 1. Hero Placement Preview
  Widget _buildHeroPreview() {
    final ad = widget.campaign;
    final bgColor = _parseColor(ad.backgroundColor, const Color(0xFF0D6B4F));

    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (ad.imageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                ad.imageUrl,
                fit: BoxFit.cover,
                color: bgColor.withOpacity(0.82),
                colorBlendMode: BlendMode.srcOver,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ad.badgeText?.toUpperCase() ?? 'SPONSORED',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (ad.targetLocations.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              ad.targetLocations.first,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    if (ad.subtitle != null && ad.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ad.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            ad.ctaText,
                            style: TextStyle(
                              color: bgColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: bgColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Dashboard Billboard Preview
  Widget _buildDashboardPreview() {
    final ad = widget.campaign;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ad.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                ad.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 80,
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D6B4F).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ad.badgeText ?? 'PROMOTED RECRUITER',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D6B4F),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text('Billboard',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ad.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                if (ad.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ad.subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {},
                    child: Text(ad.ctaText,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Job List Feed Highlight Preview
  Widget _buildJobListPreview() {
    final ad = widget.campaign;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D6B4F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D6B4F).withOpacity(0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ad.imageUrl.isNotEmpty
                ? Image.network(
                    ad.imageUrl,
                    width: 65,
                    height: 65,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 65,
                      height: 65,
                      color: const Color(0xFFE5E7EB),
                      child: const Icon(Icons.business, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 65,
                    height: 65,
                    color: const Color(0xFFE5E7EB),
                    child: const Icon(Icons.business, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FEATURED VACANCY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ad.category.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ad.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ad.subtitle ?? 'Top verified Ethiopian enterprise opportunity',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (ad.targetLocations.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            ad.targetLocations.first,
                            style: const TextStyle(
                                fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    Text(
                      ad.ctaText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6B4F),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Sidebar Placement Preview
  Widget _buildSidebarPreview() {
    final ad = widget.campaign;

    return Center(
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  ad.badgeText ?? 'SPONSORED',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ad.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  ad.imageUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    color: const Color(0xFFF3F4F6),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              ad.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(30),
                side: const BorderSide(color: Color(0xFF0D6B4F)),
              ),
              onPressed: () {},
              child: Text(
                ad.ctaText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0D6B4F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Sponsored Search Results Preview
  Widget _buildSearchSponsoredPreview() {
    final ad = widget.campaign;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Soft Amber background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'TOP SEARCH SPONSORED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ad.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          if (ad.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              ad.subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Targeting: ${ad.targetLocations.join(', ')}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(80, 32),
                ),
                onPressed: () {},
                child: Text(ad.ctaText,
                    style: const TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Category Specific Placement Preview
  Widget _buildCategorySpecificPreview() {
    final ad = widget.campaign;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 15, color: Color(0xFF0D6B4F)),
              const SizedBox(width: 6),
              Text(
                'CATEGORY RADAR: ${ad.category.replaceAll('_', ' ').toUpperCase()}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D6B4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ad.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          if (ad.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              ad.subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6B4F),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {},
              icon: const Icon(Icons.touch_app, size: 14),
              label: Text(ad.ctaText, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  String _placementTitle(String placement) {
    switch (placement) {
      case 'hero':
        return 'Hero Billboard';
      case 'dashboard':
        return 'Dashboard';
      case 'job_list':
        return 'Job Feed';
      case 'sidebar':
        return 'Sidebar';
      case 'search_sponsored':
        return 'Top Search';
      case 'category_specific':
        return 'Category Radar';
      default:
        return placement.replaceAll('_', ' ');
    }
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}
