import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/mapbox_config.dart';

class MapboxDirectionsService {
  Future<MapboxRouteResult> getDrivingRouteResult({
    required LatLng from,
    required LatLng to,
  }) async {
    if (!MapboxConfig.hasAccessToken) {
      return MapboxRouteResult.fallback(from, to);
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {
        'geometries': 'polyline',
        'overview': 'full',
        'steps': 'true',
        'access_token': MapboxConfig.accessToken,
      },
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return MapboxRouteResult.fallback(from, to);
      }

      final body = jsonDecode(response.body);
      if (body is! Map || body['code'] != 'Ok') {
        return MapboxRouteResult.fallback(from, to);
      }
      final routes = body['routes'];
      if (routes is! List || routes.isEmpty) {
        return MapboxRouteResult.fallback(from, to);
      }
      final route0 = routes.first;
      if (route0 is! Map) return MapboxRouteResult.fallback(from, to);

      final encodedGeometry = route0['geometry'] as String?;
      final points = encodedGeometry == null
          ? <LatLng>[from, to]
          : _decodePolyline(encodedGeometry);

      final distanceMeters = (route0['distance'] as num?)?.toDouble() ?? 0;
      final durationSeconds = (route0['duration'] as num?)?.toDouble() ?? 0;

      final legs = route0['legs'];
      final steps = <MapboxRouteStep>[];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map) continue;
          final legSteps = leg['steps'];
          if (legSteps is! List) continue;
          for (final step in legSteps) {
            if (step is! Map) continue;
            final stepDistance = (step['distance'] as num?)?.toDouble() ?? 0;
            final maneuver = step['maneuver'];
            final instruction = maneuver is Map
                ? (maneuver['instruction'] ?? '').toString().trim()
                : '';
            steps.add(
              MapboxRouteStep(
                distanceMeters: stepDistance,
                instruction: instruction.isEmpty ? 'Continue' : instruction,
                maneuverType: maneuver is Map
                    ? (maneuver['type'] ?? '').toString()
                    : '',
                maneuverModifier: maneuver is Map
                    ? (maneuver['modifier'] ?? '').toString()
                    : '',
              ),
            );
          }
        }
      }

      if (distanceMeters <= 0) {
        return MapboxRouteResult.fallback(from, to);
      }

      return MapboxRouteResult(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        steps: steps,
      );
    } catch (_) {
      return MapboxRouteResult.fallback(from, to);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class MapboxRouteResult {
  const MapboxRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  factory MapboxRouteResult.fallback(LatLng from, LatLng to) {
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, from, to);
    return MapboxRouteResult(
      points: [from, to],
      distanceMeters: meters,
      durationSeconds: (meters / 1000) / 40 * 3600,
      steps: const [],
    );
  }

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<MapboxRouteStep> steps;

  String get distanceLabel {
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  String get etaLabel {
    final minutes = (durationSeconds / 60).ceil().clamp(1, 999).toInt();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '$hours hr' : '$hours hr $remaining min';
  }

  MapboxRouteStep? get nextStep => steps.isEmpty ? null : steps.first;
}

class MapboxRouteStep {
  const MapboxRouteStep({
    required this.distanceMeters,
    required this.instruction,
    this.maneuverType = '',
    this.maneuverModifier = '',
  });

  final double distanceMeters;
  final String instruction;
  final String maneuverType;
  final String maneuverModifier;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
