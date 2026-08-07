import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingPlace {
  GeocodingPlace({
    required this.name,
    required this.point,
  });

  final String name;
  final LatLng point;
}

class NominatimGeocodingService {
  static const _base = 'nominatim.openstreetmap.org';
  static const _headers = <String, String>{
    'User-Agent': 'PerdaRide/1.0 (Flutter App)',
    'Accept': 'application/json',
  };

  Future<GeocodingPlace?> searchFirst(String query) async {
    final uri = Uri.https(_base, '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '1',
      'addressdetails': '1',
      'countrycodes': 'my',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty) return null;

    final first = body.first;
    if (first is! Map) return null;

    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    final displayName = first['display_name']?.toString().trim();
    return GeocodingPlace(
      name: (displayName == null || displayName.isEmpty)
          ? query
          : displayName,
      point: LatLng(lat, lon),
    );
  }

  Future<String?> reverse(LatLng point) async {
    final uri = Uri.https(_base, '/reverse', {
      'lat': point.latitude.toString(),
      'lon': point.longitude.toString(),
      'format': 'jsonv2',
      'zoom': '18',
      'addressdetails': '1',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map) return null;

    final displayName = body['display_name']?.toString().trim();
    if (displayName == null || displayName.isEmpty) return null;
    return displayName;
  }
}
