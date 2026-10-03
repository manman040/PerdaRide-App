import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../features/booking/data/booking_repository.dart';
import '../firebase/firebase_database_repository.dart';
import '../firebase/perdaride_firebase.dart';
import '../notifications/ride_notification_service.dart';
import '../settings/app_copy.dart';

Future<void> showBookingChatSheet(
  BuildContext context, {
  required BookingRepository bookingRepository,
  required String bookingId,
  required String currentUserRole,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) {
      return _BookingChatSheet(
        bookingRepository: bookingRepository,
        bookingId: bookingId,
        currentUserRole: currentUserRole,
      );
    },
  );
}

class _ChatMessage {
  const _ChatMessage({
    required this.senderRole,
    required this.message,
    required this.timestamp,
  });

  final String senderRole;
  final String message;
  final int timestamp;
}

class _BookingChatSheet extends StatefulWidget {
  const _BookingChatSheet({
    required this.bookingRepository,
    required this.bookingId,
    required this.currentUserRole,
  });

  final BookingRepository bookingRepository;
  final String bookingId;
  final String currentUserRole;

  @override
  State<_BookingChatSheet> createState() => _BookingChatSheetState();
}

class _BookingChatSheetState extends State<_BookingChatSheet> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _databaseRepository = FirebaseDatabaseRepository(
    PerdaRideFirebase.instance,
  );
  StreamSubscription<DatabaseEvent>? _subscription;
  List<_ChatMessage> _messages = const [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.bookingRepository
        .watchChatMessages(widget.bookingId)
        .listen(_onChatEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatEvent(DatabaseEvent event) {
    final value = event.snapshot.value;
    final messages = <_ChatMessage>[];
    if (value is Map) {
      value.forEach((_, raw) {
        if (raw is! Map) return;
        final rawTimestamp = raw['timestamp'];
        messages.add(
          _ChatMessage(
            senderRole: (raw['senderRole'] ?? '').toString(),
            message: (raw['message'] ?? '').toString(),
            timestamp: rawTimestamp is int
                ? rawTimestamp
                : int.tryParse('$rawTimestamp') ?? 0,
          ),
        );
      });
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    if (!mounted) return;
    setState(() {
      _messages = messages;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final copy = AppCopy.of(context);
    final message = _inputController.text.trim();
    if (message.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
    });
    try {
      await widget.bookingRepository.postChatMessage(
        bookingId: widget.bookingId,
        senderRole: widget.currentUserRole,
        message: message,
      );
      _inputController.clear();
      unawaited(_notifyOtherParty(copy, message));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final reason = e.code == 'permission-denied'
          ? 'permission denied — check the booking_chats database rule'
          : e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.sendMessageFailedGeneric} ($reason)')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.sendMessageFailedGeneric)));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _notifyOtherParty(AppCopy copy, String message) async {
    try {
      final snapshot = await _databaseRepository.getData(
        'bookings/${widget.bookingId}',
      );
      final value = snapshot.value;
      if (value is! Map) return;

      final isDriverSender = widget.currentUserRole == 'driver';
      final recipientId = (isDriverSender
              ? value['userId']
              : value['driverId'])
          ?.toString()
          .trim();
      if (recipientId == null || recipientId.isEmpty) return;

      await RideNotificationService.instance.notify(
        uid: recipientId,
        isDriver: !isDriverSender,
        title: isDriverSender
            ? copy.newMessageFromDriverTitle
            : copy.newMessageFromPassengerTitle,
        body: message,
        bookingId: widget.bookingId,
      );
    } catch (_) {}
  }

  String _labelFor(AppCopy copy, String senderRole) {
    if (senderRole == widget.currentUserRole) return copy.youLabel;
    return senderRole == 'driver' ? copy.driverRole : copy.passengerRole;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.currentUserRole == 'driver'
                  ? copy.chatWithPassengerTitle
                  : copy.chatWithDriverTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        copy.noMessagesYet,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMine =
                            message.senderRole == widget.currentUserRole;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFFF68B1F)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _labelFor(copy, message.senderRole),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isMine
                                        ? Colors.white70
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.message,
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: copy.typeMessageHint,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF68B1F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
