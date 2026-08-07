import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoutingService {
  Future<List<LatLng>> getDrivingRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final result = await getDrivingRouteResult(from: from, to: to);
    return result.points;
  }

  Future<OsrmRouteResult> getDrivingRouteResult({
    required LatLng from,
    required LatLng to,
  }) async {
    final path =
        '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.https('router.project-osrm.org', path, {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'true',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) return OsrmRouteResult.fallback(from, to);

    final body = jsonDecode(response.body);
    if (body is! Map) return OsrmRouteResult.fallback(from, to);
    final routes = body['routes'];
    if (routes is! List || routes.isEmpty) return OsrmRouteResult.fallback(from, to);
    final route0 = routes.first;
    if (route0 is! Map) return OsrmRouteResult.fallback(from, to);
    final geometry = route0['geometry'];
    if (geometry is! Map) return OsrmRouteResult.fallback(from, to);
    final coords = geometry['coordinates'];
    if (coords is! List || coords.isEmpty) return OsrmRouteResult.fallback(from, to);

    final points = <LatLng>[];
    for (final item in coords) {
      if (item is List && item.length >= 2) {
        final lon = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lat != null && lon != null) {
          points.add(LatLng(lat, lon));
        }
      }
    }
    if (points.isEmpty) return OsrmRouteResult.fallback(from, to);

    final distanceMeters = (route0['distance'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (route0['duration'] as num?)?.toDouble() ?? 0;

    return OsrmRouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      steps: _parseSteps(route0),
    );
  }

  List<OsrmRouteStep> _parseSteps(Map route) {
    final legs = route['legs'];
    if (legs is! List || legs.isEmpty) return const [];
    final steps = <OsrmRouteStep>[];
    for (final leg in legs) {
      if (leg is! Map) continue;
      final rawSteps = leg['steps'];
      if (rawSteps is! List) continue;
      for (final rawStep in rawSteps) {
        if (rawStep is! Map) continue;
        final maneuver = rawStep['maneuver'];
        final name = (rawStep['name'] ?? '').toString().trim();
        final distance = (rawStep['distance'] as num?)?.toDouble() ?? 0;
        final type = maneuver is Map ? (maneuver['type'] ?? '').toString() : '';
        final modifier =
            maneuver is Map ? (maneuver['modifier'] ?? '').toString() : '';
        steps.add(
          OsrmRouteStep(
            roadName: name.isEmpty ? 'Unnamed road' : name,
            distanceMeters: distance,
            instruction: _instruction(type: type, modifier: modifier, road: name),
          ),
        );
      }
    }
    return steps;
  }

  String _instruction({
    required String type,
    required String modifier,
    required String road,
  }) {
    final target = road.trim().isEmpty ? 'the road' : road.trim();
    if (type == 'arrive') return 'Arrive at destination';
    if (type == 'depart') return 'Head onto $target';
    if (type == 'roundabout') return 'Enter roundabout toward $target';
    if (modifier.contains('left')) return 'Turn left onto $target';
    if (modifier.contains('right')) return 'Turn right onto $target';
    if (modifier.contains('straight')) return 'Continue on $target';
    return 'Continue toward $target';
  }
}

class OsrmRouteResult {
  const OsrmRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  factory OsrmRouteResult.fallback(LatLng from, LatLng to) {
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, from, to);
    return OsrmRouteResult(
      points: [from, to],
      distanceMeters: meters,
      durationSeconds: (meters / 1000) / 40 * 3600,
      steps: const [],
    );
  }

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<OsrmRouteStep> steps;

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

  OsrmRouteStep? get nextStep => steps.isEmpty ? null : steps.first;
}

class OsrmRouteStep {
  const OsrmRouteStep({
    required this.roadName,
    required this.distanceMeters,
    required this.instruction,
  });

  final String roadName;
  final double distanceMeters;
  final String instruction;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
