import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.isDriver});

  /// Which notification feed to show -- decided by which dashboard the user
  /// navigated from, not guessed from Firebase data. A single account can
  /// have both a `users/{uid}` and a `drivers/{uid}` record (e.g. a
  /// passenger who also drives), so inferring the role from which of those
  /// records exists mixed up driver- and passenger-targeted notifications
  /// on the same screen.
  final bool isDriver;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _firebase = PerdaRideFirebase.instance;
  late final _authRepository = FirebaseAuthRepository(_firebase);
  late final _databaseRepository = FirebaseDatabaseRepository(_firebase);
  late final String _notificationPath = _resolveNotificationPath();

  String _resolveNotificationPath() {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return '';
    return widget.isDriver ? 'driver_notifications/$uid' : 'user_notifications/$uid';
  }

  Future<void> _markRead(String id) async {
    if (_notificationPath.isEmpty) return;
    try {
      await _databaseRepository.updateData('$_notificationPath/$id', {
        'read': true,
      });
    } catch (_) {}
  }

  Future<void> _markAllRead(List<_NotificationItem> items) async {
    for (final item in items.where((item) => !item.read)) {
      unawaited(_markRead(item.id));
    }
  }

  /// Tapping a notification used to only mark it read -- it stores a
  /// bookingId but nothing ever used it, so "Driver has arrived" or "New
  /// message from driver" led nowhere. This looks the booking up and, if
  /// it's still live, opens the same tracking screen the dashboard would
  /// resume into. Finished/cancelled rides (or a booking that's gone) have
  /// no tracking screen to show, so those just mark read like before.
  Future<void> _openNotification(_NotificationItem item) async {
    if (!item.read) {
      unawaited(_markRead(item.id));
    }
    final bookingId = item.bookingId;
    if (bookingId == null || bookingId.isEmpty) return;

    try {
      final snapshot = await _databaseRepository.getData(
        'bookings/$bookingId',
      );
      final value = snapshot.value;
      if (value is! Map || !mounted) return;

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

      final status = (value['status'] ?? '').toString();
      final pickupPoint = LatLng(pickupLat, pickupLng);
      final dropoffPoint = LatLng(dropoffLat, dropoffLng);
      final pickupLabel =
          (value['pickupAddress'] ?? value['pickupLocation'] ?? '')
              .toString();
      final dropoffLabel =
          (value['dropoffAddress'] ?? value['dropoffLocation'] ?? '')
              .toString();
      final paymentMethod = (value['paymentMethod'] ?? '').toString();
      final packageLabel = (value['packageLabel'] ?? '').toString();
      final fareLabel = (value['fareLabel'] ?? '').toString();
      final distanceLabel = (value['distanceLabel'] ?? '').toString();

      if (widget.isDriver) {
        const liveStatuses = {'accepted', 'arrived_pickup', 'in_progress'};
        if (!liveStatuses.contains(status)) return;
        Navigator.of(context).pushNamed(
          AppRouter.driverActiveRide,
          arguments: <String, dynamic>{
            'bookingId': bookingId,
            'pickupPoint': pickupPoint,
            'pickupLabel': pickupLabel,
            'dropoffPoint': dropoffPoint,
            'dropoffLabel': dropoffLabel,
            'paymentMethod': paymentMethod,
            'packageLabel': packageLabel,
            'priceLabel': fareLabel,
            'distanceKm': distanceLabel,
          },
        );
      } else {
        const liveStatuses = {
          'pending',
          'accepted',
          'arrived_pickup',
          'in_progress',
        };
        if (!liveStatuses.contains(status)) return;
        Navigator.of(context).pushNamed(
          AppRouter.userBookingStatus,
          arguments: <String, dynamic>{
            'bookingId': bookingId,
            'pickupPoint': pickupPoint,
            'pickupLabel': pickupLabel,
            'dropoffPoint': dropoffPoint,
            'dropoffLabel': dropoffLabel,
            'paymentMethod': paymentMethod,
            'packageLabel': packageLabel,
            'fareLabel': fareLabel,
          },
        );
      }
    } catch (_) {}
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<DatabaseEvent>(
              stream: _notificationPath.isEmpty
                  ? null
                  : _databaseRepository.watchPath(_notificationPath),
              builder: (context, snapshot) {
                final items = _mapNotifications(snapshot.data?.snapshot.value);
                final unreadCount = items.where((item) => !item.read).length;

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      title: Text(copy.notificationsTitle),
                      actions: [
                        if (unreadCount > 0)
                          TextButton(
                            onPressed: () => _markAllRead(items),
                            child: Text(
                              copy.markAllRead,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(18),
                      sliver: items.isEmpty
                          ? SliverToBoxAdapter(
                              child: _emptyState(theme, colorScheme, copy),
                            )
                          : SliverList.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _NotificationTile(
                                  item: item,
                                  onTap: () => _openNotification(item),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme colorScheme, AppCopy copy) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(copy.noNotificationsTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(copy.noNotificationsDescription, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  List<_NotificationItem> _mapNotifications(Object? raw) {
    if (raw is! Map) return const [];
    final items = <_NotificationItem>[];
    raw.forEach((key, value) {
      if (value is! Map) return;
      final title = (value['title'] ?? '').toString().trim();
      final body = (value['body'] ?? value['message'] ?? '').toString().trim();
      final timestamp = _parseTimestamp(value['createdAt'] ?? value['timestamp']);
      if (title.isEmpty && body.isEmpty) return;
      final bookingId = value['bookingId']?.toString();
      items.add(
        _NotificationItem(
          id: key.toString(),
          title: title.isEmpty ? 'Notification' : title,
          body: body,
          createdAt: timestamp ?? DateTime.now(),
          read: value['read'] == true,
          bookingId: (bookingId == null || bookingId.isEmpty)
              ? null
              : bookingId,
        ),
      );
    });
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw is Map) {
      return _parseTimestamp(raw['time'] ?? raw['seconds']);
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.tryParse(raw);
    }
    return null;
  }
}

enum _NotificationKind { accepted, arrived, started, completed, cancelled, chat, general }

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final _NotificationItem item;
  final VoidCallback onTap;

  _NotificationKind get _kind {
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (text.contains('cancel')) return _NotificationKind.cancelled;
    if (text.contains('message')) return _NotificationKind.chat;
    if (text.contains('arrived')) return _NotificationKind.arrived;
    if (text.contains('started') || text.contains('in progress')) {
      return _NotificationKind.started;
    }
    if (text.contains('completed') || text.contains('rate')) {
      return _NotificationKind.completed;
    }
    if (text.contains('accepted')) return _NotificationKind.accepted;
    return _NotificationKind.general;
  }

  ({IconData icon, Color color}) get _visual {
    switch (_kind) {
      case _NotificationKind.accepted:
        return (icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32));
      case _NotificationKind.arrived:
        return (icon: Icons.directions_car_filled_rounded, color: const Color(0xFF2D64E3));
      case _NotificationKind.started:
        return (icon: Icons.route_rounded, color: const Color(0xFF7A3FD0));
      case _NotificationKind.completed:
        return (icon: Icons.verified_rounded, color: const Color(0xFF2E7D32));
      case _NotificationKind.cancelled:
        return (icon: Icons.cancel_rounded, color: const Color(0xFFD84315));
      case _NotificationKind.chat:
        return (icon: Icons.chat_bubble_rounded, color: const Color(0xFF1E88E5));
      case _NotificationKind.general:
        return (icon: Icons.notifications_rounded, color: const Color(0xFFF68B1F));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _visual;
    final timeLabel =
        '${item.createdAt.day.toString().padLeft(2, '0')}/${item.createdAt.month.toString().padLeft(2, '0')} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        // Previously disabled once read, back when tapping only marked it
        // read (nothing left to do at that point). Now it also opens the
        // linked ride, so it needs to stay tappable either way.
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.read
                  ? theme.dividerColor
                  : visual.color.withValues(alpha: 0.35),
              width: item.read ? 1 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0x0C000000),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, color: visual.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.bookingId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? bookingId;
}
