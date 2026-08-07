import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/widgets/auth_gradient_scaffold.dart';

class DriverPendingApprovalScreen extends StatefulWidget {
  const DriverPendingApprovalScreen({super.key});

  @override
  State<DriverPendingApprovalScreen> createState() =>
      _DriverPendingApprovalScreenState();
}

class _DriverPendingApprovalScreenState
    extends State<DriverPendingApprovalScreen> {
  final _firebase = PerdaRideFirebase.instance;
  late final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(
    _firebase,
  );
  late final FirebaseDatabaseRepository _databaseRepository =
      FirebaseDatabaseRepository(_firebase);

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _status = 'pending';
  String? _adminNotes;

  @override
  void initState() {
    super.initState();
    _loadStatus(initial: true);
  }

  Future<void> _loadStatus({bool initial = false}) async {
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final driverSnapshot = await _databaseRepository.getData(
        'drivers/${user.uid}',
      );
      final driverValue = driverSnapshot.value;
      final rawStatus = driverValue is Map ? driverValue['registrationStatus'] : null;
      final status = (rawStatus?.toString() ?? 'approved').trim();

      String? adminNotes;
      if (status != 'approved') {
        final approvalSnapshot = await _databaseRepository.getData(
          'driver_approvals/${user.uid}',
        );
        final approvalValue = approvalSnapshot.value;
        if (approvalValue is Map) {
          // The admin panel writes the rejection explanation as
          // rejection_message/rejection_reason, not adminNotes -- check all
          // three so a rejection from the web admin panel is visible here too.
          for (final key in [
            'adminNotes',
            'rejection_message',
            'rejection_reason',
          ]) {
            final rawNotes = approvalValue[key];
            if (rawNotes is String && rawNotes.trim().isNotEmpty) {
              adminNotes = rawNotes.trim();
              break;
            }
          }
        }
      }

      if (!mounted) return;

      if (status.isEmpty || status == 'approved') {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRouter.driverDashboard, (route) => false);
        return;
      }

      setState(() {
        _status = status;
        _adminNotes = adminNotes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadStatus();
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _logOut() async {
    await _authRepository.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.welcome,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _status == 'rejected';

    return AuthGradientScaffold(
      header: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver',
            style: TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Registration Status',
            style: TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: rejected
                        ? const Color(0xFFFFEFE7)
                        : const Color(0xFFFFF3E6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: rejected
                          ? const Color(0xFFF4C7B5)
                          : const Color(0xFFF3C893),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        rejected
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded,
                        color: rejected
                            ? const Color(0xFFD96A43)
                            : const Color(0xFFF68B1F),
                        size: 40,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        rejected
                            ? 'Your registration was rejected'
                            : 'Your driver registration is under review',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D1B1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejected
                            ? (_adminNotes ??
                                  'Please contact support for more information.')
                            : 'Our admin team is reviewing your submitted documents. '
                                  'You will be able to access your driver dashboard once approved.',
                        style: const TextStyle(
                          height: 1.45,
                          color: Color(0xFF6A5541),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9B22), Color(0xFFF68B1F)],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _isRefreshing ? null : _refresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _isRefreshing ? 'Refreshing...' : 'Refresh Status',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _logOut,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    side: const BorderSide(color: Color(0xFFF2B067)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Log Out'),
                ),
              ],
            ),
    );
  }
}
