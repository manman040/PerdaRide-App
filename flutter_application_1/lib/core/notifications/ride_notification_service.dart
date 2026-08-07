import '../firebase/firebase_database_repository.dart';
import '../firebase/perdaride_firebase.dart';

class RideNotificationService {
  RideNotificationService._();

  static final RideNotificationService instance = RideNotificationService._();

  final _databaseRepository = FirebaseDatabaseRepository(
    PerdaRideFirebase.instance,
  );

  Future<void> notify({
    required String uid,
    required bool isDriver,
    required String title,
    required String body,
    String? bookingId,
  }) async {
    if (uid.trim().isEmpty) return;
    final path = isDriver ? 'driver_notifications/$uid' : 'user_notifications/$uid';
    try {
      await _databaseRepository.pushData(path, {
        'title': title,
        'body': body,
        if (bookingId != null) 'bookingId': bookingId,
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}
