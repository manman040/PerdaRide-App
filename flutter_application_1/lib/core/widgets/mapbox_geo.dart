import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

extension LatLngMapboxX on LatLng {
  Position toMapboxPosition() => Position(longitude, latitude);

  Point toMapboxPoint() => Point(coordinates: toMapboxPosition());
}

extension LatLngListMapboxX on List<LatLng> {
  LineString toMapboxLineString() =>
      LineString(coordinates: map((point) => point.toMapboxPosition()).toList());
}

extension MapboxPositionX on Position {
  LatLng toLatLng() => LatLng(lat.toDouble(), lng.toDouble());
}

extension MapboxPointX on Point {
  LatLng toLatLng() => coordinates.toLatLng();
}