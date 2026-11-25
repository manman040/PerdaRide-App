import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
import '../../booking/data/booking_repository.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  final _bookingRepository = BookingRepository();
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  final _databaseRepository = FirebaseDatabaseRepository(PerdaRideFirebase.instance);
  final Map<String, String> _userNamesById = <String, String>{};
  final Set<String> _loadingUserIds = <String>{};
  final Map<String, int> _ratingsByBookingId = <String, int>{};
  final Map<String, String> _commentsByBookingId = <String, String>{};
  bool _ratingsLoaded = false;

  List<_DriverHistoryItem> _extractItems(
    DatabaseEvent event,
    String driverId,
    AppCopy copy,
  ) {
    final value = event.snapshot.value;
    if (value is! Map) return const [];

    final items = <_DriverHistoryItem>[];
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
        _DriverHistoryItem(
          bookingId: bookingId,
          userId: (raw['userId'] ?? '').toString(),
          passengerName: _resolvePassengerName(raw, copy),
          pickupAddress: pickupAddress,
          dropoffAddress: dropoffAddress,
          completedAt: _parseTimestamp(raw['updatedAt'] ?? raw['createdAt']),
          fare: fare,
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

  String _resolvePassengerName(Map raw, AppCopy copy) {
    final userName = (raw['userName'] ?? '').toString().trim();
    if (userName.isNotEmpty && userName != '-') return userName;
    final userEmail = (raw['userEmail'] ?? '').toString().trim();
    if (userEmail.isNotEmpty && userEmail != '-') return userEmail;
    return copy.unknownPassengerLabel;
  }

  String _passengerName(_DriverHistoryItem item, AppCopy copy) {
    final byUserId = _userNamesById[item.userId];
    if (byUserId != null && byUserId.trim().isNotEmpty) {
      return byUserId;
    }
    if (item.passengerName.trim().isNotEmpty &&
        item.passengerName != copy.unknownPassengerLabel) {
      return item.passengerName;
    }
    return copy.unknownPassengerLabel;
  }

  Future<void> _hydratePassengerNames(List<_DriverHistoryItem> items) async {
    for (final item in items) {
      final userId = item.userId.trim();
      if (userId.isEmpty) continue;
      if (_userNamesById.containsKey(userId)) continue;
      if (_loadingUserIds.contains(userId)) continue;

      _loadingUserIds.add(userId);
      try {
        final snapshot = await _databaseRepository.getData('users/$userId');
        final value = snapshot.value;
        if (value is Map) {
          final name = (value['name'] ?? '').toString().trim();
          if (name.isNotEmpty && mounted) {
            setState(() {
              _userNamesById[userId] = name;
            });
          }
        }
      } catch (_) {
        // Fallback to existing booking-level values.
      } finally {
        _loadingUserIds.remove(userId);
      }
    }
  }

  Future<void> _hydrateRatings(String driverId) async {
    if (_ratingsLoaded) return;
    _ratingsLoaded = true;
    try {
      final snapshot = await _databaseRepository.getData('ratings/$driverId');
      final value = snapshot.value;
      if (value is! Map) return;

      final ratings = <String, int>{};
      final comments = <String, String>{};
      for (final entry in value.entries) {
        final bookingId = entry.key?.toString() ?? '';
        final raw = entry.value;
        if (bookingId.isEmpty || raw is! Map) continue;

        final ratingRaw = raw['rating'];
        final rating = ratingRaw is int
            ? ratingRaw
            : int.tryParse(ratingRaw?.toString() ?? '');
        if (rating != null) {
          ratings[bookingId] = rating.clamp(0, 5);
        }

        final comment = (raw['comment'] ?? '').toString().trim();
        if (comment.isNotEmpty) {
          comments[bookingId] = comment;
        }
      }

      if (!mounted) return;
      setState(() {
        _ratingsByBookingId
          ..clear()
          ..addAll(ratings);
        _commentsByBookingId
          ..clear()
          ..addAll(comments);
      });
    } catch (_) {
      // Ignore and keep default empty stars.
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final currentUser = _authRepository.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: Text(
          copy.driverHistoryTitle,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
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
                    child: Text('${copy.failedToLoadHistoryError}: ${snapshot.error}'),
                  );
                }

                final items = snapshot.hasData
                    ? _extractItems(snapshot.data!, currentUser.uid, copy)
                    : const <_DriverHistoryItem>[];

                if (items.isEmpty) {
                  return Center(
                    child: Text(copy.noCompletedRidesMessage),
                  );
                }
                _hydratePassengerNames(items);
                _hydrateRatings(currentUser.uid);

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _passengerName(item, copy),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${copy.pickupHistoryLabel}: ${item.pickupAddress}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${copy.dropoffHistoryLabel}: ${item.dropoffAddress}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_dateLabel(item.completedAt)}, ${_timeLabel(item.completedAt)}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (starIndex) => Padding(
                                  padding: EdgeInsets.only(right: 2),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: starIndex <
                                            (_ratingsByBookingId[item.bookingId] ?? 0)
                                        ? const Color(0xFFF6A623)
                                        : const Color(0xFFC9C9C9),
                                    size: 24,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'RM${item.fare.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFF68B1F),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          if ((_commentsByBookingId[item.bookingId] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Comment: ${_commentsByBookingId[item.bookingId]}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
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
}

class _DriverHistoryItem {
  const _DriverHistoryItem({
    required this.bookingId,
    required this.userId,
    required this.passengerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.completedAt,
    required this.fare,
  });

  final String bookingId;
  final String userId;
  final String passengerName;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime completedAt;
  final double fare;
}
