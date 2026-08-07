import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
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
  String _driverName = 'PerdaRide Driver';
  String _driverEmail = 'driver@perdaride.app';
  String _driverPackageTier = 'Package A';
  StreamSubscription<DatabaseEvent>? _bookingsSubscription;
  StreamSubscription<DatabaseEvent>? _pendingBookingsSubscription;
  StreamSubscription<Position>? _locationSubscription;
  bool _isDriverOnline = true;
  bool _isUpdatingOnlineStatus = false;
  int _pendingJobCount = 0;
  int _lastLocationPublishAt = 0;

  String get _statusText => _isDriverOnline ? 'Waiting for jobs' : 'Offline';

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _loadDriverAvailability();
    _listenTodayStats();
    _listenPendingJobs();
    _detectDriverLocation();
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
        SnackBar(content: Text('Failed to update availability: $e')),
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
      backgroundColor: const Color(0xFFF5F2EE),
      body: Stack(
        children: [
          _driverPoint == null ? _locationLoadingView() : _driverMap(),
          _topBar(context, copy),
          _bottomPanel(context),
          _buildSideMenu(context, copy),
        ],
      ),
    );
  }

  Widget _locationLoadingView() {
    return Container(
      color: const Color(0xFFF5F2EE),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 14),
          Text(
            'Detecting current location...',
            style: TextStyle(
              color: Color(0xFF454545),
              fontWeight: FontWeight.w700,
            ),
          ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          children: [
            _iconButton(
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
                  color: Colors.white,
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
                    style: const TextStyle(
                      color: Color(0xFF222222),
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

  Widget _bottomPanel(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.66,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
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
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF3BB273),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                          color: Color(0xFF454545),
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
                      title: 'Trips',
                      value: '$_todayTrips',
                      icon: Icons.local_taxi_rounded,
                    ),
                    const SizedBox(width: 10),
                    _metricCard(
                      title: 'Earnings',
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
                                  ? 'Available Jobs'
                                  : 'Go Online to Get Jobs',
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
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF7DFC3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFF68B1F)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7B6A58),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A2A2A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
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
                    color: Colors.white,
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
                                const CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Color(0xFFFFE7CB),
                                  child: Icon(
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
                                            ? 'Loading profile...'
                                            : _driverName,
                                        style: const TextStyle(
                                          color: Color(0xFF1F1F1F),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _driverEmail,
                                        style: const TextStyle(
                                          color: Color(0xFF757575),
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
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.notifications);
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
                            const Divider(color: Color(0x14000000)),
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
                Text(
                  label,
                  style: TextStyle(
                    color: danger
                        ? const Color(0xFFD94A35)
                        : const Color(0xFF212121),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location service on your phone.'),
          ),
        );
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
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _updateDriverLocation(current, moveMap: true);

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
        const SnackBar(content: Text('Unable to detect your location now.')),
      );
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
