import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/perda_map_view.dart';
import '../data/nominatim_geocoding_service.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  PerdaMapController? _mapController;
  final _searchController = TextEditingController();
  final _firebase = PerdaRideFirebase.instance;
  late final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(
    _firebase,
  );
  late final FirebaseDatabaseRepository _databaseRepository =
      FirebaseDatabaseRepository(_firebase);
  final _geocoding = NominatimGeocodingService();
  bool _isMenuOpen = false;
  String _menuName = 'PerdaRide User';
  String _menuEmail = 'user@perdaride.app';
  bool _isProfileLoading = true;
  bool _isResolvingPickup = false;
  bool _isDetectingLocation = false;
  LatLng? _pickupPoint;
  String _pickupLabel = '';
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _detectMyLocation();
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = _authRepository.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isProfileLoading = false;
      });
      return;
    }

    try {
      final snapshot = await _databaseRepository.getData('users/${user.uid}');
      final value = snapshot.value;

      String name = _menuName;
      String email = user.email ?? _menuEmail;

      if (value is Map) {
        final rawName = value['name'];
        final rawEmail = value['email'];
        if (rawName is String && rawName.trim().isNotEmpty) {
          name = rawName.trim();
        }
        if (rawEmail is String && rawEmail.trim().isNotEmpty) {
          email = rawEmail.trim();
        }
      }

      if (!mounted) return;
      setState(() {
        _menuName = name;
        _menuEmail = email;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _menuEmail = user.email ?? _menuEmail;
        _isProfileLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2ECE7),
      body: Stack(
        children: [
          _pickupPoint == null ? _locationLoadingView() : _pickupMap(),
          _buildTopBar(context),
          _buildLocationPill(copy),
          if (_pickupPoint != null) _buildPickupCard(copy),
          _buildBookingFab(context),
          _buildSideMenu(context, copy),
        ],
      ),
    );
  }

  Widget _locationLoadingView() {
    return Container(
      color: const Color(0xFFF2ECE7),
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

  Widget _pickupMap() {
    final pickupPoint = _pickupPoint!;
    return PerdaMapView(
      key: const ValueKey('user-dashboard-map'),
      initialCenter: pickupPoint,
      initialZoom: 15,
      onMapCreated: (controller) => _mapController = controller,
      onTap: _onMapTap,
      markers: [
        PerdaMapMarker(
          id: 'pickup',
          point: pickupPoint,
          color: const Color(0xFFF68B1F),
        ),
      ],
    );
  }

  void _syncPickupMarker({required bool moveCamera}) {
    final point = _pickupPoint;
    if (!moveCamera || point == null) return;
    _mapController?.animateCamera(point, 16);
  }

  Widget _buildTopBar(BuildContext context) {
    final copy = AppCopy.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      height: topInset + 74,
      padding: EdgeInsets.only(top: topInset),
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Color(0xFFFDFCFB),
          boxShadow: [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _isMenuOpen = !_isMenuOpen;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.menu, color: Color(0xFFF68B1F), size: 28),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1C000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: copy.searchHint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF9A9A9A),
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFF68B1F),
                    ),
                    suffixIcon: _isResolvingPickup
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (value) {
                    _applyPickupSearch(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPill(AppCopy copy) {
    return Positioned(
      top: 122,
      right: 18,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _detectMyLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isDetectingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.my_location,
                        size: 18,
                        color: Color(0xFF1E88E5),
                      ),
                const SizedBox(width: 8),
                Text(
                  _isDetectingLocation ? 'Detecting...' : 'Detect My Location',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingFab(BuildContext context) {
    final copy = AppCopy.of(context);
    return Positioned(
      bottom: 22,
      right: 22,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (_pickupPoint == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(copy.pickupRequiredMessage)),
              );
              return;
            }
            Navigator.of(context).pushNamed(
              AppRouter.dropoffLocation,
              arguments: <String, dynamic>{
                'pickupPoint': _pickupPoint,
                'pickupLabel': _pickupLabel,
              },
            );
          },
          child: Ink(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF15A24), Color(0xFFF68B1F)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44F15A24),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add, color: Colors.white, size: 34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupCard(AppCopy copy) {
    return Positioned(
      top: 172,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E0D8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7CB),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Icon(
                Icons.trip_origin_rounded,
                color: Color(0xFFF68B1F),
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.pickupLocation,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF353535),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pickupLabel.isEmpty ? copy.loadingPlace : _pickupLabel,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  width: _isMenuOpen ? 248 : 0,
                  margin: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
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
                            _MenuHeader(
                              name: _menuName,
                              email: _menuEmail,
                              isLoading: _isProfileLoading,
                            ),
                            const SizedBox(height: 16),
                            _menuItem(
                              context: context,
                              icon: Icons.person_outline_rounded,
                              label: copy.profileMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.myProfile);
                              },
                            ),
                            _menuItem(
                              context: context,
                              icon: Icons.notifications_none_rounded,
                              label: copy.notificationsMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.notifications);
                              },
                            ),
                            _menuItem(
                              context: context,
                              icon: Icons.settings_outlined,
                              label: copy.settingsMenu,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.settings);
                              },
                            ),
                            const Spacer(),
                            const Divider(color: Color(0x14000000)),
                            _menuItem(
                              context: context,
                              icon: Icons.logout_rounded,
                              label: copy.logoutMenu,
                              danger: true,
                              onTap: () {
                                _signOut();
                              },
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

  Widget _menuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          child: Container(
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

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _pickupPoint = point;
      _pickupLabel = '';
      _isResolvingPickup = true;
    });
    _syncPickupMarker(moveCamera: false);
    final label = await _geocoding.reverse(point);
    if (!mounted) return;
    setState(() {
      _pickupLabel = label ?? _toLabel(point, 'Pickup');
      _isResolvingPickup = false;
    });
  }

  Future<void> _applyPickupSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _isResolvingPickup = true;
    });
    final result = await _geocoding.searchFirst(query);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _isResolvingPickup = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppCopy.of(context).locationNotFound)),
      );
      return;
    }
    setState(() {
      _pickupPoint = result.point;
      _pickupLabel = result.name;
      _isResolvingPickup = false;
    });
    _syncPickupMarker(moveCamera: true);
  }

  String _toLabel(LatLng point, String prefix) {
    return '$prefix: ${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
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

  Future<void> _detectMyLocation() async {
    if (_isDetectingLocation) return;

    setState(() {
      _isDetectingLocation = true;
    });

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
      await _updatePickupFromPosition(current, moveMap: true);

      await _locationSubscription?.cancel();
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 8,
            ),
          ).listen((position) {
            _updatePickupFromPosition(
              position,
              moveMap: true,
              showResolving: false,
            );
          });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to detect your location now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  Future<void> _updatePickupFromPosition(
    Position position, {
    required bool moveMap,
    bool showResolving = true,
  }) async {
    final point = LatLng(position.latitude, position.longitude);

    if (!mounted) return;
    setState(() {
      _pickupPoint = point;
      if (showResolving) {
        _pickupLabel = '';
        _isResolvingPickup = true;
      }
    });

    _syncPickupMarker(moveCamera: moveMap);

    final label = await _geocoding.reverse(point);
    if (!mounted) return;
    setState(() {
      _pickupLabel = label ?? _toLabel(point, 'Pickup');
      _isResolvingPickup = false;
    });
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.name,
    required this.email,
    required this.isLoading,
  });

  final String name;
  final String email;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Color(0xFFFFE7CB),
          child: Icon(Icons.person, color: Color(0xFFF68B1F), size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoading ? 'Loading profile...' : name,
                style: const TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(color: Color(0xFF757575), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
