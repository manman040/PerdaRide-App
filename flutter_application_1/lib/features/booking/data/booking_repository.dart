import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';

class BookingRepository {
  BookingRepository({
    FirebaseAuthRepository? authRepository,
    FirebaseDatabaseRepository? databaseRepository,
  }) : _authRepository =
           authRepository ?? FirebaseAuthRepository(PerdaRideFirebase.instance),
       _databaseRepository =
           databaseRepository ??
           FirebaseDatabaseRepository(PerdaRideFirebase.instance);

  final FirebaseAuthRepository _authRepository;
  final FirebaseDatabaseRepository _databaseRepository;

  /// A booking whose status hasn't moved in longer than this is treated as
  /// abandoned (app killed mid-ride, driver/rider walked away, etc.) rather
  /// than resumed forever -- see [_findActiveBooking].
  static const _staleActiveBookingAge = Duration(hours: 3);

  Future<String> createBooking({
    required LatLng pickupPoint,
    required String pickupLabel,
    required LatLng dropoffPoint,
    required String dropoffLabel,
    required String paymentMethod,
    required String packageLabel,
    required String fareLabel,
    required String distanceLabel,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      throw StateError('User is not logged in.');
    }

    // The rider's display details are copied onto the booking. The database
    // rules keep users/{uid} private to its owner (it holds IC numbers and
    // phone numbers), so the driver can no longer look the rider up by id --
    // the history/active-ride screens read these fields off the booking.
    var userName = '';
    var userEmail = user.email ?? '';
    var userPhone = '';
    try {
      final profile = await _databaseRepository.getData('users/${user.uid}');
      final value = profile.value;
      if (value is Map) {
        userName = (value['name'] ?? '').toString().trim();
        final email = (value['email'] ?? '').toString().trim();
        if (email.isNotEmpty) userEmail = email;
        userPhone = (value['phone'] ?? '').toString().trim();
      }
    } catch (_) {}

    final now = DateTime.now().millisecondsSinceEpoch;
    final estimatedFare = _parseFare(fareLabel);
    final distanceKm = _parseDistance(distanceLabel);
    final data = <String, dynamic>{
      'userId': user.uid,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'pickupAddress': pickupLabel,
      'pickupLocation': pickupLabel,
      'pickupLat': pickupPoint.latitude,
      'pickupLng': pickupPoint.longitude,
      'dropoffAddress': dropoffLabel,
      'dropoffLocation': dropoffLabel,
      'dropoffLat': dropoffPoint.latitude,
      'dropoffLng': dropoffPoint.longitude,
      'paymentMethod': paymentMethod,
      'packageLabel': packageLabel,
      'fareLabel': fareLabel,
      'estimatedFare': estimatedFare,
      'distanceLabel': distanceLabel,
      'distanceKm': distanceKm,
      'status': 'pending',
      'driverId': '',
      'createdAt': now,
      'updatedAt': now,
    };

    return _databaseRepository.pushData('bookings', data);
  }

  Stream<DatabaseEvent> watchBooking(String bookingId) {
    return _databaseRepository.watchPath('bookings/$bookingId');
  }

  Stream<DatabaseEvent> watchAllBookings() {
    return _databaseRepository.watchPath('bookings');
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
    String? driverId,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (driverId != null) {
      payload['driverId'] = driverId;
    }
    await _databaseRepository.updateData('bookings/$bookingId', payload);
  }

  /// Atomically claims a still-pending booking for [driverId]. A plain
  /// `update()` (what [updateBookingStatus] does) has no way to check the
  /// booking is still unclaimed before writing, so two drivers tapping
  /// Accept on the same booking within the same instant could both get
  /// routed to the active-ride screen for it, with whichever write lands
  /// last silently overwriting the other's assignment. This runs as a
  /// Firebase transaction instead, so only the first caller to see
  /// status == 'pending' with no driverId wins; returns false (writing
  /// nothing) for everyone else.
  Future<bool> tryAcceptBooking({
    required String bookingId,
    required String driverId,
  }) async {
    final result = await _databaseRepository.runTransaction(
      'bookings/$bookingId',
      (Object? currentData) {
        if (currentData is! Map) return Transaction.abort();
        final status = (currentData['status'] ?? '').toString();
        final existingDriverId = (currentData['driverId'] ?? '').toString();
        if (status != 'pending' || existingDriverId.isNotEmpty) {
          return Transaction.abort();
        }
        final updated = Map<String, dynamic>.from(currentData);
        updated['status'] = 'accepted';
        updated['driverId'] = driverId;
        updated['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
        return Transaction.success(updated);
      },
    );
    return result.committed;
  }

  Future<void> updateBookingDetails({
    required String bookingId,
    required String paymentMethod,
    required String packageLabel,
    required String fareLabel,
    required String distanceLabel,
  }) async {
    await _databaseRepository.updateData('bookings/$bookingId', {
      'paymentMethod': paymentMethod,
      'packageLabel': packageLabel,
      'fareLabel': fareLabel,
      'estimatedFare': _parseFare(fareLabel),
      'distanceLabel': distanceLabel,
      'distanceKm': _parseDistance(distanceLabel),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Fallbacks matching the admin dashboard's own documented defaults --
  /// used only if `fareSettings/$category` hasn't been saved yet (fresh
  /// install) or the read fails, never as the source of truth. The admin
  /// dashboard (Fare Settings page) is what actually controls pricing.
  static const _fareSettingsDefaults = <String, FareSettings>{
    'categoryA': FareSettings(baseFare: 2.0, perKm: 1.2, bookingFee: 1.0),
    'categoryB': FareSettings(baseFare: 3.0, perKm: 1.5, bookingFee: 1.0),
  };

  /// Reads the admin-configured rates for [category] ('categoryA' or
  /// 'categoryB') from `fareSettings/$category`.
  Future<FareSettings> getFareSettings(String category) async {
    final fallback =
        _fareSettingsDefaults[category] ?? _fareSettingsDefaults['categoryA']!;
    try {
      final snapshot = await _databaseRepository.getData(
        'fareSettings/$category',
      );
      final value = snapshot.value;
      if (value is! Map) return fallback;
      return FareSettings(
        baseFare: _toDouble(value['baseFare']) ?? fallback.baseFare,
        perKm: _toDouble(value['perKm']) ?? fallback.perKm,
        bookingFee: _toDouble(value['bookingFee']) ?? fallback.bookingFee,
      );
    } catch (_) {
      return fallback;
    }
  }

  Stream<DatabaseEvent> watchChatMessages(String bookingId) {
    return _databaseRepository.watchPath('booking_chats/$bookingId/messages');
  }

  Future<void> postChatMessage({
    required String bookingId,
    required String senderRole,
    required String message,
  }) async {
    final user = _authRepository.currentUser;
    if (user == null) throw StateError('User is not logged in.');
    await _databaseRepository.pushData('booking_chats/$bookingId/messages', {
      'senderId': user.uid,
      'senderRole': senderRole,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  double _parseFare(String fareLabel) {
    final cleaned = fareLabel.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  double _parseDistance(String distanceLabel) {
    final cleaned = distanceLabel.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Finds the rider's own in-progress booking (if any), so the app can
  /// resume straight into the tracking screen after being closed/killed
  /// instead of dropping the rider back at a blank dashboard.
  Future<ActiveBookingSummary?> findActiveBookingForRider(String userId) {
    const activeStatuses = {
      'pending',
      'accepted',
      'arrived_pickup',
      'in_progress',
    };
    return _findActiveBooking(
      matches: (data) =>
          (data['userId'] ?? '').toString() == userId &&
          activeStatuses.contains((data['status'] ?? '').toString()),
    );
  }

  /// Same idea for a driver with a ride they've already accepted.
  Future<ActiveBookingSummary?> findActiveBookingForDriver(String driverId) {
    const activeStatuses = {'accepted', 'arrived_pickup', 'in_progress'};
    return _findActiveBooking(
      matches: (data) =>
          (data['driverId'] ?? '').toString() == driverId &&
          activeStatuses.contains((data['status'] ?? '').toString()),
    );
  }

  Future<ActiveBookingSummary?> _findActiveBooking({
    required bool Function(Map data) matches,
  }) async {
    final snapshot = await _databaseRepository.getData('bookings');
    final value = snapshot.value;
    if (value is! Map) return null;

    String? bestKey;
    Map? bestData;
    var bestUpdatedAt = -1;
    value.forEach((key, raw) {
      if (raw is! Map) return;
      if (!matches(raw)) return;
      final updatedAt = _toInt(raw['updatedAt'] ?? raw['createdAt']);
      if (bestData == null || updatedAt > bestUpdatedAt) {
        bestKey = key.toString();
        bestData = raw;
        bestUpdatedAt = updatedAt;
      }
    });

    final key = bestKey;
    final data = bestData;
    if (key == null || data == null) return null;

    // A ride that hasn't been touched in hours is almost certainly abandoned
    // (app killed mid-ride, driver/rider force-closed instead of pressing
    // Cancel, etc). Without this, the splash screen would keep resuming into
    // it forever since its status alone never stops looking "active". Mark
    // it cancelled so it also drops out of job/earnings lists instead of
    // lingering, then fall through as if there were no active ride.
    final age = DateTime.now().millisecondsSinceEpoch - bestUpdatedAt;
    if (bestUpdatedAt <= 0 || age > _staleActiveBookingAge.inMilliseconds) {
      unawaited(updateBookingStatus(bookingId: key, status: 'cancelled'));
      return null;
    }

    final pickupLat = _toDouble(data['pickupLat']);
    final pickupLng = _toDouble(data['pickupLng']);
    final dropoffLat = _toDouble(data['dropoffLat']);
    final dropoffLng = _toDouble(data['dropoffLng']);
    if (pickupLat == null ||
        pickupLng == null ||
        dropoffLat == null ||
        dropoffLng == null) {
      return null;
    }

    return ActiveBookingSummary(
      bookingId: key,
      status: (data['status'] ?? '').toString(),
      pickupPoint: LatLng(pickupLat, pickupLng),
      pickupLabel: (data['pickupAddress'] ?? data['pickupLocation'] ?? '')
          .toString(),
      dropoffPoint: LatLng(dropoffLat, dropoffLng),
      dropoffLabel: (data['dropoffAddress'] ?? data['dropoffLocation'] ?? '')
          .toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      packageLabel: (data['packageLabel'] ?? '').toString(),
      fareLabel: (data['fareLabel'] ?? '').toString(),
      distanceLabel: (data['distanceLabel'] ?? '').toString(),
    );
  }

  /// The rider's finished rides (completed or cancelled), newest first, for
  /// the Ride History section of the profile screen. Uses the userId index
  /// so only this rider's bookings are fetched.
  Future<List<RiderRideRecord>> fetchRiderRideHistory(String userId) async {
    final snapshot = await _databaseRepository.queryEqualTo(
      'bookings',
      'userId',
      userId,
    );
    final value = snapshot.value;
    if (value is! Map) return const [];

    final records = <RiderRideRecord>[];
    value.forEach((key, raw) {
      if (raw is! Map) return;
      final status = (raw['status'] ?? '').toString().toLowerCase();
      if (status != 'completed' && status != 'cancelled') return;

      final fareLabel = (raw['fareLabel'] ?? '').toString();
      final fare = _toDouble(raw['estimatedFare']) ?? _parseFare(fareLabel);
      final timestamp = _toInt(
        raw['completedAt'] ?? raw['updatedAt'] ?? raw['createdAt'],
      );
      records.add(
        RiderRideRecord(
          bookingId: key.toString(),
          status: status,
          pickupLabel: (raw['pickupAddress'] ?? raw['pickupLocation'] ?? '')
              .toString()
              .trim(),
          dropoffLabel: (raw['dropoffAddress'] ?? raw['dropoffLocation'] ?? '')
              .toString()
              .trim(),
          driverId: (raw['driverId'] ?? '').toString().trim(),
          fare: fare,
          packageLabel: (raw['packageLabel'] ?? '').toString(),
          paymentMethod: (raw['paymentMethod'] ?? '').toString(),
          rating: _toInt(raw['rating']),
          completedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        ),
      );
    });

    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return records;
  }

  /// Name and vehicle of one driver, for display next to a ride. Returns
  /// null when the record is missing or unreadable.
  Future<DriverSummary?> fetchDriverSummary(String driverId) async {
    if (driverId.isEmpty) return null;
    try {
      final snapshot = await _databaseRepository.getData('drivers/$driverId');
      final value = snapshot.value;
      if (value is! Map) return null;
      final brand = (value['vehicleBrand'] ?? '').toString().trim();
      final model = (value['vehicleModel'] ?? '').toString().trim();
      final plate =
          (value['plateNumber'] ??
                  value['carPlateNumber'] ??
                  value['vehiclePlate'] ??
                  '')
              .toString()
              .trim();
      final vehicle = [brand, model].where((e) => e.isNotEmpty).join(' ');
      return DriverSummary(
        name: (value['name'] ?? '').toString().trim(),
        vehicleLabel: [vehicle, plate].where((e) => e.isNotEmpty).join(' · '),
        plateNumber: plate,
      );
    } catch (_) {
      return null;
    }
  }

  int _toInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Admin-configured rates for one ride category ("Category A" / "Category
/// B" in the admin dashboard). See [BookingRepository.getFareSettings].
class FareSettings {
  const FareSettings({
    required this.baseFare,
    required this.perKm,
    required this.bookingFee,
  });

  final double baseFare;
  final double perKm;
  final double bookingFee;

  /// Total Fare = Base Fare + (Distance in KM x Price Per KM) + Booking Fee.
  double totalFor(double distanceKm) =>
      baseFare + (distanceKm * perKm) + bookingFee;
}

class ActiveBookingSummary {
  const ActiveBookingSummary({
    required this.bookingId,
    required this.status,
    required this.pickupPoint,
    required this.pickupLabel,
    required this.dropoffPoint,
    required this.dropoffLabel,
    required this.paymentMethod,
    required this.packageLabel,
    required this.fareLabel,
    required this.distanceLabel,
  });

  final String bookingId;
  final String status;
  final LatLng pickupPoint;
  final String pickupLabel;
  final LatLng dropoffPoint;
  final String dropoffLabel;
  final String paymentMethod;
  final String packageLabel;
  final String fareLabel;
  final String distanceLabel;
}

/// One finished ride as listed in the rider's profile history.
class RiderRideRecord {
  const RiderRideRecord({
    required this.bookingId,
    required this.status,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.driverId,
    required this.fare,
    required this.packageLabel,
    required this.paymentMethod,
    required this.rating,
    required this.completedAt,
  });

  final String bookingId;

  /// 'completed' or 'cancelled'.
  final String status;
  final String pickupLabel;
  final String dropoffLabel;
  final String driverId;
  final double fare;
  final String packageLabel;
  final String paymentMethod;

  /// 1-5 once the rider has rated the ride, otherwise 0.
  final int rating;
  final DateTime completedAt;

  bool get isCompleted => status == 'completed';

  bool get hasDate => completedAt.millisecondsSinceEpoch > 0;

  String get priceLabel => 'RM ${fare.toStringAsFixed(2)}';
}

/// The few driver fields shown next to a ride in the history.
class DriverSummary {
  const DriverSummary({
    required this.name,
    required this.vehicleLabel,
    required this.plateNumber,
  });

  final String name;

  /// "Brand Model · PLATE", or empty when nothing is known.
  final String vehicleLabel;
  final String plateNumber;
}
