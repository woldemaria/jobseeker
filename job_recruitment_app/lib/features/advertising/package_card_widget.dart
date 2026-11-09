import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/advertising_package_model.dart';

class PackageCardWidget extends StatelessWidget {
  final AdvertisingPackageModel package;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback? onViewDetails;

  const PackageCardWidget({
    super.key,
    required this.package,
    this.isSelected = false,
    this.onSelect,
    this.onViewDetails,
  });

  Color _getBadgeColor(String? badge) {
    switch (badge?.toLowerCase()) {
      case 'popular':
        return const Color(0xFFD97706); // Warm Amber
      case 'best value':
        return const Color(0xFF0D6B4F); // Primary Emerald
      case 'fast hire':
        return const Color(0xFF2563EB); // Royal Blue
      case 'enterprise':
        return const Color(0xFF7C3AED); // Deep Purple
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPopular = package.badgeLabel != null &&
        package.badgeLabel!.toLowerCase().contains('popular');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryColor
              : (isPopular ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB)),
          width: isSelected ? 2.5 : (isPopular ? 1.8 : 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.12)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Ribbon
          if (package.badgeLabel != null && package.badgeLabel!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _getBadgeColor(package.badgeLabel),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    package.badgeLabel!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        package.durationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Radio/Select indicator
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (package.badgeLabel == null ||
                              package.badgeLabel!.isEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              package.durationText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onSelect != null)
                      Radio<bool>(
                        value: true,
                        groupValue: isSelected,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (_) => onSelect?.call(),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      package.priceEtb.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D6B4F),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ETB',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6B4F),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ ${package.durationDays} days',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),

                if (package.description != null &&
                    package.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    package.description!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 16),

                // Benefits Checklist
                if (package.benefits.isNotEmpty) ...[
                  const Text(
                    'Package Inclusions:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...package.benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: Color(0xFF0D6B4F),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1F2937),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Allowed Placements Chips
                if (package.allowedPlacements.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: package.allowedPlacements.map((p) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatPlacement(p),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    if (onViewDetails != null)
                      TextButton.icon(
                        onPressed: onViewDetails,
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('Placement Details'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4B5563),
                          textStyle: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    const Spacer(),
                    if (onSelect != null)
                      ElevatedButton(
                        onPressed: onSelect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? const Color(0xFF0D6B4F)
                              : const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isSelected ? 'Selected' : 'Select Package',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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

  String _formatPlacement(String key) {
    switch (key) {
      case 'hero':
        return '★ Top Hero Carousel';
      case 'dashboard':
        return 'Dashboard Billboard';
      case 'job_list':
        return 'Job Feed Highlight';
      case 'sidebar':
        return 'Sidebar Widget';
      case 'search_sponsored':
        return 'Sponsored Search Results';
      case 'category_specific':
        return 'Category Radar';
      default:
        return key.replaceAll('_', ' ');
    }
  }
}
