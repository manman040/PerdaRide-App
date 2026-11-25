import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/firebase/account_status.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/app_shell.dart';
import '../../booking/data/booking_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _firebase = PerdaRideFirebase.instance;
  late final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(
    _firebase,
  );
  late final FirebaseDatabaseRepository _databaseRepository =
      FirebaseDatabaseRepository(_firebase);
  final _bookingRepository = BookingRepository();

  @override
  void initState() {
    super.initState();
    _routeNext();
  }

  Future<void> _routeNext() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = _authRepository.currentUser;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRouter.welcome);
      return;
    }

    try {
      final driverSnapshot = await _databaseRepository.getData(
        'drivers/${user.uid}',
      );
      final usersSnapshot = await _databaseRepository.getData(
        'users/${user.uid}',
      );
      if (!mounted) return;

      // Disabled by the admin: sign out and explain on the login screen.
      if (AccountStatus.isDisabled(driverSnapshot.value) ||
          AccountStatus.isDisabled(usersSnapshot.value)) {
        final notice = AppCopy.of(context).accountDisabledError;
        await _authRepository.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          AppRouter.login,
          arguments: <String, dynamic>{'notice': notice},
        );
        return;
      }

      if (driverSnapshot.exists) {
        final driverValue = driverSnapshot.value;
        final rawStatus = driverValue is Map
            ? driverValue['registrationStatus']
            : null;
        final status = (rawStatus?.toString() ?? 'approved').trim();
        if (status.isEmpty || status == 'approved') {
          final activeRide = await _bookingRepository.findActiveBookingForDriver(
            user.uid,
          );
          if (!mounted) return;
          if (activeRide != null) {
            Navigator.of(context).pushReplacementNamed(
              AppRouter.driverActiveRide,
              arguments: <String, dynamic>{
                'bookingId': activeRide.bookingId,
                'pickupPoint': activeRide.pickupPoint,
                'pickupLabel': activeRide.pickupLabel,
                'dropoffPoint': activeRide.dropoffPoint,
                'dropoffLabel': activeRide.dropoffLabel,
                'paymentMethod': activeRide.paymentMethod,
                'packageLabel': activeRide.packageLabel,
                'priceLabel': activeRide.fareLabel,
                'distanceKm': activeRide.distanceLabel,
              },
            );
          } else {
            Navigator.of(
              context,
            ).pushReplacementNamed(AppRouter.driverDashboard);
          }
        } else {
          Navigator.of(
            context,
          ).pushReplacementNamed(AppRouter.driverPendingApproval);
        }
        return;
      }

      if (usersSnapshot.exists) {
        final activeBooking = await _bookingRepository.findActiveBookingForRider(
          user.uid,
        );
        if (!mounted) return;
        if (activeBooking != null) {
          Navigator.of(context).pushReplacementNamed(
            AppRouter.userBookingStatus,
            arguments: <String, dynamic>{
              'bookingId': activeBooking.bookingId,
              'pickupPoint': activeBooking.pickupPoint,
              'pickupLabel': activeBooking.pickupLabel,
              'dropoffPoint': activeBooking.dropoffPoint,
              'dropoffLabel': activeBooking.dropoffLabel,
              'paymentMethod': activeBooking.paymentMethod,
              'packageLabel': activeBooking.packageLabel,
              'fareLabel': activeBooking.fareLabel,
            },
          );
        } else {
          Navigator.of(context).pushReplacementNamed(AppRouter.userDashboard);
        }
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRouter.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return AppShell(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_taxi_rounded,
                      size: 56,
                      color: Color(0xFFF68B1F),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Urban Drive',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF68B1F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(copy.splashTagline),
          ],
        ),
      ),
    );
  }
}
