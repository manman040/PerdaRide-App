import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
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
  List<String> _rejectedDocuments = const [];
  String? _rejectionReason;
  String? _rejectionMessage;

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
      List<String> rejectedDocuments = const [];
      String? rejectionReason;
      String? rejectionMessage;
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
          rejectedDocuments = _extractRejectedDocuments(approvalValue);
          final rawReason = approvalValue['rejection_reason'];
          if (rawReason is String && rawReason.trim().isNotEmpty) {
            rejectionReason = rawReason.trim();
          }
          final rawMessage = approvalValue['rejection_message'];
          if (rawMessage is String && rawMessage.trim().isNotEmpty) {
            rejectionMessage = rawMessage.trim();
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
        _rejectedDocuments = rejectedDocuments;
        _rejectionReason = rejectionReason;
        _rejectionMessage = rejectionMessage;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// The admin backend writes rejected-document info three different ways
  /// depending on when/how the reject happened -- prefer the explicit
  /// `rejected_documents` array, fall back to `document_decisions`, then to
  /// the individual `xRejected` booleans (the oldest/legacy format).
  List<String> _extractRejectedDocuments(Map approvalValue) {
    final rawList = approvalValue['rejected_documents'];
    if (rawList is List) {
      final docs = rawList
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (docs.isNotEmpty) return docs;
    }

    final decisions = approvalValue['document_decisions'];
    if (decisions is Map) {
      final docs = decisions.entries
          .where(
            (entry) => entry.value?.toString().toLowerCase() == 'rejected',
          )
          .map((entry) => entry.key.toString())
          .toList();
      if (docs.isNotEmpty) return docs;
    }

    const flagToDocType = {
      'idCardRejected': 'idCard',
      'licenseRejected': 'license',
      'carGrantRejected': 'carGrant',
      'carImageRejected': 'carImage',
    };
    final docs = <String>[];
    flagToDocType.forEach((flag, docType) {
      if (approvalValue[flag] == true) docs.add(docType);
    });
    return docs;
  }

  void _goToFixDocuments() {
    Navigator.of(context)
        .pushNamed(
          AppRouter.driverDocumentResubmit,
          arguments: {
            'rejectedDocuments': _rejectedDocuments,
            'rejectionReason': _rejectionReason,
            'rejectionMessage': _rejectionMessage,
          },
        )
        .then((_) => _refresh());
  }

  String _docTypeLabel(AppCopy copy, String docType) {
    switch (docType) {
      case 'idCard':
        return copy.idCardDocLabel;
      case 'license':
        return copy.licenseDocLabel;
      case 'carGrant':
        return copy.carGrantDocLabel;
      case 'carImage':
        return copy.carImageDocLabel;
      default:
        return docType;
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
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    final rejected = _status == 'rejected';
    final needsResubmission = _status == 'waiting_for_resubmission';
    final statusAccent = (rejected || needsResubmission)
        ? const Color(0xFFD96A43)
        : const Color(0xFFF68B1F);

    return AuthGradientScaffold(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.driverRole,
            style: const TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copy.registrationStatusTitle,
            style: const TextStyle(
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
                    color: statusAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        needsResubmission
                            ? Icons.upload_file_rounded
                            : rejected
                            ? Icons.cancel_rounded
                            : Icons.hourglass_top_rounded,
                        color: statusAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        needsResubmission
                            ? copy.resubmissionNeededTitle
                            : rejected
                            ? copy.registrationRejectedTitle
                            : copy.registrationUnderReviewTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        needsResubmission
                            ? (_rejectionMessage ??
                                  _adminNotes ??
                                  copy.resubmissionNeededDescription)
                            : rejected
                            ? (_adminNotes ?? copy.contactSupportMessage)
                            : copy.registrationReviewDescription,
                        style: TextStyle(
                          height: 1.45,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (needsResubmission &&
                          _rejectedDocuments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        for (final docType in _rejectedDocuments)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 16,
                                  color: statusAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _docTypeLabel(copy, docType),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (needsResubmission) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9B22), Color(0xFFF68B1F)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _goToFixDocuments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(copy.fixDocumentsCta),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                      _isRefreshing ? copy.refreshingCta : copy.refreshStatusCta,
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
                  child: Text(copy.logOutCta),
                ),
              ],
            ),
    );
  }
}
