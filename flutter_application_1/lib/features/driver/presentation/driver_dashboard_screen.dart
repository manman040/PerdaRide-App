import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/firebase/account_status.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/perda_map_view.dart';
import '../../booking/data/booking_repository.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  PerdaMapController? _mapController;
  final _bookingRepository = BookingRepository();
  final _firebase = PerdaRideFirebase.instance;
  late final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(
    _firebase,
  );
  late final FirebaseDatabaseRepository _databaseRepository =
      FirebaseDatabaseRepository(_firebase);

  LatLng? _driverPoint;
  int _todayTrips = 0;
  double _todayEarnings = 0;
  bool _isMenuOpen = false;
  bool _isProfileLoading = true;
  String _driverName = 'Urban Drive Driver';
  String _driverEmail = 'driver@perdaride.app';
  String _driverPackageTier = 'Package A';
  StreamSubscription<DatabaseEvent>? _bookingsSubscription;
  StreamSubscription<DatabaseEvent>? _pendingBookingsSubscription;
  StreamSubscription<Position>? _locationSubscription;
  bool _isDriverOnline = true;
  bool _isUpdatingOnlineStatus = false;
  int _pendingJobCount = 0;
  int _lastLocationPublishAt = 0;
  bool _locationRetryAvailable = false;

  String _statusText(AppCopy copy) =>
      _isDriverOnline ? copy.driverWaitingForJobsStatus : copy.driverOfflineStatus;

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _loadDriverAvailability();
    _listenTodayStats();
    _listenPendingJobs();
    // _detectDriverLocation reads AppCopy.of(context), which registers an
    // InheritedWidget dependency -- calling that synchronously from initState
    // (this method hadn't returned yet) throws
    // "dependOnInheritedWidgetOfExactType<AppSettingsScope>() ... called
    // before initState() completed", an *uncaught* exception since it happens
    // before the function's own try block, silently killing location
    // detection for the rest of the screen's life with no error shown to the
    // user. Deferring to post-frame (same pattern already used in
    // UserDashboardScreen/DriverActiveRideScreen) runs it after initState has
    // fully returned.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detectDriverLocation();
    });
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _pendingBookingsSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isProfileLoading = false;
      });
      return;
    }

    try {
      final snapshot = await _databaseRepository.getData('drivers/${user.uid}');
      final value = snapshot.value;

      if (!mounted) return;
      if (AccountStatus.isDisabled(value)) {
        await _forceSignOut();
        return;
      }

      String name = _driverName;
      String email = user.email ?? _driverEmail;

      String packageTier = _driverPackageTier;
      if (value is Map) {
        final rawName = value['name'];
        final rawEmail = value['email'];
        if (rawName is String && rawName.trim().isNotEmpty) {
          name = rawName.trim();
        }
        if (rawEmail is String && rawEmail.trim().isNotEmpty) {
          email = rawEmail.trim();
        }
        packageTier = _tierForCapacity(
          (value['passengerCapacity'] ?? '').toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        _driverName = name;
        _driverEmail = email;
        _driverPackageTier = packageTier;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _driverEmail = user.email ?? _driverEmail;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _loadDriverAvailability() async {
    final user = _authRepository.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _databaseRepository.getData('drivers/${user.uid}');
      final value = snapshot.value;
      if (value is! Map) return;
      final raw = value['isAvailable'];
      final isAvailable = raw is bool ? raw : true;
      if (!mounted) return;
      setState(() {
        _isDriverOnline = isAvailable;
      });
    } catch (_) {}
  }

  Future<void> _updateDriverAvailability(bool isOnline) async {
    final copy = AppCopy.of(context);
    final user = _authRepository.currentUser;
    if (user == null) return;
    setState(() {
      _isUpdatingOnlineStatus = true;
    });
    try {
      await _databaseRepository.updateData('drivers/${user.uid}', {
        'isAvailable': isOnline,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _isDriverOnline = isOnline;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.updateAvailabilityFailedError}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingOnlineStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return Scaffold(
      body: Stack(
        children: [
          _driverPoint == null ? _locationLoadingView(context, copy) : _driverMap(),
          _topBar(context, copy),
          _bottomPanel(context, copy),
          _buildSideMenu(context, copy),
        ],
      ),
    );
  }

  Widget _locationLoadingView(BuildContext context, AppCopy copy) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_locationRetryAvailable)
            Icon(
              Icons.location_disabled_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 32,
            )
          else
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          const SizedBox(height: 14),
          Text(
            copy.detectingLocationMessage,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_locationRetryAvailable) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _detectDriverLocation,
              child: Text(copy.retryLocationCta),
            ),
          ],
        ],
      ),
    );
  }

  Widget _driverMap() {
    final driverPoint = _driverPoint!;
    return PerdaMapView(
      key: const ValueKey('driver-dashboard-map'),
      initialCenter: driverPoint,
      initialZoom: 14.8,
      onMapCreated: (controller) => _mapController = controller,
      markers: [
        PerdaMapMarker(
          id: 'driver',
          point: driverPoint,
          color: const Color(0xFF1E88E5),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context, AppCopy copy) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          children: [
            _iconButton(
              context: context,
              icon: Icons.menu_rounded,
              onTap: () {
                setState(() {
                  _isMenuOpen = !_isMenuOpen;
                });
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    copy.driverDashboardLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPanel(BuildContext context, AppCopy copy) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.66,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: !_isDriverOnline
                            ? theme.colorScheme.onSurfaceVariant
                            : const Color(0xFF3BB273),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText(copy),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: _isDriverOnline,
                        onChanged: _isUpdatingOnlineStatus
                            ? null
                            : (value) => _updateDriverAvailability(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _metricCard(
                      context: context,
                      title: copy.tripsMetricLabel,
                      value: '$_todayTrips',
                      icon: Icons.local_taxi_rounded,
                    ),
                    const SizedBox(width: 10),
                    _metricCard(
                      context: context,
                      title: copy.earningsMetricLabel,
                      value: 'RM ${_todayEarnings.toStringAsFixed(2)}',
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ElevatedButton(
                            onPressed: !_isDriverOnline
                                ? null
                                : () async {
                                    final result = await Navigator.of(context)
                                        .pushNamed(
                                          AppRouter.driverAvailableBookings,
                                        );
                                    if (!mounted) return;
                                    if (result is Map<String, dynamic>) {
                                      final bookingId = result['bookingId'];
                                      final point = result['pickupPoint'];
                                      final dropoffPoint =
                                          result['dropoffPoint'];
                                      final pickup = result['pickupLabel'];
                                      final distance = result['distanceKm'];
                                      final dropoff = result['dropoffLabel'];
                                      final payment = result['paymentMethod'];
                                      final package = result['packageLabel'];
                                      final price = result['priceLabel'];
                                      if (bookingId is String &&
                                          point is LatLng &&
                                          dropoffPoint is LatLng &&
                                          pickup is String &&
                                          distance is String &&
                                          dropoff is String &&
                                          payment is String &&
                                          package is String &&
                                          price is String) {
                                        _publishDriverLocation(_driverPoint);
                                        if (!mounted) return;
                                        await Navigator.of(context).pushNamed(
                                          AppRouter.driverActiveRide,
                                          arguments: {
                                            'bookingId': bookingId,
                                            'pickupPoint': point,
                                            'pickupLabel': pickup,
                                            'dropoffPoint': dropoffPoint,
                                            'dropoffLabel': dropoff,
                                            'paymentMethod': payment,
                                            'packageLabel': package,
                                            'priceLabel': price,
                                            'distanceKm': distance,
                                          },
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              _isDriverOnline
                                  ? copy.availableJobsCta
                                  : copy.goOnlineForJobsCta,
                            ),
                          ),
                          if (_isDriverOnline && _pendingJobCount > 0)
                            Positioned(
                              right: -4,
                              top: -6,
                              child: Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  _pendingJobCount > 9
                                      ? '9+'
                                      : '$_pendingJobCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFF68B1F)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFFF68B1F), size: 24),
        ),
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context, AppCopy copy) {
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !_isMenuOpen,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _isMenuOpen ? 1 : 0,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isMenuOpen = false;
                });
              },
              child: Container(color: const Color(0x33000000)),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _isMenuOpen ? 286 : 0,
                  margin: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _isMenuOpen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.16),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFFF68B1F),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isProfileLoading
                                            ? copy.loadingProfileMessage
                                            : _driverName,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _driverEmail,
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _driverMenuItem(
                              context: context,
                              icon: Icons.person_outline_rounded,
                              label: copy.profileMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.driverProfile);
                              },
                            ),
                            _driverMenuItem(
                              context: context,
                              icon: Icons.notifications_none_rounded,
                              label: copy.notificationsMenu,
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  AppRouter.notifications,
                                  arguments: {'isDriver': true},
                                );
                              },
                            ),
                            _driverMenuItem(
                              context: context,
                              icon: Icons.settings_outlined,
                              label: copy.settingsMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.settings);
                              },
                            ),
                            _driverMenuItem(
                              context: context,
                              icon: Icons.history_rounded,
                              label: copy.driverHistoryMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.driverHistory);
                              },
                            ),
                            _driverMenuItem(
                              context: context,
                              icon: Icons.account_balance_wallet_outlined,
                              label: copy.totalEarningMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.driverTotalEarning);
                              },
                            ),
                            const Spacer(),
                            Divider(color: theme.dividerColor),
                            _driverMenuItem(
                              context: context,
                              icon: Icons.logout_rounded,
                              label: copy.logoutMenu,
                              danger: true,
                              onTap: _signOut,
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _isMenuOpen = false;
            });
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger
                      ? const Color(0xFFD94A35)
                      : const Color(0xFFF68B1F),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: danger
                          ? const Color(0xFFD94A35)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _listenTodayStats() {
    _bookingsSubscription = _bookingRepository.watchAllBookings().listen((
      event,
    ) {
      final user = _authRepository.currentUser;
      if (user == null) return;
      final value = event.snapshot.value;
      final stats = _computeTodayStats(value, user.uid);
      if (!mounted) return;
      setState(() {
        _todayTrips = stats.trips;
        _todayEarnings = stats.earnings;
      });
    });
  }

  Future<void> _detectDriverLocation() async {
    final copy = AppCopy.of(context);
    if (mounted) {
      setState(() {
        _locationRetryAvailable = false;
      });
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(copy.enableLocationServiceMessage),
          ),
        );
        setState(() => _locationRetryAvailable = true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy.locationPermissionRequiredMessage)),
        );
        setState(() => _locationRetryAvailable = true);
        return;
      }

      // A fresh GPS fix can take a while, or -- e.g. a stale/idle emulator
      // GPS provider, or a phone with a weak signal indoors -- never arrive
      // at all. Without a time limit this hangs forever with no way for the
      // driver to recover short of an app restart, so fall back to the last
      // cached fix (near-instant) rather than leaving the map stuck loading;
      // the live position stream below still brings it current once a real
      // fix comes in.
      Position? current;
      try {
        current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        current = await Geolocator.getLastKnownPosition();
      }

      if (current != null) {
        _updateDriverLocation(current, moveMap: true);
      } else if (mounted) {
        setState(() => _locationRetryAvailable = true);
      }

      await _locationSubscription?.cancel();
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            ),
          ).listen((position) {
            _updateDriverLocation(position, moveMap: true);
          });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.unableDetectLocationMessage)),
      );
      setState(() => _locationRetryAvailable = true);
    }
  }

  void _updateDriverLocation(Position position, {required bool moveMap}) {
    final point = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _driverPoint = point;
    });

    if (moveMap) {
      unawaited(_mapController?.animateCamera(point, 16));
    }

    _publishDriverLocation(point);
  }

  Future<void> _publishDriverLocation(LatLng? point) async {
    final user = _authRepository.currentUser;
    if (user == null || point == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastLocationPublishAt < 5000) return;
    _lastLocationPublishAt = now;

    try {
      await _databaseRepository.setData('driver_locations/${user.uid}', {
        'driverId': user.uid,
        'lat': point.latitude,
        'lng': point.longitude,
        'updatedAt': now,
      });
    } catch (_) {}
  }

  void _listenPendingJobs() {
    _pendingBookingsSubscription = _bookingRepository.watchAllBookings().listen(
      (event) {
        final driverId = _authRepository.currentUser?.uid ?? '';
        final count = _countPendingJobs(event.snapshot.value, driverId);
        if (!mounted) return;
        setState(() {
          _pendingJobCount = count;
        });
      },
    );
  }

  int _countPendingJobs(Object? raw, String currentDriverId) {
    if (raw is! Map) return 0;
    var count = 0;
    raw.forEach((_, value) {
      if (value is! Map) return;
      final status = (value['status'] ?? '').toString().toLowerCase();
      final driverId = (value['driverId'] ?? '').toString();
      final fare = _parseRm(value['fareLabel']);
      final pickupAddress = (value['pickupAddress'] ?? '').toString().trim();
      final dropoffAddress = (value['dropoffAddress'] ?? '').toString().trim();
      final distanceLabel = (value['distanceLabel'] ?? '').toString().trim();
      final packageLabel = (value['packageLabel'] ?? '').toString().trim();
      if (status != 'pending') return;
      if (driverId.isNotEmpty) return;
      if (fare <= 0) return;
      if (pickupAddress.isEmpty ||
          pickupAddress == '-' ||
          dropoffAddress.isEmpty ||
          dropoffAddress == '-') {
        return;
      }
      if (distanceLabel.isEmpty || distanceLabel == '-- km') return;
      if (packageLabel.isEmpty || packageLabel == '-') return;
      if (!packageLabel.startsWith(_driverPackageTier)) return;
      final rejectedByRaw = value['rejectedBy'];
      if (currentDriverId.isNotEmpty && rejectedByRaw is Map) {
        final rejectedForThisDriver = rejectedByRaw[currentDriverId];
        if (rejectedForThisDriver == true ||
            rejectedForThisDriver?.toString().toLowerCase() == 'true') {
          return;
        }
      }
      count += 1;
    });
    return count;
  }

  String _tierForCapacity(String capacity) {
    final seats = int.tryParse(capacity) ?? 4;
    return seats > 4 ? 'Package B' : 'Package A';
  }

  _DailyStats _computeTodayStats(Object? raw, String driverId) {
    if (raw is! Map) {
      return const _DailyStats(trips: 0, earnings: 0);
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));

    var trips = 0;
    var earnings = 0.0;

    raw.forEach((_, value) {
      if (value is! Map) return;

      final bookingDriverId = (value['driverId'] ?? '').toString();
      final status = (value['status'] ?? '').toString().toLowerCase();
      if (bookingDriverId != driverId || status != 'completed') return;

      final completedAt = _parseTimestamp(
        value['updatedAt'] ?? value['completedAt'] ?? value['createdAt'],
      );
      if (completedAt == null) return;
      if (completedAt.isBefore(startOfToday) ||
          !completedAt.isBefore(startOfTomorrow)) {
        return;
      }

      final fare = _parseRm(value['fareLabel']);
      if (fare <= 0) return;

      trips += 1;
      earnings += fare;
    });

    return _DailyStats(trips: trips, earnings: earnings);
  }

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw is Map) {
      return _parseTimestamp(raw['time'] ?? raw['seconds']);
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      return DateTime.tryParse(raw);
    }
    return null;
  }

  double _parseRm(dynamic rawFareLabel) {
    final text = (rawFareLabel ?? '').toString();
    final cleaned = text.replaceAll('RM', '').replaceAll(' ', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// The admin disabled this account: sign out and explain on the login screen.
  Future<void> _forceSignOut() async {
    final notice = AppCopy.of(context).accountDisabledError;
    try {
      await _authRepository.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.login,
      (route) => false,
      arguments: <String, dynamic>{'notice': notice},
    );
  }

  Future<void> _signOut() async {
    try {
      await _authRepository.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppCopy.of(context).logoutSuccess)),
      );
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppCopy.of(context).logoutError)));
    }
  }
}

class _DailyStats {
  const _DailyStats({required this.trips, required this.earnings});

  final int trips;
  final double earnings;
}
