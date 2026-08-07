import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';

class BookingRepository {
  BookingRepository({
    FirebaseAuthRepository? authRepository,
    FirebaseDatabaseRepository? databaseRepository,
  })  : _authRepository =
            authRepository ?? FirebaseAuthRepository(PerdaRideFirebase.instance),
        _databaseRepository = databaseRepository ??
            FirebaseDatabaseRepository(PerdaRideFirebase.instance);

  final FirebaseAuthRepository _authRepository;
  final FirebaseDatabaseRepository _databaseRepository;

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

    final now = DateTime.now().millisecondsSinceEpoch;
    final estimatedFare = _parseFare(fareLabel);
    final distanceKm = _parseDistance(distanceLabel);
    final data = <String, dynamic>{
      'userId': user.uid,
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
}
