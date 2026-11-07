import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MapLocationResult {
  final double latitude;
  final double longitude;
  final String displayName;

  const MapLocationResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class PlaceProfile {
  final String name;
  final String? imageUrl;
  final String? description;
  final String? extract;
  final double? latitude;
  final double? longitude;

  const PlaceProfile({
    required this.name,
    this.imageUrl,
    this.description,
    this.extract,
    this.latitude,
    this.longitude,
  });
}

class MapService {
  static final Map<String, MapLocationResult> _cache = {};
  static final Map<String, PlaceProfile> _profileCache = {};

  // Common Ethiopian Subcities, Neighborhoods, and Cities fallback coordinates.
  // CRITICAL: Specific subcities and landmarks MUST appear BEFORE generic city names
  // to prevent 'Addis Ababa' from intercepting Bole, Kazanchis, Piassa, etc.
  static final Map<String, MapLocationResult> _defaultEthiopianCoordinates = {
    // Specific Addis Ababa subcities & landmarks
    'bole medhanialem': const MapLocationResult(latitude: 8.9983, longitude: 38.7861, displayName: 'Bole Medhanialem, Addis Ababa, Ethiopia'),
    'edna mall': const MapLocationResult(latitude: 8.9980, longitude: 38.7850, displayName: 'Edna Mall, Bole, Addis Ababa, Ethiopia'),
    'atlas': const MapLocationResult(latitude: 9.0060, longitude: 38.7840, displayName: 'Atlas, Bole, Addis Ababa, Ethiopia'),
    'bole airport': const MapLocationResult(latitude: 8.9806, longitude: 38.7994, displayName: 'Bole International Airport, Addis Ababa, Ethiopia'),
    'bole': const MapLocationResult(latitude: 8.9950, longitude: 38.7880, displayName: 'Bole, Addis Ababa, Ethiopia'),
    'kazanchis': const MapLocationResult(latitude: 9.0159, longitude: 38.7712, displayName: 'Kazanchis, Kirkos, Addis Ababa, Ethiopia'),
    'uneca': const MapLocationResult(latitude: 9.0160, longitude: 38.7680, displayName: 'UNECA Compound, Kazanchis, Addis Ababa, Ethiopia'),
    'mexico': const MapLocationResult(latitude: 9.0105, longitude: 38.7430, displayName: 'Mexico Square, Lideta, Addis Ababa, Ethiopia'),
    'lideta': const MapLocationResult(latitude: 9.0080, longitude: 38.7400, displayName: 'Lideta, Addis Ababa, Ethiopia'),
    'piassa': const MapLocationResult(latitude: 9.0350, longitude: 38.7520, displayName: 'Piassa, Arada, Addis Ababa, Ethiopia'),
    'arada': const MapLocationResult(latitude: 9.0360, longitude: 38.7510, displayName: 'Arada, Addis Ababa, Ethiopia'),
    'megenagna': const MapLocationResult(latitude: 9.0225, longitude: 38.8020, displayName: 'Megenagna, Yeka, Addis Ababa, Ethiopia'),
    'yeka': const MapLocationResult(latitude: 9.0280, longitude: 38.8100, displayName: 'Yeka, Addis Ababa, Ethiopia'),
    'cmc': const MapLocationResult(latitude: 9.0180, longitude: 38.8520, displayName: 'CMC, Yeka, Addis Ababa, Ethiopia'),
    'ayat': const MapLocationResult(latitude: 9.0250, longitude: 38.8680, displayName: 'Ayat, Yeka, Addis Ababa, Ethiopia'),
    'gerji': const MapLocationResult(latitude: 8.9920, longitude: 38.8150, displayName: 'Gerji, Bole, Addis Ababa, Ethiopia'),
    'gotera': const MapLocationResult(latitude: 9.0010, longitude: 38.7560, displayName: 'Gotera, Kirkos, Addis Ababa, Ethiopia'),
    'kera': const MapLocationResult(latitude: 8.9980, longitude: 38.7510, displayName: 'Kera, Kirkos, Addis Ababa, Ethiopia'),
    'sarbet': const MapLocationResult(latitude: 8.9960, longitude: 38.7360, displayName: 'Sarbet, Kirkos, Addis Ababa, Ethiopia'),
    'old airport': const MapLocationResult(latitude: 8.9900, longitude: 38.7300, displayName: 'Old Airport, Nifas Silk-Lafto, Addis Ababa, Ethiopia'),
    'lebu': const MapLocationResult(latitude: 8.9480, longitude: 38.7180, displayName: 'Lebu, Jemo, Addis Ababa, Ethiopia'),
    'jemo': const MapLocationResult(latitude: 8.9420, longitude: 38.7100, displayName: 'Jemo, Addis Ababa, Ethiopia'),
    'merkato': const MapLocationResult(latitude: 9.0333, longitude: 38.7300, displayName: 'Merkato, Addis Ketema, Addis Ababa, Ethiopia'),
    'addis ketema': const MapLocationResult(latitude: 9.0340, longitude: 38.7310, displayName: 'Addis Ketema, Addis Ababa, Ethiopia'),
    'arat kilo': const MapLocationResult(latitude: 9.0380, longitude: 38.7610, displayName: 'Arat Kilo (4 Kilo), Addis Ababa, Ethiopia'),
    '4 kilo': const MapLocationResult(latitude: 9.0380, longitude: 38.7610, displayName: 'Arat Kilo (4 Kilo), Addis Ababa, Ethiopia'),
    'sidist kilo': const MapLocationResult(latitude: 9.0480, longitude: 38.7610, displayName: 'Sidist Kilo (6 Kilo), Addis Ababa, Ethiopia'),
    '6 kilo': const MapLocationResult(latitude: 9.0480, longitude: 38.7610, displayName: 'Sidist Kilo (6 Kilo), Addis Ababa, Ethiopia'),
    'meskel square': const MapLocationResult(latitude: 9.0105, longitude: 38.7620, displayName: 'Meskel Square, Kirkos, Addis Ababa, Ethiopia'),
    'stadium': const MapLocationResult(latitude: 9.0110, longitude: 38.7580, displayName: 'Addis Ababa Stadium, Kirkos, Addis Ababa, Ethiopia'),
    'kirkos': const MapLocationResult(latitude: 9.0120, longitude: 38.7600, displayName: 'Kirkos Subcity, Addis Ababa, Ethiopia'),
    'akaki kaliti': const MapLocationResult(latitude: 8.8920, longitude: 38.7850, displayName: 'Akaki Kaliti, Addis Ababa, Ethiopia'),
    'kaliti': const MapLocationResult(latitude: 8.8920, longitude: 38.7850, displayName: 'Kaliti, Addis Ababa, Ethiopia'),
    'nifas silk': const MapLocationResult(latitude: 8.9700, longitude: 38.7500, displayName: 'Nifas Silk-Lafto, Addis Ababa, Ethiopia'),
    'lafto': const MapLocationResult(latitude: 8.9700, longitude: 38.7400, displayName: 'Lafto, Addis Ababa, Ethiopia'),
    'kolfe': const MapLocationResult(latitude: 9.0420, longitude: 38.7050, displayName: 'Kolfe Keranio, Addis Ababa, Ethiopia'),
    'gullele': const MapLocationResult(latitude: 9.0720, longitude: 38.7450, displayName: 'Gullele, Addis Ababa, Ethiopia'),
    'shiromeda': const MapLocationResult(latitude: 9.0680, longitude: 38.7550, displayName: 'Shiromeda, Gullele, Addis Ababa, Ethiopia'),
    'entoto': const MapLocationResult(latitude: 9.0880, longitude: 38.7620, displayName: 'Entoto, Addis Ababa, Ethiopia'),
    'torhailoch': const MapLocationResult(latitude: 9.0060, longitude: 38.7220, displayName: 'Torhailoch, Addis Ababa, Ethiopia'),
    'lamberet': const MapLocationResult(latitude: 9.0310, longitude: 38.8190, displayName: 'Lamberet, Yeka, Addis Ababa, Ethiopia'),

    // Regional Ethiopian Cities & Centers
    'hawassa': const MapLocationResult(latitude: 7.0500, longitude: 38.4667, displayName: 'Hawassa, Sidama, Ethiopia'),
    'bahir dar': const MapLocationResult(latitude: 11.5936, longitude: 37.3908, displayName: 'Bahir Dar, Amhara, Ethiopia'),
    'dire dawa': const MapLocationResult(latitude: 9.6000, longitude: 41.8667, displayName: 'Dire Dawa, Ethiopia'),
    'mekelle': const MapLocationResult(latitude: 13.4967, longitude: 39.4753, displayName: 'Mekelle, Tigray, Ethiopia'),
    'adama': const MapLocationResult(latitude: 8.5400, longitude: 39.2700, displayName: 'Adama (Nazret), Oromia, Ethiopia'),
    'nazret': const MapLocationResult(latitude: 8.5400, longitude: 39.2700, displayName: 'Adama (Nazret), Oromia, Ethiopia'),
    'gondar': const MapLocationResult(latitude: 12.6000, longitude: 37.4667, displayName: 'Gondar, Amhara, Ethiopia'),
    'jimma': const MapLocationResult(latitude: 7.6667, longitude: 36.8333, displayName: 'Jimma, Oromia, Ethiopia'),
    'bishoftu': const MapLocationResult(latitude: 8.7500, longitude: 38.9833, displayName: 'Bishoftu (Debre Zeyit), Ethiopia'),
    'debre zeyit': const MapLocationResult(latitude: 8.7500, longitude: 38.9833, displayName: 'Bishoftu (Debre Zeyit), Ethiopia'),
    'dessie': const MapLocationResult(latitude: 11.1300, longitude: 39.6300, displayName: 'Dessie, Wollo, Amhara, Ethiopia'),
    'kombolcha': const MapLocationResult(latitude: 11.0800, longitude: 39.7400, displayName: 'Kombolcha, Wollo, Amhara, Ethiopia'),
    'harar': const MapLocationResult(latitude: 9.3139, longitude: 42.1283, displayName: 'Harar (Jugol), Harari, Ethiopia'),
    'jigjiga': const MapLocationResult(latitude: 9.3500, longitude: 42.8000, displayName: 'Jigjiga, Somali, Ethiopia'),
    'semera': const MapLocationResult(latitude: 11.7936, longitude: 41.0086, displayName: 'Semera, Afar, Ethiopia'),
    'assosa': const MapLocationResult(latitude: 10.0667, longitude: 34.5333, displayName: 'Assosa, Benishangul-Gumuz, Ethiopia'),
    'gambela': const MapLocationResult(latitude: 8.2500, longitude: 34.5833, displayName: 'Gambela, Ethiopia'),
    'debre birhan': const MapLocationResult(latitude: 9.6800, longitude: 39.5300, displayName: 'Debre Birhan, Amhara, Ethiopia'),
    'debre markos': const MapLocationResult(latitude: 10.3300, longitude: 37.7300, displayName: 'Debre Markos, Amhara, Ethiopia'),
    'arba minch': const MapLocationResult(latitude: 6.0333, longitude: 37.5500, displayName: 'Arba Minch, Gamo, Ethiopia'),
    'shashemene': const MapLocationResult(latitude: 7.2000, longitude: 38.6000, displayName: 'Shashemene, Oromia, Ethiopia'),
    'wolaita sodo': const MapLocationResult(latitude: 6.8600, longitude: 37.7600, displayName: 'Wolaita Sodo, Ethiopia'),
    'sodo': const MapLocationResult(latitude: 6.8600, longitude: 37.7600, displayName: 'Wolaita Sodo, Ethiopia'),
    'hosaena': const MapLocationResult(latitude: 7.5500, longitude: 37.8500, displayName: 'Hosaena, Ethiopia'),
    'dilla': const MapLocationResult(latitude: 6.4100, longitude: 38.3100, displayName: 'Dilla, Gedeo, Ethiopia'),
    'nekemte': const MapLocationResult(latitude: 9.0800, longitude: 36.5500, displayName: 'Nekemte, Oromia, Ethiopia'),
    'ambo': const MapLocationResult(latitude: 8.9800, longitude: 37.8500, displayName: 'Ambo, Oromia, Ethiopia'),
    'woldia': const MapLocationResult(latitude: 11.8300, longitude: 39.6000, displayName: 'Woldia, North Wollo, Ethiopia'),
    'axum': const MapLocationResult(latitude: 14.1200, longitude: 38.7200, displayName: 'Axum, Tigray, Ethiopia'),

    // Generic capital city fallbacks (CHECKED LAST)
    'addis ababa': const MapLocationResult(latitude: 9.0300, longitude: 38.7400, displayName: 'Addis Ababa, Ethiopia'),
    'addis abeba': const MapLocationResult(latitude: 9.0300, longitude: 38.7400, displayName: 'Addis Ababa, Ethiopia'),
  };

  // Curated High-Definition Place Profiles with Landmark Images
  static final Map<String, PlaceProfile> _curatedPlaceProfiles = {
    'bole': const PlaceProfile(
      name: 'Bole Subcity, Addis Ababa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Addis_Ababa_Bole_Airport.jpg/640px-Addis_Ababa_Bole_Airport.jpg',
      description: 'Premier business, technology, and corporate district',
      extract: 'Bole is a prominent metropolitan subcity hosting corporate headquarters, embassies, international banks, and enterprise office hubs.',
      latitude: 8.9950,
      longitude: 38.7880,
    ),
    'kazanchis': const PlaceProfile(
      name: 'Kazanchis, Addis Ababa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Addis_in_night.jpg/640px-Addis_in_night.jpg',
      description: 'International business, UN-ECA, and diplomatic sector',
      extract: 'Kazanchis is a vibrant business district located close to the UNECA headquarters, commercial banks, and top hotels.',
      latitude: 9.0190,
      longitude: 38.7720,
    ),
    'hawassa': const PlaceProfile(
      name: 'Hawassa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Awassa%2C_2016.png/640px-Awassa%2C_2016.png',
      description: 'Capital of Sidama Region & Great Rift Valley lake city',
      extract: 'Hawassa is a booming industrial and university hub situated along the shores of scenic Lake Hawassa, hosting the Hawassa Industrial Park.',
      latitude: 7.0500,
      longitude: 38.4667,
    ),
    'bahir dar': const PlaceProfile(
      name: 'Bahir Dar',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Lake_Tana_Bahir_Dar.jpg/640px-Lake_Tana_Bahir_Dar.jpg',
      description: 'Capital of Amhara Region on Lake Tana and Blue Nile',
      extract: 'Bahir Dar is known for its wide palm-lined boulevards, Lake Tana island monasteries, and flourishing commercial enterprises.',
      latitude: 11.5936,
      longitude: 37.3908,
    ),
    'dire dawa': const PlaceProfile(
      name: 'Dire Dawa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/Dire_Dawa_Train_Station.jpg/640px-Dire_Dawa_Train_Station.jpg',
      description: 'Chartered city and eastern trade railway corridor',
      extract: 'Dire Dawa is a historic industrial and commercial crossroad connected by the Ethio-Djibouti Railway.',
      latitude: 9.6000,
      longitude: 41.8667,
    ),
    'gondar': const PlaceProfile(
      name: 'Gondar',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Fasil_Ghebbi_Gondar.jpg/640px-Fasil_Ghebbi_Gondar.jpg',
      description: 'Historic royal capital and UNESCO World Heritage center',
      extract: 'Gondar is famous for the 17th-century Fasil Ghebbi stone castle complex, universities, and regional commerce.',
      latitude: 12.6000,
      longitude: 37.4667,
    ),
    'mekelle': const PlaceProfile(
      name: 'Mekelle',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Mekelle_Yohannes_IV_Palace.jpg/640px-Mekelle_Yohannes_IV_Palace.jpg',
      description: 'Capital and industrial hub of Tigray Region',
      extract: 'Mekelle is a northern commercial, educational, and manufacturing center.',
      latitude: 13.4967,
      longitude: 39.4753,
    ),
    'bishoftu': const PlaceProfile(
      name: 'Bishoftu (Debre Zeyit)',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Lake_Babogaya_Bishoftu.jpg/640px-Lake_Babogaya_Bishoftu.jpg',
      description: 'Crater lake resort city and aviation center',
      extract: 'Bishoftu is renowned for its scenic volcanic crater lakes, aerospace research, and rapid corporate expansion.',
      latitude: 8.7500,
      longitude: 38.9833,
    ),
    'addis ababa': const PlaceProfile(
      name: 'Addis Ababa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Addis_in_night.jpg/640px-Addis_in_night.jpg',
      description: 'Capital and largest financial center of Ethiopia',
      extract: 'Addis Ababa is the diplomatic, financial, and cultural hub of Ethiopia, home to the African Union headquarters and the commercial center of eastern Africa.',
      latitude: 9.0300,
      longitude: 38.7400,
    ),
    'addis abeba': const PlaceProfile(
      name: 'Addis Ababa',
      imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Addis_in_night.jpg/640px-Addis_in_night.jpg',
      description: 'Capital and largest financial center of Ethiopia',
      extract: 'Addis Ababa is the diplomatic, financial, and cultural hub of Ethiopia.',
      latitude: 9.0300,
      longitude: 38.7400,
    ),
  };

  /// Query Nominatim Geocoding API helper
  static Future<MapLocationResult?> _queryNominatim(String query) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'JobSeekerEthiopiaRecruitmentApp/1.0 (contact@jobseeker-ethiopia.et)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final first = list.first;
          final lat = double.tryParse(first['lat'].toString());
          final lon = double.tryParse(first['lon'].toString());
          if (lat != null && lon != null) {
            return MapLocationResult(
              latitude: lat,
              longitude: lon,
              displayName: first['display_name'] ?? query,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Geocode address and organization using live Nominatim API with smart fallback
  static Future<MapLocationResult?> geocode(String address, {String? organizationName}) async {
    final clean = address.trim();
    final cleanOrg = organizationName?.trim();
    if (clean.isEmpty && (cleanOrg == null || cleanOrg.isEmpty)) return null;

    final cacheKey = '${cleanOrg ?? ""}_$clean'.trim();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // 1. Dynamic Attempt: Organization Name + Address (Finds exact building/establishment)
    if (cleanOrg != null && cleanOrg.isNotEmpty) {
      final orgQuery = clean.isNotEmpty && !cleanOrg.toLowerCase().contains(clean.toLowerCase())
          ? '$cleanOrg, $clean, Ethiopia'
          : '$cleanOrg, Ethiopia';
      final orgResult = await _queryNominatim(orgQuery);
      if (orgResult != null) {
        _cache[cacheKey] = orgResult;
        return orgResult;
      }
    }

    // 2. Dynamic Attempt: Full Address with Ethiopia country qualifier
    if (clean.isNotEmpty) {
      final addrQuery = clean.toLowerCase().contains('ethiopia') ? clean : '$clean, Ethiopia';
      final addrResult = await _queryNominatim(addrQuery);
      if (addrResult != null) {
        _cache[cacheKey] = addrResult;
        return addrResult;
      }

      // 3. Dynamic Attempt: First token / subcity
      final parts = clean.split(',');
      if (parts.length > 1) {
        final subPart = parts.first.trim();
        if (subPart.isNotEmpty) {
          final partResult = await _queryNominatim('$subPart, Ethiopia');
          if (partResult != null) {
            _cache[cacheKey] = partResult;
            return partResult;
          }
        }
      }
    }

    // 4. Offline Fallback: Specific subcities and neighborhoods match first!
    final lower = '$clean ${cleanOrg ?? ""}'.toLowerCase();
    for (var key in _defaultEthiopianCoordinates.keys) {
      if (lower.contains(key)) {
        final fallback = _defaultEthiopianCoordinates[key]!;
        _cache[cacheKey] = fallback;
        return fallback;
      }
    }

    // 5. Default fallback to central Addis Ababa
    const defaultRes = MapLocationResult(
      latitude: 9.0300,
      longitude: 38.7400,
      displayName: 'Addis Ababa, Ethiopia',
    );
    _cache[cacheKey] = defaultRes;
    return defaultRes;
  }

  /// Search multiple matching places dynamically for interactive search
  static Future<List<MapLocationResult>> searchPlaces(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final q = clean.toLowerCase().contains('ethiopia') ? clean : '$clean, Ethiopia';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'JobSeekerEthiopiaRecruitmentApp/1.0 (contact@jobseeker-ethiopia.et)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) {
          return MapLocationResult(
            latitude: double.parse(item['lat'].toString()),
            longitude: double.parse(item['lon'].toString()),
            displayName: item['display_name'] ?? clean,
          );
        }).toList();
      }
    } catch (_) {}

    final single = await geocode(query);
    return single != null ? [single] : [];
  }

  /// Fetch specific place profile with real landmark image and summary
  static Future<PlaceProfile> getPlaceProfile(String address, {String? organizationName}) async {
    final clean = address.trim();
    final cleanOrg = organizationName?.trim();
    final combined = '${cleanOrg ?? ""} $clean'.trim();

    if (_profileCache.containsKey(combined)) {
      return _profileCache[combined]!;
    }

    final lower = combined.toLowerCase();

    // Check curated dictionary first
    for (var key in _curatedPlaceProfiles.keys) {
      if (lower.contains(key)) {
        final profile = _curatedPlaceProfiles[key]!;
        _profileCache[combined] = profile;
        return profile;
      }
    }

    // Dynamic query from Wikimedia API
    try {
      final token = clean.split(',').first.trim().replaceAll(' ', '_');
      final uri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(token)}',
      );

      final resp = await http.get(uri, headers: {
        'User-Agent': 'JobSeekerEthiopiaRecruitmentApp/1.0 (contact@jobseeker.et)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final String? imgUrl = data['thumbnail']?['source'] ?? data['originalimage']?['source'];
        if (imgUrl != null && imgUrl.isNotEmpty) {
          final profile = PlaceProfile(
            name: data['title'] ?? clean,
            imageUrl: imgUrl,
            description: data['description'] ?? 'Workplace and regional destination in Ethiopia',
            extract: data['extract'] ?? 'Verified location for employment and workplace opportunities.',
            latitude: data['coordinates'] != null ? double.tryParse(data['coordinates']['lat'].toString()) : null,
            longitude: data['coordinates'] != null ? double.tryParse(data['coordinates']['lon'].toString()) : null,
          );
          _profileCache[combined] = profile;
          return profile;
        }
      }
    } catch (_) {}

    // Fallback to Addis Ababa
    final fallback = _curatedPlaceProfiles['addis ababa']!;
    _profileCache[combined] = fallback;
    return fallback;
  }

  /// Construct exact search query for Google Maps
  static String buildExactPlaceQuery(String address, {String? organizationName}) {
    final cleanAddr = address.trim();
    final cleanOrg = organizationName?.trim();

    if (cleanOrg != null && cleanOrg.isNotEmpty) {
      if (cleanAddr.isNotEmpty && !cleanOrg.toLowerCase().contains(cleanAddr.toLowerCase())) {
        return cleanAddr.toLowerCase().contains('ethiopia')
            ? '$cleanOrg, $cleanAddr'
            : '$cleanOrg, $cleanAddr, Ethiopia';
      }
      return cleanOrg.toLowerCase().contains('ethiopia')
          ? cleanOrg
          : '$cleanOrg, Ethiopia';
    }

    if (cleanAddr.isNotEmpty) {
      return cleanAddr.toLowerCase().contains('ethiopia')
          ? cleanAddr
          : '$cleanAddr, Ethiopia';
    }

    return 'Addis Ababa, Ethiopia';
  }

  /// URL for Google Maps to find the EXACT REAL place
  static String getGoogleMapsUrl(
    String address, {
    String? organizationName,
    double? lat,
    double? lon,
  }) {
    final query = buildExactPlaceQuery(address, organizationName: organizationName);
    if (lat != null && lon != null) {
      return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}&center=$lat,$lon';
    }
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
  }

  /// URL for Google Maps turn-by-turn navigation / directions to the exact place
  static String getGoogleMapsDirectionsUrl(
    String address, {
    String? organizationName,
    double? lat,
    double? lon,
  }) {
    final dest = buildExactPlaceQuery(address, organizationName: organizationName);
    return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(dest)}';
  }

  /// URL for OpenStreetMap web viewer
  static String getOpenStreetMapUrl(String address, {double? lat, double? lon}) {
    if (lat != null && lon != null) {
      return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=16/$lat/$lon';
    }
    return 'https://www.openstreetmap.org/search?query=${Uri.encodeComponent(address)}';
  }

  /// URL for OpenStreetMap turn-by-turn navigation / directions
  static String getOpenStreetMapDirectionsUrl(String address, {double? lat, double? lon}) {
    if (lat != null && lon != null) {
      return 'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=;$lat,$lon';
    }
    return 'https://www.openstreetmap.org/search?query=${Uri.encodeComponent(address)}';
  }

  /// Open Google Maps to find the EXACT place
  static Future<bool> openGoogleMaps(
    String address, {
    String? organizationName,
    double? lat,
    double? lon,
  }) async {
    final url = getGoogleMapsUrl(address, organizationName: organizationName, lat: lat, lon: lon);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Open turn-by-turn navigation / directions in Google Maps
  static Future<bool> openDirections(
    String address, {
    String? organizationName,
    double? lat,
    double? lon,
  }) async {
    final url = getGoogleMapsDirectionsUrl(address, organizationName: organizationName, lat: lat, lon: lon);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Open address in OpenStreetMap
  static Future<bool> openOpenStreetMap(String address, {double? lat, double? lon}) async {
    final url = getOpenStreetMapUrl(address, lat: lat, lon: lon);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Open native geo intent if available, otherwise Google Maps
  static Future<bool> openNativeMap(String address, {String? organizationName, double? lat, double? lon}) async {
    if (lat != null && lon != null) {
      final q = buildExactPlaceQuery(address, organizationName: organizationName);
      final geoUri = Uri.parse('geo:$lat,$lon?q=${Uri.encodeComponent(q)}');
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri);
      }
    }
    return await openGoogleMaps(address, organizationName: organizationName, lat: lat, lon: lon);
  }

  /// Generic URL / Link opener (websites, email, phone)
  static Future<bool> launchExternal(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
