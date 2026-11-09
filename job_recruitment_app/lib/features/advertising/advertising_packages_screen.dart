import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/advertising_package_model.dart';
import '../../repositories/advertisement_repository.dart';
import 'campaign_creation_wizard_screen.dart';
import 'package_card_widget.dart';

class AdvertisingPackagesScreen extends StatefulWidget {
  final int? preselectedPackageId;
  final Function(AdvertisingPackageModel package)? onPackageSelected;

  const AdvertisingPackagesScreen({
    super.key,
    this.preselectedPackageId,
    this.onPackageSelected,
  });

  @override
  State<AdvertisingPackagesScreen> createState() =>
      _AdvertisingPackagesScreenState();
}

class _AdvertisingPackagesScreenState extends State<AdvertisingPackagesScreen> {
  List<AdvertisingPackageModel> _packages = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.preselectedPackageId;
    _loadPackages();
  }

  Future<void> _loadPackages({bool isRefresh = false}) async {
    if (!isRefresh && _packages.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final repo = Provider.of<AdvertisementRepository>(context, listen: false);
      final pkgs = await repo.getAdvertisingPackages();

      if (mounted) {
        setState(() {
          _packages = pkgs;
          _isLoading = false;
          if (_selectedId == null && pkgs.isNotEmpty) {
            // Default to popular or first package if selection mode
            final popular = pkgs.firstWhere(
              (p) => p.badgeLabel?.toLowerCase().contains('popular') == true,
              orElse: () => pkgs.first,
            );
            _selectedId = popular.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load advertising packages. Please try again.';
        });
      }
    }
  }

  void _showPlacementInfoSheet(AdvertisingPackageModel pkg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pkg.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Price: ${pkg.displayPrice} for ${pkg.durationText}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0D6B4F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Eligible Advertisement Categories:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pkg.allowedCategories.map((c) {
                  return Chip(
                    label: Text(
                      c.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: const Color(0xFFF3F4F6),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Authorized App Placements:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pkg.allowedPlacements.map((p) {
                  return Chip(
                    avatar: const Icon(Icons.check, size: 14, color: Color(0xFF0D6B4F)),
                    label: Text(
                      p.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: const Color(0xFFECFDF5),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6B4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (widget.onPackageSelected != null) {
                      widget.onPackageSelected!(pkg);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CampaignCreationWizardScreen(
                            preselectedPackageId: pkg.id,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Choose This Package'),
                ),
              ),
            ],
          ),
        );
      },
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
      body: _buildBody(),
      bottomNavigationBar: _packages.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _selectedId != null
                      ? () {
                          final selected = _packages.firstWhere(
                            (p) => p.id == _selectedId,
                            orElse: () => _packages.first,
                          );
                          if (widget.onPackageSelected != null) {
                            widget.onPackageSelected!(selected);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CampaignCreationWizardScreen(
                                  preselectedPackageId: selected.id,
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6B4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.onPackageSelected != null
                        ? 'Continue with Selected Package'
                        : 'Launch Campaign with Selected Package',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0D6B4F)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadPackages(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6B4F),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_packages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No active advertising packages available at the moment.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPackages(isRefresh: true),
      color: const Color(0xFF0D6B4F),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner intro
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D6B4F), Color(0xFF094D38)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.rocket_launch, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Promote Your Hiring & Brand',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Reach thousands of qualified Ethiopian job seekers across Addis Ababa and regional economic hubs with targeted placement packages.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Packages List
          ..._packages.map((pkg) {
            final isSelected = pkg.id == _selectedId;
            return PackageCardWidget(
              package: pkg,
              isSelected: isSelected,
              onSelect: () {
                setState(() => _selectedId = pkg.id);
                if (widget.onPackageSelected != null) {
                  widget.onPackageSelected!(pkg);
                }
              },
              onViewDetails: () => _showPlacementInfoSheet(pkg),
            );
          }),
        ],
      ),
    );
  }
}
