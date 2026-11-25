import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/notifications/ride_notification_service.dart';
import '../../../core/services/mapbox_directions_service.dart';
import '../../../core/settings/app_copy.dart';
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
  late String _distanceText = widget.initialDistanceLabel;
  MapboxRouteResult? _routeResult;
  bool _isVoiceNavigationOn = false;
  bool _isMuted = false;
  String? _lastSpokenInstruction;
  PerdaMapController? _navMapController;
  StreamSubscription<DatabaseEvent>? _driverLocationSubscription;
  StreamSubscription<Position>? _liveLocationSubscription;
  StreamSubscription<DatabaseEvent>? _bookingStatusSubscription;
  int _lastLocationPublishAt = 0;
  int _lastCameraAnimateAt = 0;

  bool _ttsReady = false;
  // Set right before this screen writes 'cancelled' itself (driver-initiated
  // cancel), so the booking listener below doesn't mistake that echo for a
  // rider-initiated cancellation and pop up a redundant/contradictory dialog.
  bool _cancelledLocally = false;
  bool _isHandlingRideEnd = false;

  @override
  void initState() {
    super.initState();
    _listenDriverLocation();
    _listenBookingStatus();
    // Deferred to post-frame so the initial GPS fix (a platform channel
    // round-trip to a slow-to-respond system service) doesn't compete with
    // the map's own first-frame setup, which is when this screen is most
    // prone to input-dispatch contention right after a cold app launch.
    //
    // TTS is intentionally *not* initialized here: `TextToSpeech.setLanguage`
    // makes Android synchronously enumerate and deserialize every installed
    // voice on the calling thread (confirmed via a main-thread stack trace
    // caught mid-freeze, stuck in `Voice.<init>` via `ObjectInputStream`).
    // That's slow regardless of timing, so it's deferred further, to
    // _ensureTtsReady(), which only runs the first time voice navigation is
    // actually turned on -- most rides never need it at all.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _detectInitialLocation();
    });
  }

  Future<void> _ensureTtsReady() async {
    if (_ttsReady) return;
    _ttsReady = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
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

      // See the matching comment in DriverDashboardScreen._detectDriverLocation:
      // a fresh GPS fix can hang indefinitely (stale emulator provider, weak
      // signal, etc.), so fall back to the last cached fix instead of leaving
      // this screen without a location. _startNavigation() already retries
      // this call if it's still null when the driver taps Navigate.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null || !mounted || _driverPoint != null) return;
      setState(() {
        _driverPoint = LatLng(position!.latitude, position.longitude);
      });
      _refreshNavigationRoute();
    } catch (_) {}
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    _liveLocationSubscription?.cancel();
    _bookingStatusSubscription?.cancel();
    _tts.stop();
    super.dispose();
  }

  /// Mirrors the passenger side's own booking listener -- without this, a
  /// rider cancelling mid-ride (in [UserBookingStatusScreen]) writes
  /// 'cancelled' to Firebase but this screen, which only knew the status at
  /// the moment it opened, keeps showing ACCEPTED/ARRIVED/IN PROGRESS with
  /// every action button still live.
  void _listenBookingStatus() {
    _bookingStatusSubscription = _bookingRepository
        .watchBooking(widget.bookingId)
        .listen((event) {
          final value = event.snapshot.value;
          if (value is! Map) return;
          final status = (value['status'] ?? '').toString();
          if (status == 'cancelled' && !_cancelledLocally) {
            _handleRideCancelledByRider();
          }
        });
  }

  Future<void> _handleRideCancelledByRider() async {
    if (_isHandlingRideEnd) return;
    _isHandlingRideEnd = true;
    _tts.stop();
    if (_isVoiceNavigationOn) {
      _stopLiveLocationBroadcast();
    }
    if (!mounted) return;
    final copy = AppCopy.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.rideCancelledByPassengerTitle),
        content: Text(copy.rideCancelledByPassengerMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(copy.okCta),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _exitRideScreen();
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

          // While actively navigating, _startLiveLocationBroadcast's direct GPS
          // stream already drives _driverPoint/the camera with fresher data --
          // this Firebase echo is throttled to a 5s publish cadence, so letting
          // it also overwrite _driverPoint here would periodically snap the
          // camera back to a stale position. Pre-navigation (e.g. the ride-card
          // preview map), this is still the only source of driver position.
          if (!_isVoiceNavigationOn) {
            final previous = _driverPoint;
            if (!mounted) return;
            setState(() {
              if (previous != null && previous != point) {
                _driverBearing = const Distance().bearing(previous, point);
              }
              _driverPoint = point;
            });
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

  String _statusTextFor(AppCopy copy) {
    switch (_rideStage) {
      case DriverRideStage.idle:
      case DriverRideStage.accepted:
        return copy.headingToPickupStatus;
      case DriverRideStage.arrivedPickup:
        return copy.driverArrivedPickupStatus;
      case DriverRideStage.inProgress:
        return copy.rideInProgressStatus;
      case DriverRideStage.completed:
        return copy.rideCompletedStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isVoiceNavigationOn
          ? _navigationView(context)
          : SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 220, child: _pickupPreviewMap(context)),
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
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    final stageMeta = switch (_rideStage) {
      DriverRideStage.accepted => (
        label: copy.acceptedStageLabel,
        color: const Color(0xFF2E90E5),
        primaryAction: copy.arrivedActionCta,
      ),
      DriverRideStage.arrivedPickup => (
        label: copy.arrivedPickupStageLabel,
        color: const Color(0xFFF09A1A),
        primaryAction: copy.startRideCta,
      ),
      DriverRideStage.inProgress => (
        label: copy.inProgressStageLabel,
        color: const Color(0xFF8E44AD),
        primaryAction: copy.completeRideCta,
      ),
      DriverRideStage.completed => (
        label: copy.completedStageLabel,
        color: const Color(0xFF2E7D32),
        primaryAction: copy.doneCta,
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
          _statusTextFor(copy),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
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
                context: context,
                icon: Icons.trip_origin_rounded,
                color: const Color(0xFF2E7D32),
                value: widget.pickupLabel,
              ),
              const SizedBox(height: 8),
              _rideAddress(
                context: context,
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
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
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
                          ? copy.navigateToDropoffCta
                          : copy.navigateToPassengerCta,
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
                      _exitRideScreen();
                      return;
                    }

                    setState(() {
                      if (_rideStage == DriverRideStage.accepted) {
                        _rideStage = DriverRideStage.arrivedPickup;
                      } else if (_rideStage ==
                          DriverRideStage.arrivedPickup) {
                        _rideStage = DriverRideStage.inProgress;
                      } else if (_rideStage == DriverRideStage.inProgress) {
                        _rideStage = DriverRideStage.completed;
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
                    child: Text(copy.cancelRideCta),
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
                  child: Text(copy.chatWithPassengerTitle),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rideAddress({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: theme.colorScheme.onSurface, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _pickupPreviewMap(BuildContext context) {
    final driverPoint = _driverPoint;
    if (driverPoint == null) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
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

  Widget _navigationView(BuildContext context) {
    final driverPoint = _driverPoint;
    if (driverPoint == null) {
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final copy = AppCopy.of(context);
    final destination = _navDestinationPoint;
    final route = _routeResult;
    final routePoints = route != null && route.points.length > 1
        ? route.points
        : [driverPoint, destination];

    // Reverted to the original full-bleed Stack layout: wrapping the map in
    // Expanded/Column (to keep buttons off it) made the platform view
    // render solid black permanently -- a known Flutter platform-view
    // sizing-timing issue, confirmed directly on-device. The overlay-touch
    // problem (buttons on top of the map not receiving taps) is real but
    // needs a different fix than restructuring this layout; see
    // perda_map_view.dart's docstring for the current state of that
    // investigation. Use the bottom sheet's "End Navigation" button, not
    // the top-left back arrow, until that's resolved.
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _navBackButton(context),
                const SizedBox(height: 10),
                _instructionBanner(copy),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 210,
          child: _recenterButton(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(top: false, child: _navigationBottomSheet(context, copy)),
        ),
      ],
    );
  }

  Widget _navBackButton(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: _endNavigation,
      icon: Icon(
        Icons.arrow_back_rounded,
        color: theme.colorScheme.onSurface,
      ),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
      ),
    );
  }

  Widget _instructionBanner(AppCopy copy) {
    final routeResult = _routeResult;
    final steps = routeResult?.steps ?? const <MapboxRouteStep>[];
    final step = steps.isEmpty ? null : steps.first;
    final afterNext = steps.length > 1 ? steps[1] : null;
    // A non-null result with no steps means the route call fell back to a
    // straight-line estimate (e.g. the directions request timed out) rather
    // than still being in flight -- distinguish that from genuinely loading
    // so the banner doesn't say "Finding your route..." forever.
    final placeholderText = routeResult == null
        ? copy.findingRouteMessage
        : copy.directionsUnavailableMessage;

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
        mainAxisSize: MainAxisSize.min,
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
                      step?.instruction ?? placeholderText,
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
                Text(
                  copy.thenLabel,
                  style: const TextStyle(
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

  Widget _navigationBottomSheet(BuildContext context, AppCopy copy) {
    final theme = Theme.of(context);
    final route = _routeResult;
    // Malaysia has a fixed UTC+8 offset (no DST), computed explicitly here
    // instead of relying on DateTime.now()'s local offset -- devices/
    // emulators with their system timezone misconfigured (e.g. left on UTC)
    // would otherwise show an arrival time hours off from the real one.
    final arrival = route == null
        ? null
        : DateTime.now().toUtc().add(
            const Duration(hours: 8),
          ).add(Duration(seconds: route.durationSeconds.round()));
    final arrivalLabel = arrival == null
        ? '--:--'
        : '${arrival.hour.toString().padLeft(2, '0')}:'
              '${arrival.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
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
            '${copy.toDestinationLabel} $_navDestinationLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                route?.etaLabel ?? '-- min',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                route?.distanceLabel ?? '-- km',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${copy.arriveAtLabel} ~$arrivalLabel',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              onPressed: _endNavigation,
              child: Text(copy.endNavigationCta),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide() async {
    _cancelledLocally = true;
    _isHandlingRideEnd = true;
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
    _exitRideScreen();
  }

  void _exitRideScreen() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        AppRouter.driverDashboard,
        (route) => false,
      );
    }
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
    final copy = AppCopy.of(context);
    if (_driverPoint == null) {
      // The post-frame GPS fix may still be in flight (e.g. tapping this
      // right after the screen opens) -- try once more inline instead of
      // giving up, since bailing out here left the screen stuck showing
      // the ride card with no way to reach the navigation view.
      await _detectInitialLocation();
    }
    if (_driverPoint == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.waitingForLocationMessage)),
      );
      return;
    }

    setState(() {
      _isVoiceNavigationOn = true;
    });
    unawaited(_ensureTtsReady());
    _startLiveLocationBroadcast();
    await _refreshNavigationRoute();
  }

  void _endNavigation() {
    setState(() {
      _isVoiceNavigationOn = false;
    });
    _lastSpokenInstruction = null;
    _tts.stop();
    _stopLiveLocationBroadcast();
  }

  /// Streams the driver's GPS to `driver_locations/{uid}` for as long as
  /// navigation is on, so the passenger's "Show Driver Location" always has
  /// a live feed to read -- independent of whether [DriverDashboardScreen]
  /// is still alive underneath (it isn't, e.g. when the app is relaunched
  /// mid-ride and the splash screen restores straight into this screen).
  /// Also drives the on-screen camera directly from this same local GPS
  /// stream (see [_updateLocalDriverPosition]) instead of waiting on the
  /// throttled Firebase round-trip, so the map tracks the driver smoothly
  /// without needing a manual recenter tap.
  void _startLiveLocationBroadcast() {
    _liveLocationSubscription?.cancel();
    _liveLocationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 8,
          ),
        ).listen((position) {
          final point = LatLng(position.latitude, position.longitude);
          _updateLocalDriverPosition(point);
          _publishDriverLocation(point);
        });
    final point = _driverPoint;
    if (point != null) {
      _publishDriverLocation(point);
    }
  }

  void _stopLiveLocationBroadcast() {
    _liveLocationSubscription?.cancel();
    _liveLocationSubscription = null;
  }

  /// Updates the local driver marker/camera directly from a fresh GPS fix,
  /// bypassing the Firebase publish/read-back round trip entirely so the
  /// navigation camera follows in near-real-time. The animate call itself is
  /// separately throttled (~800ms) because Mapbox's `flyTo` runs a 650ms
  /// animation that GPS ticks at driving speed (8m distanceFilter) can
  /// otherwise interrupt/restart before it finishes, which looks jerky.
  void _updateLocalDriverPosition(LatLng point) {
    if (!mounted) return;
    final previous = _driverPoint;
    setState(() {
      if (previous != null && previous != point) {
        _driverBearing = const Distance().bearing(previous, point);
      }
      _driverPoint = point;
    });

    if (!_isVoiceNavigationOn) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCameraAnimateAt < 800) return;
    _lastCameraAnimateAt = now;
    unawaited(_navMapController?.animateCamera(point, 17.5));
  }

  Future<void> _publishDriverLocation(LatLng point) async {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLocationPublishAt < 5000) return;
    _lastLocationPublishAt = now;

    try {
      await _databaseRepository.setData('driver_locations/$uid', {
        'driverId': uid,
        'lat': point.latitude,
        'lng': point.longitude,
        'updatedAt': now,
      });
    } catch (_) {}
  }
}
