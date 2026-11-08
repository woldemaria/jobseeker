import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/map_service.dart';

class LocationMapModal extends StatefulWidget {
  final String title;
  final String address;
  final String? organizationName;
  final double? latitude;
  final double? longitude;

  const LocationMapModal({
    super.key,
    required this.title,
    required this.address,
    this.organizationName,
    this.latitude,
    this.longitude,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String address,
    String? organizationName,
    double? latitude,
    double? longitude,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationMapModal(
        title: title,
        address: address,
        organizationName: organizationName,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  State<LocationMapModal> createState() => _LocationMapModalState();
}

class _LocationMapModalState extends State<LocationMapModal> {
  late TextEditingController _searchController;
  MapLocationResult? _location;
  PlaceProfile? _placeProfile;
  bool _isLoading = true;
  bool _isSearching = false;
  int _activeTab =
      0; // 0: Google Maps & Place, 1: OpenStreetMap, 2: Place Photo
  int _zoom = 15;
  List<MapLocationResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    final initialQuery =
        widget.organizationName != null && widget.organizationName!.isNotEmpty
        ? '${widget.organizationName}, ${widget.address}'
        : widget.address;
    _searchController = TextEditingController(text: initialQuery);
    _loadLocationAndProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndProfile() async {
    setState(() => _isLoading = true);

    if (widget.latitude != null && widget.longitude != null) {
      _location = MapLocationResult(
        latitude: widget.latitude!,
        longitude: widget.longitude!,
        displayName: widget.address,
      );
    }

    final geocodeFuture = _location != null
        ? Future.value(_location)
        : MapService.geocode(
            widget.address,
            organizationName: widget.organizationName,
          );

    final profileFuture = MapService.getPlaceProfile(
      widget.address,
      organizationName: widget.organizationName,
    );

    final results = await Future.wait([geocodeFuture, profileFuture]);

    if (mounted) {
      setState(() {
        _location = results[0] as MapLocationResult?;
        _placeProfile = results[1] as PlaceProfile?;
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() => _isSearching = true);
    final results = await MapService.searchPlaces(clean);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchResults = results;
        if (results.isNotEmpty) {
          _location = results.first;
          _searchResults = [];
        }
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not find "$clean". Showing closest Ethiopian location.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getOsmTileUrl(double lat, double lon, int zoom) {
    final n = pow(2, zoom).toInt();
    final x = (((lon + 180) / 360) * n).floor();
    final latRad = lat * pi / 180;
    final y = (((1 - (log(tan(latRad) + (1 / cos(latRad))) / pi)) / 2) * n)
        .floor();
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  void _zoomIn() {
    if (_zoom < 18) setState(() => _zoom++);
  }

  void _zoomOut() {
    if (_zoom > 10) setState(() => _zoom--);
  }

  @override
  Widget build(BuildContext context) {
    final double? lat = _location?.latitude;
    final double? lon = _location?.longitude;
    final activeAddress = _location?.displayName ?? widget.address;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with Title & Organization
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D6B4F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF0D6B4F),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.organizationName != null &&
                          widget.organizationName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.organizationName!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0D6B4F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        widget.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar for Finding Exact Places
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText:
                            'Search exact place, building, or landmark...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                      onSubmitted: _performSearch,
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0D6B4F),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Color(0xFF0D6B4F),
                      ),
                      tooltip: 'Locate Exact Place',
                      onPressed: () => _performSearch(_searchController.text),
                    ),
                ],
              ),
            ),

            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (ctx, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = _searchResults[idx];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.pin_drop,
                        size: 16,
                        color: Color(0xFF0D6B4F),
                      ),
                      title: Text(
                        item.displayName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        setState(() {
                          _location = item;
                          _searchController.text = item.displayName;
                          _searchResults = [];
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),

            // View Switcher Tabs: [ Google Maps & Place ] vs [ OpenStreetMap ] vs [ Landmark Photo ]
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Google Maps', Icons.public),
                  _buildTabButton(1, 'OpenStreetMap', Icons.map_outlined),
                  _buildTabButton(
                    2,
                    'Place Photo',
                    Icons.photo_camera_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab 0: Google Maps & Exact Place Card
            if (_activeTab == 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Color(0xFF10B981),
                                size: 13,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Exact Place Verified',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (lat != null && lon != null)
                          Text(
                            'GPS: ${lat.toStringAsFixed(4)}°, ${lon.toStringAsFixed(4)}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      MapService.buildExactPlaceQuery(
                        widget.address,
                        organizationName: widget.organizationName,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeAddress,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),

                    // Primary Google Maps Launch Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          MapService.openGoogleMaps(
                            widget.address,
                            organizationName: widget.organizationName,
                            lat: lat,
                            lon: lon,
                          );
                        },
                        icon: const Icon(
                          Icons.travel_explore,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Find Exact Place on Google Maps',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Turn-by-Turn GPS Directions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          MapService.openDirections(
                            widget.address,
                            organizationName: widget.organizationName,
                            lat: lat,
                            lon: lon,
                          );
                        },
                        icon: const Icon(
                          Icons.directions,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Get Turn-by-Turn Directions',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6B4F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // Tab 1: OpenStreetMap Slippy Tile
            else if (_activeTab == 1) ...[
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  color: const Color(0xFFE2E8F0),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF0D6B4F),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Locating place on OpenStreetMap...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          if (lat != null && lon != null)
                            Positioned.fill(
                              child: Image.network(
                                _getOsmTileUrl(lat, lon, _zoom),
                                fit: BoxFit.cover,
                                headers: const {
                                  'User-Agent':
                                      'JobSeekerEthiopiaRecruitmentApp/1.0',
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(
                                        child: Icon(
                                          Icons.map_outlined,
                                          size: 48,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          // Center Pin
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.address,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFFDC2626),
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                          // Zoom controls
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: _zoomIn,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 1,
                                  width: 30,
                                  color: Colors.grey.shade300,
                                ),
                                InkWell(
                                  onTap: _zoomOut,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(6),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 18,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Open in OSM button overlay
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: InkWell(
                              onTap: () {
                                MapService.openOpenStreetMap(
                                  widget.address,
                                  lat: lat,
                                  lon: lon,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D6B4F),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_in_new,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Open in OSM Web',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ]
            // Tab 2: Specific Landmark Place Photo
            else if (_activeTab == 2) ...[
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  color: const Color(0xFF0F172A),
                ),
                clipBehavior: Clip.antiAlias,
                child: _placeProfile?.imageUrl != null
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              _placeProfile!.imageUrl!,
                              fit: BoxFit.cover,
                              headers: const {
                                'User-Agent':
                                    'JobSeekerEthiopiaRecruitmentApp/1.0',
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: const Color(0xFF1E293B),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 48,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _placeProfile!.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_placeProfile!.description != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _placeProfile!.description!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Place photo not available for this address.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 12),

            // Secondary Quick Actions (Copy Coordinates & Alternative Maps)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final textToCopy = lat != null && lon != null
                          ? '${widget.address} (GPS: $lat, $lon)'
                          : widget.address;
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Address & GPS coordinates copied to clipboard!',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                      size: 14,
                      color: Color(0xFF475569),
                    ),
                    label: const Text(
                      'Copy GPS',
                      style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      MapService.openGoogleMaps(
                        widget.address,
                        organizationName: widget.organizationName,
                        lat: lat,
                        lon: lon,
                      );
                    },
                    icon: const Icon(
                      Icons.open_in_browser,
                      size: 14,
                      color: Color(0xFF1E88E5),
                    ),
                    label: const Text(
                      'Google Maps',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E88E5)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFF90CAF9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      MapService.openOpenStreetMap(
                        widget.address,
                        lat: lat,
                        lon: lon,
                      );
                    },
                    icon: const Icon(
                      Icons.map,
                      size: 14,
                      color: Color(0xFF0D6B4F),
                    ),
                    label: const Text(
                      'OSM Web',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0D6B4F)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFF0D6B4F)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0D6B4F)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
