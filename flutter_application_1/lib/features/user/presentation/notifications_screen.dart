import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _firebase = PerdaRideFirebase.instance;
  late final _authRepository = FirebaseAuthRepository(_firebase);
  late final _databaseRepository = FirebaseDatabaseRepository(_firebase);
  String _notificationPath = '';
  bool _pathReady = false;

  @override
  void initState() {
    super.initState();
    _resolveNotificationPath();
  }

  Future<void> _resolveNotificationPath() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _pathReady = true;
      });
      return;
    }
    try {
      final userProfile = await _databaseRepository.getData('users/${user.uid}');
      String path = 'user_notifications/${user.uid}';
      if (userProfile.value is Map) {
        final userType =
            (userProfile.value as Map)['userType']?.toString().toLowerCase();
        if (userType == 'driver') {
          path = 'driver_notifications/${user.uid}';
        }
      } else {
        final driverProfile = await _databaseRepository.getData(
          'drivers/${user.uid}',
        );
        if (driverProfile.value is Map) {
          path = 'driver_notifications/${user.uid}';
        }
      }
      if (!mounted) return;
      setState(() {
        _notificationPath = path;
        _pathReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationPath = 'user_notifications/${user.uid}';
        _pathReady = true;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: !_pathReady
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DatabaseEvent>(
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
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
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
                                  onTap: () => _markRead(item.id),
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
      items.add(
        _NotificationItem(
          id: key.toString(),
          title: title.isEmpty ? 'Notification' : title,
          body: body,
          createdAt: timestamp ?? DateTime.now(),
          read: value['read'] == true,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.read ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.read
                  ? const Color(0xFFEDEDED)
                  : visual.color.withValues(alpha: 0.35),
              width: item.read ? 1 : 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 10,
                offset: Offset(0, 4),
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
                        style: const TextStyle(color: Color(0xFF5F5F5F), height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
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
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
}
