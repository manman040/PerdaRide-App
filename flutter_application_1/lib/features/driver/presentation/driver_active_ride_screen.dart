import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/notifications/ride_notification_service.dart';
import '../../../core/services/mapbox_directions_service.dart';
import '../../../core/widgets/booking_chat_sheet.dart';
import '../../../core/widgets/perda_map_view.dart';
import '../../booking/data/booking_repository.dart';
import '../data/driver_ride_stage.dart';

class DriverActiveRideScreen extends StatefulWidget {
  const DriverActiveRideScreen({
    super.key,
    required this.bookingId,
    required this.pickupPoint,
    required this.pickupLabel,
    required this.dropoffPoint,
    required this.dropoffLabel,
    required this.paymentMethod,
    required this.packageLabel,
    required this.priceLabel,
    required this.initialDistanceLabel,
  });

  final String bookingId;
  final LatLng pickupPoint;
  final String pickupLabel;
  final LatLng dropoffPoint;
  final String dropoffLabel;
  final String paymentMethod;
  final String packageLabel;
  final String priceLabel;
  final String initialDistanceLabel;

  @override
  State<DriverActiveRideScreen> createState() =>
      _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  static const _navBlue = Color(0xFF2E90E5);

  final _bookingRepository = BookingRepository();
  final _routingService = MapboxDirectionsService();
  final _firebase = PerdaRideFirebase.instance;
  late final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(
    _firebase,
  );
  late final FirebaseDatabaseRepository _databaseRepository =
      FirebaseDatabaseRepository(_firebase);

  final _tts = FlutterTts();
  LatLng? _driverPoint;
  double _driverBearing = 0;
  DriverRideStage _rideStage = DriverRideStage.accepted;
  String _statusText = 'Heading to passenger pickup';
  late String _distanceText = widget.initialDistanceLabel;
  MapboxRouteResult? _routeResult;
  bool _isVoiceNavigationOn = false;
  bool _isMuted = false;
  String? _lastSpokenInstruction;
  PerdaMapController? _navMapController;
  StreamSubscription<DatabaseEvent>? _driverLocationSubscription;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _listenDriverLocation();
    _detectInitialLocation();
  }

  /// Seeds [_driverPoint] with a direct GPS fix instead of waiting on the
  /// Firebase relay from [DriverDashboardScreen], which only republishes
  /// every 5s (and only once the driver has moved 8m), so it can otherwise
  /// leave this screen without a location for a while right after opening.
  Future<void> _detectInitialLocation() async {
    if (_driverPoint != null) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted || _driverPoint != null) return;
      setState(() {
        _driverPoint = LatLng(position.latitude, position.longitude);
      });
      _refreshNavigationRoute();
    } catch (_) {}
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _listenDriverLocation() {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return;
    _driverLocationSubscription = _databaseRepository
        .watchPath('driver_locations/$uid')
        .listen((event) {
          final value = event.snapshot.value;
          if (value is! Map) return;

          final lat = _toDouble(value['lat']);
          final lng = _toDouble(value['lng']);
          if (lat == null || lng == null) return;

          final point = LatLng(lat, lng);
          final previous = _driverPoint;
          if (!mounted) return;
          setState(() {
            if (previous != null && previous != point) {
              _driverBearing = const Distance().bearing(previous, point);
            }
            _driverPoint = point;
          });

          if (_isVoiceNavigationOn) {
            unawaited(_navMapController?.animateCamera(point, 17.5));
          }

          if (_rideStage == DriverRideStage.accepted ||
              _rideStage == DriverRideStage.arrivedPickup ||
              _rideStage == DriverRideStage.inProgress) {
            _refreshNavigationRoute();
          }
        });
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  LatLng get _navDestinationPoint => _rideStage == DriverRideStage.inProgress
      ? widget.dropoffPoint
      : widget.pickupPoint;

  String get _navDestinationLabel => _rideStage == DriverRideStage.inProgress
      ? widget.dropoffLabel
      : widget.pickupLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isVoiceNavigationOn
          ? _navigationView()
          : SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 220, child: _pickupPreviewMap()),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      child: _rideProgressCard(context),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _rideProgressCard(BuildContext context) {
    final stageMeta = switch (_rideStage) {
      DriverRideStage.accepted => (
        label: 'ACCEPTED',
        color: const Color(0xFF2E90E5),
        primaryAction: 'Arrived',
      ),
      DriverRideStage.arrivedPickup => (
        label: 'ARRIVED PICKUP',
        color: const Color(0xFFF09A1A),
        primaryAction: 'Start Ride',
      ),
      DriverRideStage.inProgress => (
        label: 'IN PROGRESS',
        color: const Color(0xFF8E44AD),
        primaryAction: 'Complete Ride',
      ),
      DriverRideStage.completed => (
        label: 'COMPLETED',
        color: const Color(0xFF2E7D32),
        primaryAction: 'Done',
      ),
      DriverRideStage.idle => (
        label: '',
        color: const Color(0xFF2E7D32),
        primaryAction: '',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _statusText,
          style: const TextStyle(
            color: Color(0xFF454545),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7DED3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stageMeta.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    stageMeta.label,
                    style: TextStyle(
                      color: stageMeta.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _rideAddress(
                icon: Icons.trip_origin_rounded,
                color: const Color(0xFF2E7D32),
                value: widget.pickupLabel,
              ),
              const SizedBox(height: 8),
              _rideAddress(
                icon: Icons.place_rounded,
                color: const Color(0xFFD84315),
                value: widget.dropoffLabel,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.packageLabel} | Fare: ${widget.priceLabel} | '
                  '${widget.paymentMethod} | $_distanceText',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_rideStage == DriverRideStage.accepted ||
                  _rideStage == DriverRideStage.arrivedPickup ||
                  _rideStage == DriverRideStage.inProgress) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(
                      _rideStage == DriverRideStage.inProgress
                          ? 'Navigate to Drop-off'
                          : 'Navigate to Passenger',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_rideStage == DriverRideStage.completed) {
                      Navigator.of(context).pop();
                      return;
                    }

                    setState(() {
                      if (_rideStage == DriverRideStage.accepted) {
                        _rideStage = DriverRideStage.arrivedPickup;
                        _statusText = 'Driver arrived at pickup';
                      } else if (_rideStage ==
                          DriverRideStage.arrivedPickup) {
                        _rideStage = DriverRideStage.inProgress;
                        _statusText = 'Ride in progress';
                      } else if (_rideStage == DriverRideStage.inProgress) {
                        _rideStage = DriverRideStage.completed;
                        _statusText = 'Ride completed';
                      }
                    });
                    if (_rideStage == DriverRideStage.inProgress) {
                      await _refreshNavigationRoute();
                    }
                    if (_rideStage == DriverRideStage.completed) {
                      _endNavigation();
                    }
                    final status = switch (_rideStage) {
                      DriverRideStage.arrivedPickup => 'arrived_pickup',
                      DriverRideStage.inProgress => 'in_progress',
                      DriverRideStage.completed => 'completed',
                      _ => null,
                    };
                    if (status != null) {
                      await _bookingRepository.updateBookingStatus(
                        bookingId: widget.bookingId,
                        status: status,
                      );
                      final riderMessage = switch (status) {
                        'arrived_pickup' => (
                          title: 'Driver has arrived',
                          body: 'Your driver is waiting at the pickup point.',
                        ),
                        'in_progress' => (
                          title: 'Your ride has started',
                          body: 'Enjoy your trip!',
                        ),
                        'completed' => (
                          title: 'Ride completed',
                          body: 'Please rate your driver.',
                        ),
                        _ => null,
                      };
                      if (riderMessage != null) {
                        unawaited(
                          _notifyRider(
                            title: riderMessage.title,
                            body: riderMessage.body,
                          ),
                        );
                      }
                      if (status == 'completed') {
                        final driverId = _authRepository.currentUser?.uid;
                        if (driverId != null) {
                          unawaited(_ensurePaymentDeadline(driverId));
                        }
                      }
                    }
                  },
                  child: Text(stageMeta.primaryAction),
                ),
              ),
              const SizedBox(height: 8),
              if (_rideStage != DriverRideStage.completed)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelRide,
                    child: const Text('Cancel Ride'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => showBookingChatSheet(
                    context,
                    bookingRepository: _bookingRepository,
                    bookingId: widget.bookingId,
                    currentUserRole: 'driver',
                  ),
                  child: const Text('Chat with Passenger'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rideAddress({
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF3F3F3F), height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _pickupPreviewMap() {
    final driverPoint = _driverPoint;
    if (driverPoint == null) {
      return Container(
        color: const Color(0xFFF5F2EE),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    final destination = _navDestinationPoint;
    return PerdaMapView(
      key: const ValueKey('driver-ride-preview-map'),
      initialCenter: LatLng(
        (driverPoint.latitude + destination.latitude) / 2,
        (driverPoint.longitude + destination.longitude) / 2,
      ),
      initialZoom: 13,
      markers: [
        PerdaMapMarker(
          id: 'driver',
          point: driverPoint,
          color: const Color(0xFF1E88E5),
        ),
        PerdaMapMarker(
          id: 'destination',
          point: destination,
          color: _rideStage == DriverRideStage.inProgress
              ? const Color(0xFFD32F2F)
              : const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  Widget _navigationView() {
    final driverPoint = _driverPoint;
    if (driverPoint == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final destination = _navDestinationPoint;
    final route = _routeResult;
    final routePoints = route != null && route.points.length > 1
        ? route.points
        : [driverPoint, destination];

    return Stack(
      children: [
        PerdaMapView(
          key: const ValueKey('driver-navigation-map'),
          initialCenter: driverPoint,
          initialZoom: 17.5,
          onMapCreated: (controller) => _navMapController = controller,
          markers: [
            PerdaMapMarker(
              id: 'destination',
              point: destination,
              color: const Color(0xFFD32F2F),
            ),
          ],
          polylines: [
            PerdaMapPolyline(
              id: 'nav-route',
              points: routePoints,
              color: _navBlue,
              width: 5,
            ),
          ],
        ),
        IgnorePointer(
          child: Center(
            child: Transform.rotate(
              angle: _driverBearing * math.pi / 180,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _navBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _instructionBanner(),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 210,
          child: _recenterButton(),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(top: false, child: _navigationBottomSheet()),
        ),
      ],
    );
  }

  Widget _instructionBanner() {
    final steps = _routeResult?.steps ?? const <MapboxRouteStep>[];
    final step = steps.isEmpty ? null : steps.first;
    final afterNext = steps.length > 1 ? steps[1] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: _navBlue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _maneuverIcon(step?.maneuverType, step?.maneuverModifier),
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step?.distanceLabel ?? '--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      step?.instruction ?? 'Finding your route...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isMuted = !_isMuted),
                icon: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (afterNext != null) ...[
            const Divider(color: Colors.white24, height: 18),
            Row(
              children: [
                const Text(
                  'Then',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _maneuverIcon(
                    afterNext.maneuverType,
                    afterNext.maneuverModifier,
                  ),
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    afterNext.instruction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _maneuverIcon(String? type, String? modifier) {
    switch (type) {
      case 'arrive':
        return Icons.flag_rounded;
      case 'depart':
        return Icons.navigation_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_left_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'fork':
        return modifier == 'left'
            ? Icons.fork_left_rounded
            : Icons.fork_right_rounded;
    }
    switch (modifier) {
      case 'left':
        return Icons.turn_left_rounded;
      case 'right':
        return Icons.turn_right_rounded;
      case 'sharp left':
        return Icons.turn_sharp_left_rounded;
      case 'sharp right':
        return Icons.turn_sharp_right_rounded;
      case 'slight left':
        return Icons.turn_slight_left_rounded;
      case 'slight right':
        return Icons.turn_slight_right_rounded;
      case 'uturn':
        return Icons.u_turn_left_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  Widget _recenterButton() {
    return Material(
      color: _navBlue,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          final point = _driverPoint;
          if (point != null) {
            _navMapController?.animateCamera(point, 17.5);
          }
        },
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _navigationBottomSheet() {
    final route = _routeResult;
    final arrival = route == null
        ? null
        : DateTime.now().add(Duration(seconds: route.durationSeconds.round()));
    final arrivalLabel = arrival == null
        ? '--:--'
        : '${arrival.hour.toString().padLeft(2, '0')}:'
              '${arrival.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To $_navDestinationLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B6B6B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                route?.etaLabel ?? '-- min',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF202020),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                route?.distanceLabel ?? '-- km',
                style: const TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'arrive ~$arrivalLabel',
                style: const TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _endNavigation,
                  child: const Text('End Navigation'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _openExternalNavigation,
                child: const Text('Open Maps'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide() async {
    await _bookingRepository.updateBookingStatus(
      bookingId: widget.bookingId,
      status: 'cancelled',
    );
    unawaited(
      _notifyRider(
        title: 'Ride cancelled',
        body: 'Your driver cancelled the ride.',
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _notifyRider({
    required String title,
    required String body,
  }) async {
    try {
      final snapshot = await _databaseRepository.getData(
        'bookings/${widget.bookingId}',
      );
      final value = snapshot.value;
      if (value is! Map) return;
      final userId = (value['userId'] ?? '').toString();
      if (userId.isEmpty) return;
      await RideNotificationService.instance.notify(
        uid: userId,
        isDriver: false,
        title: title,
        body: body,
        bookingId: widget.bookingId,
      );
    } catch (_) {}
  }

  Future<void> _ensurePaymentDeadline(String driverId) async {
    try {
      final existing = await _databaseRepository.getData(
        'driver_commissions/$driverId/payment_deadline',
      );
      if (existing.value != null) return;
      final deadline = DateTime.now().add(const Duration(hours: 24));
      await _databaseRepository.updateData('driver_commissions/$driverId', {
        'payment_deadline': {
          'time': deadline.millisecondsSinceEpoch,
          'date': deadline.toIso8601String(),
          'set_by': 'auto',
          'set_at': DateTime.now().millisecondsSinceEpoch,
        },
      });
    } catch (_) {}
  }

  Future<void> _refreshNavigationRoute() async {
    final driverPoint = _driverPoint;
    if (driverPoint == null) return;

    final to = _navDestinationPoint;

    late final MapboxRouteResult result;
    try {
      result = await _routingService.getDrivingRouteResult(
        from: driverPoint,
        to: to,
      );
    } catch (_) {
      result = MapboxRouteResult.fallback(driverPoint, to);
    }
    if (!mounted) return;
    setState(() {
      _distanceText = result.distanceLabel;
      _routeResult = result;
    });

    if (_isVoiceNavigationOn && !_isMuted) {
      final next = result.nextStep;
      if (next != null && next.instruction != _lastSpokenInstruction) {
        _lastSpokenInstruction = next.instruction;
        await _tts.speak('${next.instruction}. In ${next.distanceLabel}.');
      }
    }
  }

  Future<void> _startNavigation() async {
    if (_driverPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for current location.')),
      );
      return;
    }

    setState(() {
      _isVoiceNavigationOn = true;
    });
    await _refreshNavigationRoute();
  }

  void _endNavigation() {
    setState(() {
      _isVoiceNavigationOn = false;
    });
    _lastSpokenInstruction = null;
    _tts.stop();
  }

  Future<void> _openExternalNavigation() async {
    final destination = _navDestinationPoint;

    final nativeUri = Uri.parse(
      'google.navigation:q=${destination.latitude},${destination.longitude}&mode=d',
    );
    final launchedNative = await launchUrl(
      nativeUri,
      mode: LaunchMode.externalApplication,
    );
    if (launchedNative) return;

    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=driving',
    );
    final launchedWeb = await launchUrl(
      webUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launchedWeb && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open navigation.')),
      );
    }
  }
}
