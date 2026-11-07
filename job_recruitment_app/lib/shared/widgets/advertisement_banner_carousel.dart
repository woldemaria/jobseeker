import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/advertisement_model.dart';
import '../../repositories/advertisement_repository.dart';
import '../../repositories/application_repository.dart';
import '../../repositories/job_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../features/advertising/ad_consent_modal.dart';
import '../../features/jobs/job_details_screen.dart';
import '../../features/authentication/register_screen.dart';

enum BannerLayoutType {
  hero,
  compact,
  inline,
}

class AdvertisementBannerCarousel extends StatefulWidget {
  final String placement;
  final String? category;
  final double? height;
  final bool autoSlide;
  final Duration slideDuration;
  final bool showIndicators;
  final BannerLayoutType layoutType;
  final Function(int jobId)? onJobSelect;
  final Function(int tabIndex)? onNavigateTab;

  const AdvertisementBannerCarousel({
    super.key,
    this.placement = 'hero',
    this.category,
    this.height,
    this.autoSlide = true,
    this.slideDuration = const Duration(seconds: 5),
    this.showIndicators = true,
    this.layoutType = BannerLayoutType.hero,
    this.onJobSelect,
    this.onNavigateTab,
  });

  @override
  State<AdvertisementBannerCarousel> createState() => _AdvertisementBannerCarouselState();
}

class _AdvertisementBannerCarouselState extends State<AdvertisementBannerCarousel> {
  List<AdvertisementModel> _advertisements = [];
  bool _isLoading = true;
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoSlideTimer;
  bool _isPaused = false;
  final Set<int> _recordedImpressions = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadAdvertisements();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAdvertisements() async {
    final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);
    final isPersonalized = storageService.isPersonalizedAdsAllowed();

    try {
      final ads = await adRepo.getAdvertisements(
        placement: widget.placement,
        category: widget.category,
        personalized: isPersonalized,
      );
      if (mounted) {
        setState(() {
          _advertisements = ads;
          _isLoading = false;
        });
        if (ads.isNotEmpty) {
          _recordImpression(ads[0].id);
          _startAutoSlide();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (!widget.autoSlide || _advertisements.length <= 1) return;

    // Check accessibility reduced-motion preference
    final disableAnimations = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
    if (disableAnimations) return;

    _autoSlideTimer = Timer.periodic(widget.slideDuration, (_) {
      if (!_isPaused && mounted && _advertisements.isNotEmpty && _pageController.hasClients) {
        final nextIndex = (_currentIndex + 1) % _advertisements.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _pauseAutoSlide() {
    setState(() => _isPaused = true);
  }

  void _resumeAutoSlide() {
    setState(() => _isPaused = false);
  }

  void _recordImpression(int adId) {
    if (_recordedImpressions.contains(adId)) return;
    _recordedImpressions.add(adId);

    final storageService = Provider.of<StorageService>(context, listen: false);
    if (!storageService.isAnalyticsAllowed()) return;

    final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
    adRepo.recordImpression(adId);
  }

  void _handleBannerClick(AdvertisementModel ad) {
    // Audit click event if analytics consent granted
    final storageService = Provider.of<StorageService>(context, listen: false);
    if (storageService.isAnalyticsAllowed()) {
      final adRepo = Provider.of<AdvertisementRepository>(context, listen: false);
      adRepo.recordClick(ad.id);
    }

    final ctaType = ad.ctaType;
    final target = ad.ctaTarget.trim();

    if (ctaType == 'apply_now' || ctaType == 'view_details') {
      int? jobId = int.tryParse(target);
      if (jobId == null && target.contains('/jobs/')) {
        jobId = int.tryParse(target.split('/jobs/').last.replaceAll(RegExp(r'[^0-9]'), ''));
      }
      if (jobId == null && RegExp(r'\d+').hasMatch(target)) {
        jobId = int.tryParse(RegExp(r'\d+').firstMatch(target)!.group(0)!);
      }

      if (jobId != null) {
        if (widget.onJobSelect != null) {
          widget.onJobSelect!(jobId);
        } else {
          final jobRepo = Provider.of<JobRepository>(context, listen: false);
          final appRepo = Provider.of<ApplicationRepository>(context, listen: false);
          final profRepo = Provider.of<ProfileRepository>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailsScreen(
                jobId: jobId!,
                jobRepo: jobRepo,
                appRepo: appRepo,
                profRepo: profRepo,
              ),
            ),
          );
        }
        return;
      } else if (target == '/jobs' || target == 'jobs') {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(1); // Search tab
        }
        return;
      }
    }

    if (ctaType == 'explore_jobs' || target == '/jobs' || target == 'jobs') {
      if (widget.onNavigateTab != null) {
        widget.onNavigateTab!(1); // Search tab
      }
      return;
    }

    if (ctaType == 'register') {
      final authService = Provider.of<AuthService>(context, listen: false);
      final jobRepo = Provider.of<JobRepository>(context, listen: false);
      final appRepo = Provider.of<ApplicationRepository>(context, listen: false);
      final profRepo = Provider.of<ProfileRepository>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(
            authService: authService,
            jobRepo: jobRepo,
            appRepo: appRepo,
            profRepo: profRepo,
            apiService: apiService,
          ),
        ),
      );
      return;
    }

    // external_link or visit_company
    if (target.isNotEmpty) {
      final uri = Uri.tryParse(target.startsWith('http') ? target : 'https://$target');
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.height ?? _getDefaultHeight(),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_advertisements.isEmpty) {
      return const SizedBox.shrink();
    }

    final languageCode = Localizations.localeOf(context).languageCode;
    final double bannerHeight = widget.height ?? _getDefaultHeight();

    return MouseRegion(
      onEnter: (_) => _pauseAutoSlide(),
      onExit: (_) => _resumeAutoSlide(),
      child: GestureDetector(
        onLongPressStart: (_) => _pauseAutoSlide(),
        onLongPressEnd: (_) => _resumeAutoSlide(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: bannerHeight,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _advertisements.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                      _recordImpression(_advertisements[index].id);
                    },
                    itemBuilder: (context, index) {
                      final ad = _advertisements[index];
                      return _buildBannerCard(ad, languageCode);
                    },
                  ),

                  // Pause indicator badge
                  if (_isPaused)
                    Positioned(
                      top: 10,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause, size: 12, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              'Paused',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Prev/Next Navigation arrows for tablet / web
                  if (_advertisements.length > 1) ...[
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black38,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              if (!_pageController.hasClients) return;
                              final prev = (_currentIndex - 1 + _advertisements.length) % _advertisements.length;
                              if (_currentIndex == 0) {
                                _pageController.jumpToPage(prev);
                              } else {
                                _pageController.animateToPage(
                                  prev,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.chevron_left, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black38,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              if (!_pageController.hasClients) return;
                              final next = (_currentIndex + 1) % _advertisements.length;
                              if (next == 0) {
                                _pageController.jumpToPage(0);
                              } else {
                                _pageController.animateToPage(
                                  next,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.chevron_right, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Dot indicators
            if (widget.showIndicators && _advertisements.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_advertisements.length, (i) {
                  final isActive = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryColor : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _getDefaultHeight() {
    switch (widget.layoutType) {
      case BannerLayoutType.hero:
        return 200.0;
      case BannerLayoutType.compact:
        return 150.0;
      case BannerLayoutType.inline:
        return 125.0;
    }
  }

  Widget _buildBannerCard(AdvertisementModel ad, String languageCode) {
    switch (widget.layoutType) {
      case BannerLayoutType.hero:
        return _buildHeroLayout(ad, languageCode);
      case BannerLayoutType.compact:
        return _buildCompactLayout(ad, languageCode);
      case BannerLayoutType.inline:
        return _buildInlineLayout(ad, languageCode);
    }
  }

  Widget _buildHeroLayout(AdvertisementModel ad, String languageCode) {
    final title = ad.getTitle(languageCode);
    final subtitle = ad.getSubtitle(languageCode);
    final badge = ad.getBadge(languageCode);
    final cta = ad.getCta(languageCode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image with fallback
            Image.network(
              ad.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.campaign, size: 64, color: Colors.white24),
                  ),
                );
              },
            ),

            // High-contrast gradient overlay
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

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(ad.category),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getCategoryIcon(ad.category), size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      // Sponsored tag & Privacy Consent Trigger
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              languageCode == 'am' ? 'ማስታወቂያ' : 'Promoted',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              final storage = Provider.of<StorageService>(context, listen: false);
                              AdConsentModal.show(
                                context,
                                storageService: storage,
                                onConsentUpdated: () => _loadAdvertisements(),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.privacy_tip_outlined, size: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Bottom content & CTA
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () => _handleBannerClick(ad),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                        ),
                        icon: Text(
                          cta,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        label: Icon(
                          _getCtaIcon(ad.ctaType),
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLayout(AdvertisementModel ad, String languageCode) {
    final title = ad.getTitle(languageCode);
    final subtitle = ad.getSubtitle(languageCode);
    final badge = ad.getBadge(languageCode);
    final cta = ad.getCta(languageCode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Left thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: SizedBox(
              width: 120,
              height: double.infinity,
              child: Image.network(
                ad.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  child: const Icon(Icons.campaign, color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(ad.category).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: _getCategoryColor(ad.category),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _handleBannerClick(ad),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cta,
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(_getCtaIcon(ad.ctaType), size: 13, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineLayout(AdvertisementModel ad, String languageCode) {
    final title = ad.getTitle(languageCode);
    final subtitle = ad.getSubtitle(languageCode);
    final cta = ad.getCta(languageCode);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Image.network(
                ad.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  child: const Icon(Icons.campaign, color: AppTheme.primaryColor),
                ),
              ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        languageCode == 'am' ? 'ስፖንሰር' : 'Sponsored',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _handleBannerClick(ad),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(cta, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'featured_jobs':
        return Colors.amber.shade800;
      case 'recruitment_campaigns':
        return Colors.teal.shade700;
      case 'company_promotions':
        return AppTheme.primaryColor;
      case 'sponsored_vacancies':
        return Colors.blueAccent.shade700;
      case 'announcements':
        return Colors.deepPurple.shade600;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'featured_jobs':
        return Icons.star;
      case 'recruitment_campaigns':
        return Icons.groups;
      case 'company_promotions':
        return Icons.business;
      case 'sponsored_vacancies':
        return Icons.workspace_premium;
      case 'announcements':
        return Icons.campaign;
      default:
        return Icons.campaign;
    }
  }

  IconData _getCtaIcon(String ctaType) {
    switch (ctaType) {
      case 'apply_now':
        return Icons.send;
      case 'view_details':
        return Icons.arrow_forward;
      case 'explore_jobs':
        return Icons.travel_explore;
      case 'register':
        return Icons.person_add;
      case 'visit_company':
      case 'external_link':
        return Icons.open_in_new;
      default:
        return Icons.arrow_forward;
    }
  }
}
