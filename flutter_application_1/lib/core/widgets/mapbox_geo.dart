import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

extension LatLngMapboxX on LatLng {
  mb.Point toMapboxPoint() =>
      mb.Point(coordinates: mb.Position(longitude, latitude));
}

extension MapboxPointX on mb.Point {
  LatLng toLatLng() =>
      LatLng(coordinates.lat.toDouble(), coordinates.lng.toDouble());
}
