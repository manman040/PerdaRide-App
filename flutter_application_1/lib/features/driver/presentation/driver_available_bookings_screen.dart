import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
import '../../booking/data/booking_repository.dart';

class DriverAvailableBookingsScreen extends StatefulWidget {
  const DriverAvailableBookingsScreen({super.key});

  @override
  State<DriverAvailableBookingsScreen> createState() =>
      _DriverAvailableBookingsScreenState();
}

class _DriverAvailableBookingsScreenState
    extends State<DriverAvailableBookingsScreen> {
  final _bookingRepository = BookingRepository();
  final _firebase = PerdaRideFirebase.instance;
  late final _authRepository = FirebaseAuthRepository(_firebase);
  late final _databaseRepository = FirebaseDatabaseRepository(_firebase);
  final Set<String> _rejectedBookingIds = <String>{};
  bool _isAccepting = false;
  bool _isDriverOnline = true;
  bool _isLoadingAvailability = true;
  String _driverPackageTier = 'Package A';

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isDriverOnline = false;
        _isLoadingAvailability = false;
      });
      return;
    }
    try {
      final snapshot = await _databaseRepository.getData('drivers/${user.uid}');
      final value = snapshot.value;
      bool online = true;
      String packageTier = _driverPackageTier;
      if (value is Map) {
        if (value['isAvailable'] is bool) {
          online = value['isAvailable'] as bool;
        }
        packageTier = _tierForCapacity(
          (value['passengerCapacity'] ?? '').toString(),
        );
      }
      if (!mounted) return;
      setState(() {
        _isDriverOnline = online;
        _driverPackageTier = packageTier;
        _isLoadingAvailability = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingAvailability = false;
      });
    }
  }

  String _tierForCapacity(String capacity) {
    final seats = int.tryParse(capacity) ?? 4;
    return seats > 4 ? 'Package B' : 'Package A';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: Text(
          copy.availableBookingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder(
        stream: _bookingRepository.watchAllBookings(),
        builder: (context, snapshot) {
          if (_isLoadingAvailability) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_isDriverOnline) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  copy.offlineBookingsMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          final bookings = _extractAvailableBookings(snapshot.data?.snapshot.value);
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (bookings.isEmpty) {
            return Center(
              child: Text(
                copy.noAvailableBookingsMessage,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = bookings[index];
              return _BookingCard(
                item: item,
                copy: copy,
                onSeeDetail: () => _showBookingDetail(context, item),
              );
            },
          );
        },
      ),
    );
  }

  List<DriverBookingItem> _extractAvailableBookings(Object? raw) {
    if (raw is! Map) return const [];
    final bookings = <DriverBookingItem>[];
    final currentDriverId = _authRepository.currentUser?.uid ?? '';

    raw.forEach((key, value) {
      if (value is! Map) return;

      final status = value['status']?.toString() ?? '';
      final driverId = value['driverId']?.toString() ?? '';
      if (status != 'pending') return;
      if (driverId.isNotEmpty) return;
      if (_rejectedBookingIds.contains(key.toString())) return;
      final rejectedByRaw = value['rejectedBy'];
      if (currentDriverId.isNotEmpty && rejectedByRaw is Map) {
        final rejectedForThisDriver = rejectedByRaw[currentDriverId];
        if (rejectedForThisDriver == true ||
            rejectedForThisDriver?.toString().toLowerCase() == 'true') {
          return;
        }
      }

      final pickupLat = _toDouble(value['pickupLat']);
      final pickupLng = _toDouble(value['pickupLng']);
      final dropoffLat = _toDouble(value['dropoffLat']);
      final dropoffLng = _toDouble(value['dropoffLng']);
      if (pickupLat == null ||
          pickupLng == null ||
          dropoffLat == null ||
          dropoffLng == null) {
        return;
      }

      final fare = _parseRm(value['fareLabel']);
      final pickupAddress = (value['pickupAddress'] ?? '').toString().trim();
      final dropoffAddress = (value['dropoffAddress'] ?? '').toString().trim();
      final distanceLabel = (value['distanceLabel'] ?? '').toString().trim();
      final packageLabel = (value['packageLabel'] ?? '').toString().trim();

      if (fare <= 0) return;
      if (!_isMeaningfulAddress(pickupAddress)) return;
      if (!_isMeaningfulAddress(dropoffAddress)) return;
      if (distanceLabel.isEmpty || distanceLabel == '-- km') return;
      if (packageLabel.isEmpty || packageLabel == '-') return;
      if (!packageLabel.startsWith(_driverPackageTier)) return;

      bookings.add(
        DriverBookingItem(
          bookingId: key.toString(),
          userId: (value['userId'] ?? '').toString(),
          priceLabel: 'RM${fare.toStringAsFixed(2)}',
          distanceLabel: distanceLabel,
          paymentMethod: value['paymentMethod']?.toString() ?? 'Cash',
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          packageLabel: packageLabel,
          pickupPoint: LatLng(pickupLat, pickupLng),
          dropoffPoint: LatLng(dropoffLat, dropoffLng),
        ),
      );
    });

    bookings.sort((a, b) => b.bookingId.compareTo(a.bookingId));
    return bookings;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _parseRm(dynamic rawFareLabel) {
    final text = (rawFareLabel ?? '').toString();
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  bool _isMeaningfulAddress(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower == '-' || lower == '--' || lower == 'n/a') return false;
    return true;
  }

  Future<void> _showBookingDetail(
    BuildContext context,
    DriverBookingItem item,
  ) async {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  copy.bookingDetailsTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.priceLabel,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DetailChip(text: item.distanceLabel),
                          _DetailChip(text: item.paymentMethod),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _detailRow(
                  context: context,
                  icon: Icons.trip_origin_rounded,
                  color: const Color(0xFF2E7D32),
                  title: copy.pickupHistoryLabel,
                  value: item.pickupAddress,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  context: context,
                  icon: Icons.place_rounded,
                  color: const Color(0xFFD84315),
                  title: copy.dropoffHistoryLabel,
                  value: item.dropoffAddress,
                ),
                const SizedBox(height: 10),
                Text(
                  item.packageLabel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop('reject'),
                        child: Text(copy.rejectCta),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isAccepting
                            ? null
                            : () => Navigator.of(context).pop('accept'),
                        child: Text(_isAccepting ? copy.acceptingCta : copy.acceptCta),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'reject') {
      setState(() {
        _rejectedBookingIds.add(item.bookingId);
      });
      final currentDriverId = _authRepository.currentUser?.uid;
      if (currentDriverId != null && currentDriverId.isNotEmpty) {
        await _databaseRepository.updateData(
          'bookings/${item.bookingId}/rejectedBy',
          {
            currentDriverId: true,
          },
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.bookingRejectedMessage)),
      );
      return;
    }

    if (action == 'accept') {
      await _acceptBooking(item);
    }
  }

  Future<void> _acceptBooking(DriverBookingItem item) async {
    final copy = AppCopy.of(context);
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.driverNotLoggedInMessage)),
      );
      return;
    }

    setState(() {
      _isAccepting = true;
    });

    try {
      final claimed = await _bookingRepository.tryAcceptBooking(
        bookingId: item.bookingId,
        driverId: user.uid,
      );
      if (!claimed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy.bookingAlreadyTakenMessage)),
        );
        return;
      }
      // Notification writes should not block accepted booking flow.
      try {
        if (item.userId.isNotEmpty) {
          await _databaseRepository.pushData('user_notifications/${item.userId}', {
            'title': 'Driver accepted your booking',
            'body': 'A driver is now heading to your pickup location.',
            'bookingId': item.bookingId,
            'read': false,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
        await _databaseRepository.pushData('driver_notifications/${user.uid}', {
          'title': 'Booking accepted',
          'body': 'You accepted a new booking.',
          'bookingId': item.bookingId,
          'read': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop(<String, dynamic>{
        'bookingId': item.bookingId,
        'pickupPoint': item.pickupPoint,
        'dropoffPoint': item.dropoffPoint,
        'pickupLabel': item.pickupAddress,
        'dropoffLabel': item.dropoffAddress,
        'distanceKm': item.distanceLabel,
        'paymentMethod': item.paymentMethod,
        'packageLabel': item.packageLabel,
        'priceLabel': item.priceLabel,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.acceptFailedError}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  Widget _detailRow({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.item,
    required this.copy,
    required this.onSeeDetail,
  });

  final DriverBookingItem item;
  final AppCopy copy;
  final VoidCallback onSeeDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.priceLabel,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(context, item.distanceLabel),
              _chip(context, item.paymentMethod),
            ],
          ),
          const SizedBox(height: 10),
          _addressRow(
            context: context,
            icon: Icons.trip_origin_rounded,
            color: const Color(0xFF2E7D32),
            text: item.pickupAddress,
          ),
          const SizedBox(height: 8),
          _addressRow(
            context: context,
            icon: Icons.place_rounded,
            color: const Color(0xFFD84315),
            text: item.dropoffAddress,
          ),
          const SizedBox(height: 9),
          Text(
            item.packageLabel,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSeeDetail,
              child: Text(copy.seeDetailBookingCta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _addressRow({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DriverBookingItem {
  DriverBookingItem({
    required this.bookingId,
    required this.userId,
    required this.priceLabel,
    required this.distanceLabel,
    required this.paymentMethod,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.packageLabel,
    required this.pickupPoint,
    required this.dropoffPoint,
  });

  final String bookingId;
  final String userId;
  final String priceLabel;
  final String distanceLabel;
  final String paymentMethod;
  final String pickupAddress;
  final String dropoffAddress;
  final String packageLabel;
  final LatLng pickupPoint;
  final LatLng dropoffPoint;
}
