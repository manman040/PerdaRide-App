import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/widgets/app_shell.dart';

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

      if (driverSnapshot.exists) {
        final driverValue = driverSnapshot.value;
        final rawStatus = driverValue is Map
            ? driverValue['registrationStatus']
            : null;
        final status = (rawStatus?.toString() ?? 'approved').trim();
        if (status.isEmpty || status == 'approved') {
          Navigator.of(
            context,
          ).pushReplacementNamed(AppRouter.driverDashboard);
        } else {
          Navigator.of(
            context,
          ).pushReplacementNamed(AppRouter.driverPendingApproval);
        }
        return;
      }

      if (usersSnapshot.exists) {
        Navigator.of(context).pushReplacementNamed(AppRouter.userDashboard);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRouter.welcome);
  }

  @override
  Widget build(BuildContext context) {
    return const AppShell(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
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
                      'PerdaRide',
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
            SizedBox(height: 20),
            Text('Passenger and driver services in one app.'),
          ],
        ),
      ),
    );
  }
}
