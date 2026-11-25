import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/notifications/ride_notification_service.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/booking_chat_sheet.dart';
import '../../../core/widgets/perda_map_view.dart';
import '../../booking/data/booking_repository.dart';
import '../data/osrm_routing_service.dart';

enum UserBookingStatus {
  pending,
  accepted,
  arrivedPickup,
  inProgress,
  completed,
  cancelled,
}

class UserBookingStatusScreen extends StatefulWidget {
  const UserBookingStatusScreen({
    super.key,
    required this.bookingId,
    required this.pickupPoint,
    required this.pickupLabel,
    required this.dropoffPoint,
    required this.dropoffLabel,
    required this.paymentMethod,
    required this.packageLabel,
    required this.fareLabel,
  });

  final String bookingId;
  final LatLng pickupPoint;
  final String pickupLabel;
  final LatLng dropoffPoint;
  final String dropoffLabel;
  final String paymentMethod;
  final String packageLabel;
  final String fareLabel;

  @override
  State<UserBookingStatusScreen> createState() =>
      _UserBookingStatusScreenState();
}

class _UserBookingStatusScreenState extends State<UserBookingStatusScreen> {
  PerdaMapController? _mapController;
  final _bookingRepository = BookingRepository();
  final _routingService = OsrmRoutingService();
  final _databaseRepository = FirebaseDatabaseRepository(
    PerdaRideFirebase.instance,
  );
  UserBookingStatus _status = UserBookingStatus.pending;
  late String _paymentMethod = widget.paymentMethod;
  late String _packageLabel = widget.packageLabel;
  late String _fareLabel = widget.fareLabel;
  String? _driverId;
  _DriverProfileSummary? _driverProfile;
  String _loadedDriverId = '';
  bool _isCancelling = false;
  bool _isSubmittingRating = false;
  bool _hasSubmittedRating = false;
  int _selectedRating = 5;
  final TextEditingController _ratingCommentController =
      TextEditingController();
  StreamSubscription<DatabaseEvent>? _bookingSubscription;
  StreamSubscription<DatabaseEvent>? _driverLocationSubscription;
  List<LatLng> _routePoints = [];
  List<LatLng> _driverRoutePoints = [];
  OsrmRouteResult? _routeResult;
  OsrmRouteResult? _driverRouteResult;
  LatLng? _driverPoint;
  String _trackedDriverId = '';
  bool _isShowingDriverRoute = false;
  bool _isLoadingDriverRoute = false;
  bool _wantsDriverRoute = false;

  @override
  void initState() {
    super.initState();
    _listenBookingStatus();
    _loadRoute();
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _ratingCommentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    final meta = _statusMeta(_status, copy);
    // Once the driver's live route is being tracked, prefer it over the
    // static pickup->dropoff estimate from booking time -- otherwise this
    // tag drifts out of sync with the driver's own live navigation view,
    // which always reflects their current remaining distance/ETA.
    final liveDriverRoute = _isShowingDriverRoute ? _driverRouteResult : null;
    final distanceKm =
        liveDriverRoute?.distanceLabel ??
        _routeResult?.distanceLabel ??
        _distanceLabel(widget.pickupPoint, widget.dropoffPoint);
    final etaLabel = liveDriverRoute?.etaLabel ?? _routeResult?.etaLabel;

    return Scaffold(
      body: Stack(
        children: [
          _bookingMap(),
          _topBar(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: meta.badgeBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Icon(meta.icon, color: meta.badgeFg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                meta.subtitle,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_status == UserBookingStatus.pending) ...[
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacementNamed(
                              AppRouter.bookingPreview,
                              arguments: <String, dynamic>{
                                'pickupPoint': widget.pickupPoint,
                                'pickupLabel': widget.pickupLabel,
                                'dropoffPoint': widget.dropoffPoint,
                                'dropoffLabel': widget.dropoffLabel,
                                'existingBookingId': widget.bookingId,
                                'initialPaymentMethod': _paymentMethod,
                                'initialPackageLabel': _packageLabel,
                              },
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(72, 42),
                              side: BorderSide(color: theme.dividerColor),
                            ),
                            child: Text(copy.editCta),
                          ),
                          const SizedBox(width: 6),
                        ],
                        IconButton(
                          onPressed: () => _exitBookingStatusScreen(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (_driverProfile != null) ...[
                      const SizedBox(height: 12),
                      _driverInfoCard(context, _driverProfile!),
                    ],
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _tag(context, _paymentMethod),
                          const SizedBox(width: 8),
                          _tag(context, distanceKm),
                          if (etaLabel != null) ...[
                            const SizedBox(width: 8),
                            _tag(context, etaLabel),
                          ],
                          const SizedBox(width: 8),
                          _tag(context, _fareLabel),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_canShowDriverLocation) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingDriverRoute
                              ? null
                              : _showDriverLocation,
                          icon:
                              (_isLoadingDriverRoute ||
                                  (_wantsDriverRoute && _driverPoint == null))
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.directions_car_rounded),
                          label: Text(
                            _isLoadingDriverRoute
                                ? copy.loadingDriverRouteLabel
                                : (_wantsDriverRoute && _driverPoint == null)
                                ? copy.waitingForDriverLocationLabel
                                : copy.showDriverLocationCta,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isCancelling ||
                                _status == UserBookingStatus.completed
                            ? null
                            : _cancelBooking,
                        child: Text(
                          _isCancelling
                              ? copy.cancellingLabel
                              : copy.cancelBookingCta,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => showBookingChatSheet(
                          context,
                          bookingRepository: _bookingRepository,
                          bookingId: widget.bookingId,
                          currentUserRole: 'user',
                        ),
                        child: Text(copy.chatWithDriverTitle),
                      ),
                    ),
                    if (_status == UserBookingStatus.completed) ...[
                      const SizedBox(height: 10),
                      _ratingCard(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exitBookingStatusScreen(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        AppRouter.userDashboard,
        (route) => false,
      );
    }
  }

  Widget _topBar(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _exitBookingStatusScreen(context),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface,
              ),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingMap() {
    final showDriverRoute = _isShowingDriverRoute &&
        _driverPoint != null &&
        _driverRoutePoints.isNotEmpty;
    final routePoints = showDriverRoute
        ? _driverRoutePoints
        : _routePoints.isEmpty
        ? [widget.pickupPoint, widget.dropoffPoint]
        : _routePoints;
    final driverPoint = _driverPoint;

    return PerdaMapView(
      key: const ValueKey('user-booking-status-map'),
      initialCenter: LatLng(
        (widget.pickupPoint.latitude + widget.dropoffPoint.latitude) / 2,
        (widget.pickupPoint.longitude + widget.dropoffPoint.longitude) / 2,
      ),
      initialZoom: 14.3,
      onMapCreated: (controller) => _mapController = controller,
      markers: [
        PerdaMapMarker(
          id: 'pickup',
          point: widget.pickupPoint,
          color: const Color(0xFF2E7D32),
        ),
        PerdaMapMarker(
          id: 'dropoff',
          point: widget.dropoffPoint,
          color: const Color(0xFFD32F2F),
        ),
        if (driverPoint != null)
          PerdaMapMarker(
            id: 'driver',
            point: driverPoint,
            color: const Color(0xFF1E88E5),
          ),
      ],
      polylines: [
        PerdaMapPolyline(
          id: 'route',
          points: routePoints,
          color: showDriverRoute
              ? const Color(0xFF1D4ED8)
              : const Color(0xFF2CB67D),
        ),
      ],
    );
  }

  Widget _tag(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _driverInfoCard(BuildContext context, _DriverProfileSummary profile) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.surface,
            backgroundImage: profile.imageUrl.startsWith('http')
                ? NetworkImage(profile.imageUrl)
                : null,
            child: profile.imageUrl.startsWith('http')
                ? null
                : Icon(
                    Icons.person,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.vehicleModel.isEmpty
                      ? copy.vehicleUnknownLabel
                      : profile.vehicleModel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${copy.platePrefixLabel} ${profile.plateNumber}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (profile.phone.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _callDriver(profile.phone),
              icon: const Icon(Icons.call_rounded),
              iconSize: 26,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2E9B51),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _callDriver(String phone) async {
    final copy = AppCopy.of(context);
    final uri = Uri.parse('tel:$phone');
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.unableToStartCallError)));
    }
  }

  void _listenBookingStatus() {
    _bookingSubscription = _bookingRepository
        .watchBooking(widget.bookingId)
        .listen((event) {
          final value = event.snapshot.value;
          if (value is! Map) return;
          final dynamic rawStatus = value['status'];
          final dynamic rawDriverId = value['driverId'];
          final dynamic rawRated = value['rated'];
          final dynamic rawPaymentMethod = value['paymentMethod'];
          final dynamic rawPackageLabel = value['packageLabel'];
          final dynamic rawFareLabel = value['fareLabel'];
          final status = _fromStatus(rawStatus?.toString());
          if (!mounted) return;
          setState(() {
            _status = status;
            _driverId = rawDriverId?.toString();
            _hasSubmittedRating = rawRated == true;
            if (rawPaymentMethod is String && rawPaymentMethod.isNotEmpty) {
              _paymentMethod = rawPaymentMethod;
            }
            if (rawPackageLabel is String && rawPackageLabel.isNotEmpty) {
              _packageLabel = rawPackageLabel;
            }
            if (rawFareLabel is String && rawFareLabel.isNotEmpty) {
              _fareLabel = rawFareLabel;
            }
          });
          _loadDriverProfile();
          _listenDriverLocation();
        });
  }

  bool get _canShowDriverLocation {
    return _driverId != null &&
        _driverId!.trim().isNotEmpty &&
        (_status == UserBookingStatus.accepted ||
            _status == UserBookingStatus.arrivedPickup ||
            _status == UserBookingStatus.inProgress);
  }

  void _listenDriverLocation() {
    final driverId = _driverId?.trim() ?? '';
    if (driverId.isEmpty || driverId == _trackedDriverId) return;
    _trackedDriverId = driverId;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = _databaseRepository
        .watchPath('driver_locations/$driverId')
        .listen((event) {
          final value = event.snapshot.value;
          if (value is! Map) return;

          final lat = _toDouble(value['lat']);
          final lng = _toDouble(value['lng']);
          if (lat == null || lng == null) return;

          final point = LatLng(lat, lng);
          if (!mounted) return;
          setState(() {
            _driverPoint = point;
          });

          if (_wantsDriverRoute && !_isShowingDriverRoute) {
            setState(() {
              _isShowingDriverRoute = true;
            });
            _loadDriverRoute(moveMap: true);
          } else if (_isShowingDriverRoute) {
            _loadDriverRoute(moveMap: false);
          }
        });
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _showDriverLocation() async {
    final copy = AppCopy.of(context);
    setState(() {
      _wantsDriverRoute = true;
    });
    if (_driverPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.waitingForDriverLiveLocationError)),
      );
      return;
    }
    setState(() {
      _isShowingDriverRoute = true;
    });
    await _loadDriverRoute(moveMap: true);
  }

  Future<void> _loadDriverRoute({required bool moveMap}) async {
    final driverPoint = _driverPoint;
    if (driverPoint == null || _isLoadingDriverRoute) return;

    setState(() {
      _isLoadingDriverRoute = true;
    });
    final destination = _status == UserBookingStatus.inProgress
        ? widget.dropoffPoint
        : widget.pickupPoint;
    final result = await _routingService.getDrivingRouteResult(
      from: driverPoint,
      to: destination,
    );
    if (!mounted) return;
    setState(() {
      _driverRoutePoints = result.points;
      _driverRouteResult = result;
      _isLoadingDriverRoute = false;
    });
    if (moveMap) {
      await _mapController?.animateCamera(driverPoint, 15.8);
    }
  }

  Future<void> _loadDriverProfile() async {
    final driverId = _driverId?.trim() ?? '';
    if (driverId == _loadedDriverId) return;
    if (driverId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _driverProfile = null;
        _loadedDriverId = '';
      });
      return;
    }

    try {
      final snapshot = await _databaseRepository.getData('drivers/$driverId');
      Map? value = snapshot.value is Map ? snapshot.value as Map : null;
      if (value == null) {
        final fallbackSnapshot = await _databaseRepository.getData(
          'driver_approvals/$driverId',
        );
        if (fallbackSnapshot.value is Map) {
          value = fallbackSnapshot.value as Map;
        }
      }
      if (!mounted) return;
      if (value == null) {
        setState(() {
          _driverProfile = null;
          _loadedDriverId = driverId;
        });
        return;
      }

      final name = (value['name'] ?? '').toString().trim();
      final imagePath = (value['profilePicturePath'] ?? '').toString().trim();
      final model = (value['vehicleModel'] ?? '').toString().trim();
      final brand = (value['vehicleBrand'] ?? '').toString().trim();
      final phone = (value['phone'] ?? '').toString().trim();
      final plate =
          (value['plateNumber'] ??
                  value['carPlateNumber'] ??
                  value['vehiclePlate'] ??
                  value['carPlate'] ??
                  value['registrationNumber'] ??
                  'Not set')
              .toString()
              .trim();

      setState(() {
        _driverProfile = _DriverProfileSummary(
          name: name.isEmpty ? 'Driver' : name,
          imageUrl: imagePath,
          vehicleModel: [
            brand,
            model,
          ].where((e) => e.trim().isNotEmpty).join(' ').trim(),
          plateNumber: plate.isEmpty ? 'Not set' : plate,
          phone: phone,
        );
        _loadedDriverId = driverId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _driverProfile = null;
        _loadedDriverId = driverId;
      });
    }
  }

  Future<void> _loadRoute() async {
    final result = await _routingService.getDrivingRouteResult(
      from: widget.pickupPoint,
      to: widget.dropoffPoint,
    );
    if (!mounted) return;
    setState(() {
      _routeResult = result;
      _routePoints = result.points;
    });
  }

  Future<void> _cancelBooking() async {
    setState(() {
      _isCancelling = true;
    });
    try {
      await _bookingRepository.updateBookingStatus(
        bookingId: widget.bookingId,
        status: 'cancelled',
      );
      final driverId = _driverId?.trim() ?? '';
      if (driverId.isNotEmpty) {
        unawaited(
          RideNotificationService.instance.notify(
            uid: driverId,
            isDriver: true,
            title: 'Ride cancelled',
            body: 'The passenger cancelled this ride.',
            bookingId: widget.bookingId,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _status = UserBookingStatus.cancelled;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  String _distanceLabel(LatLng pickup, LatLng dropoff) {
    const distance = Distance();
    final meter = distance.as(LengthUnit.Meter, pickup, dropoff);
    return '${(meter / 1000).toStringAsFixed(1)} km';
  }

  _StatusMeta _statusMeta(UserBookingStatus status, AppCopy copy) {
    switch (status) {
      case UserBookingStatus.pending:
        const badgeFg = Color(0xFFE09D00);
        return _StatusMeta(
          title: copy.bookingPendingTitle,
          subtitle: copy.bookingPendingSubtitle,
          icon: Icons.access_time_rounded,
          badgeBg: badgeFg.withValues(alpha: 0.16),
          badgeFg: badgeFg,
        );
      case UserBookingStatus.accepted:
        const badgeFg = Color(0xFF2E7D32);
        return _StatusMeta(
          title: copy.driverAcceptedTitle,
          subtitle: copy.driverAcceptedSubtitle,
          icon: Icons.check_circle_rounded,
          badgeBg: badgeFg.withValues(alpha: 0.14),
          badgeFg: badgeFg,
        );
      case UserBookingStatus.arrivedPickup:
        const badgeFg = Color(0xFF2D64E3);
        return _StatusMeta(
          title: copy.driverArrivedTitle,
          subtitle: copy.driverArrivedSubtitle,
          icon: Icons.directions_car_filled_rounded,
          badgeBg: badgeFg.withValues(alpha: 0.14),
          badgeFg: badgeFg,
        );
      case UserBookingStatus.inProgress:
        const badgeFg = Color(0xFF7A3FD0);
        return _StatusMeta(
          title: copy.rideInProgressTitle,
          subtitle: copy.rideInProgressSubtitle,
          icon: Icons.route_rounded,
          badgeBg: badgeFg.withValues(alpha: 0.14),
          badgeFg: badgeFg,
        );
      case UserBookingStatus.completed:
        const badgeFg = Color(0xFF2E7D32);
        return _StatusMeta(
          title: copy.rideCompletedTitle,
          subtitle: copy.rideCompletedSubtitle,
          icon: Icons.verified_rounded,
          badgeBg: badgeFg.withValues(alpha: 0.14),
          badgeFg: badgeFg,
        );
      case UserBookingStatus.cancelled:
        const badgeFg = Color(0xFFD84315);
        return _StatusMeta(
          title: copy.bookingCancelledTitle,
          subtitle: copy.bookingCancelledSubtitle,
          icon: Icons.cancel_rounded,
          badgeBg: badgeFg.withValues(alpha: 0.14),
          badgeFg: badgeFg,
        );
    }
  }

  UserBookingStatus _fromStatus(String? value) {
    switch (value) {
      case 'pending':
        return UserBookingStatus.pending;
      case 'accepted':
        return UserBookingStatus.accepted;
      case 'arrived_pickup':
        return UserBookingStatus.arrivedPickup;
      case 'in_progress':
        return UserBookingStatus.inProgress;
      case 'completed':
        return UserBookingStatus.completed;
      case 'cancelled':
        return UserBookingStatus.cancelled;
      default:
        return UserBookingStatus.pending;
    }
  }

  Widget _ratingCard(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    const badgeAccent = Color(0xFFF6A623);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.rateYourDriverLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => IconButton(
                onPressed: _hasSubmittedRating
                    ? null
                    : () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                icon: Icon(
                  index < _selectedRating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: badgeAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ratingCommentController,
            enabled: !_hasSubmittedRating,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: copy.writeCommentHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_hasSubmittedRating || _isSubmittingRating)
                  ? null
                  : _submitRating,
              child: Text(
                _hasSubmittedRating
                    ? copy.ratingSubmittedLabel
                    : _isSubmittingRating
                    ? copy.bookingSubmittingCta
                    : copy.submitRatingCta,
              ),
            ),
          ),
          if (_hasSubmittedRating) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.userDashboard,
                  (route) => false,
                ),
                child: Text(copy.backToHomeCta),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitRating() async {
    final copy = AppCopy.of(context);
    final driverId = _driverId?.trim() ?? '';
    final comment = _ratingCommentController.text.trim();
    if (driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.driverNotFoundForRatingError)),
      );
      return;
    }

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      await _databaseRepository
          .setData('ratings/$driverId/${widget.bookingId}', {
            'bookingId': widget.bookingId,
            'driverId': driverId,
            'rating': _selectedRating,
            'comment': comment,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
      await _databaseRepository.updateData('bookings/${widget.bookingId}', {
        'rated': true,
        'rating': _selectedRating,
        'ratingComment': comment,
        'ratingTimestamp': DateTime.now().millisecondsSinceEpoch,
      });
      if (!mounted) return;
      setState(() {
        _hasSubmittedRating = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.thanksRatingSubmittedMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.failedToSubmitRatingError} $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }
}

class _StatusMeta {
  const _StatusMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeBg,
    required this.badgeFg,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeBg;
  final Color badgeFg;
}

class _DriverProfileSummary {
  const _DriverProfileSummary({
    required this.name,
    required this.imageUrl,
    required this.vehicleModel,
    required this.plateNumber,
    required this.phone,
  });

  final String name;
  final String imageUrl;
  final String vehicleModel;
  final String plateNumber;
  final String phone;
}
