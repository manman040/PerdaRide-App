import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'mapbox_geo.dart';

@immutable
class PerdaMapMarker {
  const PerdaMapMarker({
    required this.id,
    required this.point,
    required this.color,
  });

  final String id;
  final LatLng point;
  final Color color;
}

@immutable
class PerdaMapPolyline {
  const PerdaMapPolyline({
    required this.id,
    required this.points,
    required this.color,
    this.width = 4,
  });

  final String id;
  final List<LatLng> points;
  final Color color;
  final double width;
}

class PerdaMapController {
  PerdaMapController._(this._map);

  final mb.MapboxMap _map;

  Future<void> animateCamera(LatLng target, double zoom) {
    return _map.flyTo(
      mb.CameraOptions(center: target.toMapboxPoint(), zoom: zoom),
      mb.MapAnimationOptions(duration: 650),
    );
  }
}

/// A thin wrapper around Mapbox's [mb.MapWidget] that mirrors the small
/// subset of the old `google_maps_flutter` `GoogleMap` API this app used:
/// a fixed initial camera plus a declarative list of colored markers and
/// polylines that get resynced whenever they change.
///
/// Deliberately left on the plain default Android platform-view hosting
/// mode (Virtual Display) -- see the comment on the `MapWidget` build below
/// before changing `androidHostingMode`/`textureView`. VD is the
/// most-thoroughly-verified-freeze-resistant option on this project's
/// Android target; its one confirmed downside (Flutter widgets stacked
/// directly on top of the map don't receive touches) no longer applies
/// anywhere in this codebase -- every screen keeps interactive controls in
/// regions that don't spatially overlap a [PerdaMapView]. Keep it that way
/// rather than reaching for a different hosting mode.
class PerdaMapView extends StatefulWidget {
  const PerdaMapView({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    this.markers = const [],
    this.polylines = const [],
    this.onMapCreated,
    this.onTap,
  });

  final LatLng initialCenter;
  final double initialZoom;
  final List<PerdaMapMarker> markers;
  final List<PerdaMapPolyline> polylines;
  final ValueChanged<PerdaMapController>? onMapCreated;
  final ValueChanged<LatLng>? onTap;

  @override
  State<PerdaMapView> createState() => _PerdaMapViewState();
}

class _PerdaMapViewState extends State<PerdaMapView> {
  mb.CircleAnnotationManager? _circleManager;
  mb.PolylineAnnotationManager? _polylineManager;

  @override
  void didUpdateWidget(covariant PerdaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnnotations();
  }

  @override
  Widget build(BuildContext context) {
    return mb.MapWidget(
      // No androidHostingMode/textureView override -- see the class
      // docstring above. Hybrid Composition was tried here and caused a
      // complete, silent freeze reproduced without a debugger attached
      // (zero log output, no ANR trigger). TLHC avoided that freeze but
      // still had VD's overlay-touch problem. VD itself is the option most
      // thoroughly verified freeze-resistant in real, extended,
      // non-debugger use; its overlay-touch limitation is now a non-issue
      // since no screen stacks interactive widgets on top of the map.
      cameraOptions: mb.CameraOptions(
        center: widget.initialCenter.toMapboxPoint(),
        zoom: widget.initialZoom,
      ),
      onMapCreated: _onMapCreated,
      onTapListener: widget.onTap == null ? null : _onTap,
    );
  }

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    final circleManager = await map.annotations.createCircleAnnotationManager();
    final polylineManager =
        await map.annotations.createPolylineAnnotationManager();
    if (!mounted) {
      return;
    }
    _circleManager = circleManager;
    _polylineManager = polylineManager;
    await _syncAnnotations();
    widget.onMapCreated?.call(PerdaMapController._(map));
  }

  void _onTap(mb.MapContentGestureContext context) {
    widget.onTap?.call(context.point.toLatLng());
  }

  Future<void> _syncAnnotations() async {
    final circleManager = _circleManager;
    final polylineManager = _polylineManager;
    if (circleManager == null || polylineManager == null) {
      return;
    }

    await polylineManager.deleteAll();
    for (final polyline in widget.polylines) {
      await polylineManager.create(
        mb.PolylineAnnotationOptions(
          geometry: mb.LineString(
            coordinates: polyline.points
                .map((point) => mb.Position(point.longitude, point.latitude))
                .toList(),
          ),
          lineColor: polyline.color.toARGB32(),
          lineWidth: polyline.width,
        ),
      );
    }

    await circleManager.deleteAll();
    for (final marker in widget.markers) {
      await circleManager.create(
        mb.CircleAnnotationOptions(
          geometry: marker.point.toMapboxPoint(),
          circleColor: marker.color.toARGB32(),
          circleRadius: 9,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.5,
        ),
      );
    }
  }
}