import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
import '../../booking/data/booking_repository.dart';
import '../data/toyyibpay_service.dart';

class DriverTotalEarningScreen extends StatefulWidget {
  const DriverTotalEarningScreen({super.key});

  @override
  State<DriverTotalEarningScreen> createState() =>
      _DriverTotalEarningScreenState();
}

class _DriverTotalEarningScreenState extends State<DriverTotalEarningScreen> {
  final _bookingRepository = BookingRepository();
  final _firebase = PerdaRideFirebase.instance;
  late final _authRepository = FirebaseAuthRepository(_firebase);
  late final _databaseRepository = FirebaseDatabaseRepository(_firebase);
  final _toyyibPayService = ToyyibPayService();
  bool _isPayingAll = false;
  late int _selectedMonth = DateTime.now().month;
  late int _selectedYear = DateTime.now().year;
  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  List<_EarningRecord> _extractItems(DatabaseEvent event, String driverId) {
    final value = event.snapshot.value;
    if (value is! Map) return const [];

    final items = <_EarningRecord>[];
    for (final entry in value.entries) {
      final bookingId = entry.key?.toString() ?? '';
      final raw = entry.value;
      if (raw is! Map) continue;

      final status = (raw['status'] ?? '').toString().toLowerCase();
      final bookingDriverId = (raw['driverId'] ?? '').toString();
      if (status != 'completed' || bookingDriverId != driverId) continue;

      final fare = _parseRm(raw['fareLabel']);
      final pickupAddress = (raw['pickupAddress'] ?? '').toString().trim();
      final dropoffAddress = (raw['dropoffAddress'] ?? '').toString().trim();
      if (fare <= 0) continue;
      if (!_isMeaningfulAddress(pickupAddress)) continue;
      if (!_isMeaningfulAddress(dropoffAddress)) continue;

      items.add(
        _EarningRecord(
          bookingId: bookingId,
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          completedAt: _parseTimestamp(raw['updatedAt'] ?? raw['createdAt']),
          fare: fare,
          commission: fare * 0.2,
        ),
      );
    }

    items.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return items;
  }

  DateTime _parseTimestamp(dynamic raw) {
    if (raw is Map) {
      return _parseTimestamp(raw['time'] ?? raw['seconds']);
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.now();
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

  List<_EarningRecord> _applyFilter(List<_EarningRecord> items) {
    return items.where((item) {
      final d = item.completedAt;
      return d.year == _selectedYear && d.month == _selectedMonth;
    }).toList();
  }

  Set<String> _extractPaidBookingIds(Object? raw) {
    if (raw is! Map) return const {};

    // The backend writes the "paid" confirmation as its own record (keyed
    // only by billCode, no bookingIds) instead of updating the app's
    // original "pending" record (which does carry bookingIds). Bridge the
    // two by billCode so a paid confirmation anywhere in this driver's
    // payment history unlocks the matching pending record's bookings.
    final records = <Map>[];
    final paidBillCodes = <String>{};
    raw.forEach((_, value) {
      if (value is! Map) return;
      records.add(value);
      final status = (value['status'] ?? value['paymentStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (status == 'paid' || status == 'success' || status == 'completed') {
        final billCode = (value['billCode'] ?? '').toString();
        if (billCode.isNotEmpty) {
          paidBillCodes.add(billCode);
        }
      }
    });

    final paidBookingIds = <String>{};
    for (final value in records) {
      final status = (value['status'] ?? value['paymentStatus'] ?? '')
          .toString()
          .toLowerCase();
      final billCode = (value['billCode'] ?? '').toString();
      final isPaid = status == 'paid' ||
          status == 'success' ||
          status == 'completed' ||
          (billCode.isNotEmpty && paidBillCodes.contains(billCode));
      if (!isPaid) continue;

      final singleId = value['bookingId'];
      if (singleId is String && singleId.isNotEmpty) {
        paidBookingIds.add(singleId);
      }
      final batchIds = value['bookingIds'];
      if (batchIds is List) {
        for (final id in batchIds) {
          if (id is String && id.isNotEmpty) {
            paidBookingIds.add(id);
          }
        }
      }
    }
    return paidBookingIds;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final currentUser = _authRepository.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.totalEarningTitle),
      ),
      body: currentUser == null
          ? Center(child: Text(copy.pleaseLoginAsDriverMessage))
          : StreamBuilder<DatabaseEvent>(
              stream: _bookingRepository.watchAllBookings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('${copy.failedToLoadEarningsError}: ${snapshot.error}'),
                  );
                }

                final items = snapshot.hasData
                    ? _extractItems(snapshot.data!, currentUser.uid)
                    : const <_EarningRecord>[];
                final filteredItems = _applyFilter(items);
                final totalEarnings = filteredItems.fold<double>(
                  0,
                  (sum, item) => sum + item.fare,
                );
                final totalCommission = filteredItems.fold<double>(
                  0,
                  (sum, item) => sum + item.commission,
                );
                return StreamBuilder<DatabaseEvent>(
                  stream: _databaseRepository.watchPath(
                    'commission_payment/${currentUser.uid}',
                  ),
                  builder: (context, paymentSnapshot) {
                    final paidBookingIds = _extractPaidBookingIds(
                      paymentSnapshot.data?.snapshot.value,
                    );
                    final paidAmount = filteredItems
                        .where((item) => paidBookingIds.contains(item.bookingId))
                        .fold<double>(0, (sum, item) => sum + item.commission);
                    final outstandingCommission = filteredItems
                        .where(
                          (item) => !paidBookingIds.contains(item.bookingId),
                        )
                        .fold<double>(0, (sum, item) => sum + item.commission);
                    // Unlike outstandingCommission above, this ignores the
                    // month/year dropdown -- it's the driver's true overall
                    // unpaid balance, which is what the payment deadline
                    // should track. Using the filtered figure would let
                    // switching to a month with nothing outstanding wipe out
                    // a deadline for a real unpaid balance sitting in a
                    // different month.
                    final totalOutstandingCommission = items
                        .where(
                          (item) => !paidBookingIds.contains(item.bookingId),
                        )
                        .fold<double>(0, (sum, item) => sum + item.commission);
                    return StreamBuilder<DatabaseEvent>(
                      stream: _databaseRepository.watchPath(
                        'driver_commissions/${currentUser.uid}/payment_deadline',
                      ),
                      builder: (context, deadlineSnapshot) {
                        final deadline = _parseDeadline(
                          deadlineSnapshot.data?.snapshot.value,
                        );
                        final hasOutstanding = totalOutstandingCommission > 0;
                        if (_lastSyncedHasOutstanding != hasOutstanding) {
                          _lastSyncedHasOutstanding = hasOutstanding;
                          unawaited(
                            _syncPaymentDeadline(
                              driverId: currentUser.uid,
                              hasOutstandingCommission: hasOutstanding,
                            ),
                          );
                        }
                        return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      children: [
                        if (deadline != null && totalOutstandingCommission > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DeadlineBanner(deadline: deadline),
                          ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _dropdownField(
                                  context: context,
                                  label: copy.monthLabel,
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedMonth,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    items: List.generate(
                                      12,
                                      (index) => DropdownMenuItem(
                                        value: index + 1,
                                        child: Text(_months[index]),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        _selectedMonth = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _dropdownField(
                                  context: context,
                                  label: copy.yearLabel,
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedYear,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    items: _yearOptions()
                                        .map(
                                          (year) => DropdownMenuItem(
                                            value: year,
                                            child: Text('$year'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() {
                                        _selectedYear = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                copy.totalEarnedLabel,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'RM${totalEarnings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFF68B1F),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${filteredItems.length} ${copy.ridesLabel}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _summaryChip(
                                      context: context,
                                      title: copy.totalCommissionLabel,
                                      value:
                                          'RM${totalCommission.toStringAsFixed(2)}',
                                      valueColor: const Color(0xFFF68B1F),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _summaryChip(
                                      context: context,
                                      title: copy.outstandingLabel,
                                      value:
                                          'RM${outstandingCommission.toStringAsFixed(2)}',
                                      valueColor: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _summaryChip(
                                      context: context,
                                      title: copy.paidLabel,
                                      value: 'RM${paidAmount.toStringAsFixed(2)}',
                                      valueColor: const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isPayingAll ||
                                          filteredItems.isEmpty ||
                                          outstandingCommission <= 0
                                      ? null
                                      : () => _payAllCommission(
                                            totalCommission: outstandingCommission,
                                            items: filteredItems,
                                          ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    _isPayingAll
                                        ? copy.creatingBillCta
                                        : '${copy.payAllCommissionLabel} (RM${outstandingCommission.toStringAsFixed(2)})',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (filteredItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 36),
                            child: Center(
                              child: Text(copy.noEarningRecordsMessage),
                            ),
                          ),
                        ...filteredItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _EarningTripCard(
                              item: item,
                              theme: theme,
                              copy: copy,
                            ),
                          ),
                        ),
                      ],
                    );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  DateTime? _parseDeadline(Object? raw) {
    if (raw is! Map) return null;
    final time = raw['time'];
    if (time is num) return DateTime.fromMillisecondsSinceEpoch(time.toInt());
    return null;
  }

  // Tracks whether the driver had any unpaid commission the last time we
  // synced, so _syncPaymentDeadline only runs when that actually flips
  // instead of on every rebuild of the nested StreamBuilders above.
  bool? _lastSyncedHasOutstanding;

  /// Keeps `driver_commissions/{driverId}/payment_deadline` in lockstep with
  /// whether the driver currently owes any commission at all. Previously
  /// this was only ever *created*, never cleared -- so the first deadline a
  /// driver was ever given stuck around forever, silently governing every
  /// unrelated balance they'd owe for the rest of their time on the
  /// platform (pay it off, accrue a brand new unpaid ride next month, and
  /// the screen would still show the original stale/overdue date instead of
  /// a fresh 24h window).
  Future<void> _syncPaymentDeadline({
    required String driverId,
    required bool hasOutstandingCommission,
  }) async {
    try {
      final existing = await _databaseRepository.getData(
        'driver_commissions/$driverId/payment_deadline',
      );
      final hasDeadline = existing.value != null;
      if (hasOutstandingCommission && !hasDeadline) {
        final deadline = DateTime.now().add(const Duration(hours: 24));
        await _databaseRepository.updateData('driver_commissions/$driverId', {
          'payment_deadline': {
            'time': deadline.millisecondsSinceEpoch,
            'date': deadline.toIso8601String(),
            'set_by': 'auto',
            'set_at': DateTime.now().millisecondsSinceEpoch,
          },
        });
      } else if (!hasOutstandingCommission && hasDeadline) {
        await _databaseRepository.removePath(
          'driver_commissions/$driverId/payment_deadline',
        );
      }
    } catch (_) {}
  }

  Future<void> _payAllCommission({
    required double totalCommission,
    required List<_EarningRecord> items,
  }) async {
    if (_isPayingAll) return;
    final copy = AppCopy.of(context);
    setState(() {
      _isPayingAll = true;
    });
    try {
      final user = _authRepository.currentUser;
      if (user == null) throw Exception(copy.driverNotLoggedInError);
      final profile = await _loadDriverProfile(user.uid);
      final reference = _buildReference(user.uid, 'ALL');
      final result = await _toyyibPayService.createBill(
        driverId: user.uid,
        amount: totalCommission,
        reference: reference,
        driverName: profile.name,
        driverEmail: profile.email,
        driverPhone: profile.phone,
      );

      await _databaseRepository.pushData('commission_payment/${user.uid}', {
        'bookingIds': items.map((e) => e.bookingId).toList(),
        'amount': totalCommission,
        'reference': reference,
        'billCode': result.billCode,
        'status': 'pending',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      await _toyyibPayService.openPaymentPage(result.paymentUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.payAllFailedError}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPayingAll = false;
        });
      }
    }
  }

  Future<_DriverPayerProfile> _loadDriverProfile(String driverId) async {
    final driverSnap = await _databaseRepository.getData('drivers/$driverId');
    if (driverSnap.value is Map) {
      final map = driverSnap.value as Map;
      final name = (map['name'] ?? '').toString().trim();
      final email = (map['email'] ?? _authRepository.currentUser?.email ?? '')
          .toString()
          .trim();
      final phone = (map['phone'] ?? '').toString().trim();
      return _DriverPayerProfile(name: name, email: email, phone: phone);
    }
    return _DriverPayerProfile(
      name: 'Driver',
      email: _authRepository.currentUser?.email ?? '',
      phone: '',
    );
  }

  String _buildReference(String driverId, String suffix) {
    final short = driverId.substring(0, driverId.length > 8 ? 8 : driverId.length);
    final tail = DateTime.now().millisecondsSinceEpoch.toString();
    final compactSuffix = suffix.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return 'COMM-${short.toUpperCase()}-$compactSuffix-${tail.substring(tail.length - 6)}';
  }

  Widget _dropdownField({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  List<int> _yearOptions() {
    final nowYear = DateTime.now().year;
    final from = nowYear - 3;
    final to = nowYear + 1;
    return List<int>.generate(to - from + 1, (index) => from + index);
  }
}

class _EarningTripCard extends StatelessWidget {
  const _EarningTripCard({
    required this.item,
    required this.theme,
    required this.copy,
  });

  final _EarningRecord item;
  final ThemeData theme;
  final AppCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateLabel(item.completedAt),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _timeLabel(item.completedAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${item.pickupAddress} -> ${item.dropoffAddress}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM${item.fare.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFF68B1F),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${copy.commissionLabel}: RM${item.commission.toStringAsFixed(2)}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeadlineBanner extends StatelessWidget {
  const _DeadlineBanner({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isOverdue = DateTime.now().isAfter(deadline);
    final color = isOverdue ? const Color(0xFFD84315) : const Color(0xFFF68B1F);
    final background = color.withValues(alpha: 0.14);
    final whenLabel = '${_dateLabel(deadline)}, ${_timeLabel(deadline)}';
    final label = isOverdue
        ? '${copy.commissionOverdueMessage} $whenLabel'
        : '${copy.payCommissionByMessage} $whenLabel';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.warning_rounded : Icons.schedule_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _summaryChip({
  required BuildContext context,
  required String title,
  required String value,
  required Color valueColor,
}) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

String _dateLabel(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final ampm = date.hour >= 12 ? 'pm' : 'am';
  return '${hour.toString()}:${date.minute.toString().padLeft(2, '0')} $ampm';
}

class _EarningRecord {
  const _EarningRecord({
    required this.bookingId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.completedAt,
    required this.fare,
    required this.commission,
  });

  final String bookingId;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime completedAt;
  final double fare;
  final double commission;
}

class _DriverPayerProfile {
  const _DriverPayerProfile({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;
}
