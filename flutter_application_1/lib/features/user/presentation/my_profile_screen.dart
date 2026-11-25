import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
import '../../booking/data/booking_repository.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  final _databaseRepository = FirebaseDatabaseRepository(
    PerdaRideFirebase.instance,
  );

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic> _profile = const {};
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bookingRepository = BookingRepository();

  // Ride history section: the rider's completed/cancelled rides plus the
  // driver of each, loaded once alongside the profile.
  static const _collapsedRideCount = 5;
  bool _isHistoryLoading = true;
  bool _historyFailed = false;
  bool _showAllRides = false;
  List<RiderRideRecord> _rides = const [];
  Map<String, DriverSummary> _driversById = const {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRideHistory();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing() {
    _nameController.text =
        _readValue('name') == AppCopy.of(context).unknownValue
        ? ''
        : _readValue('name');
    _phoneController.text =
        _readValue('phone') == AppCopy.of(context).unknownValue
        ? ''
        : _readValue('phone');
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveProfile() async {
    final copy = AppCopy.of(context);
    final user = _authRepository.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      await _databaseRepository.updateData('users/${user.uid}', {
        'name': name,
        'phone': phone,
      });
      if (!mounted) return;
      setState(() {
        _profile = {..._profile, 'name': name, 'phone': phone};
        _isEditing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.userProfileUpdatedMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.failedToUpdateProfileError} $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final snapshot = await _databaseRepository.getData('users/${user.uid}');
      final value = snapshot.value;
      if (!mounted) return;
      setState(() {
        _profile = value is Map
            ? value.map((key, value) => MapEntry(key.toString(), value))
            : const {};
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Loads the rider's finished rides and looks each distinct driver up once.
  Future<void> _loadRideHistory() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isHistoryLoading = false;
      });
      return;
    }

    if (!_isHistoryLoading && mounted) {
      setState(() {
        _isHistoryLoading = true;
        _historyFailed = false;
      });
    }

    try {
      final rides = await _bookingRepository.fetchRiderRideHistory(user.uid);
      final driverIds = rides
          .map((ride) => ride.driverId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final summaries = await Future.wait(
        driverIds.map(_bookingRepository.fetchDriverSummary),
      );
      final byId = <String, DriverSummary>{};
      for (var i = 0; i < driverIds.length; i++) {
        final summary = summaries[i];
        if (summary != null) byId[driverIds[i]] = summary;
      }
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _driversById = byId;
        _isHistoryLoading = false;
        _historyFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isHistoryLoading = false;
        _historyFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = _readValue('name');
    final email = _readValue(
      'email',
      fallback: _authRepository.currentUser?.email,
    );
    final phone = _readValue('phone');
    final idCard = _readValue('idCard');
    final safeName = name == copy.unknownValue ? '' : name.trim();
    final initials = safeName.isEmpty ? 'P' : safeName[0].toUpperCase();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 66),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Text(
                      copy.profileTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!_isLoading && !_isEditing)
                    IconButton(
                      onPressed: _startEditing,
                      icon: const Icon(Icons.edit_outlined),
                      color: Colors.white,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -46),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.45),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: colorScheme.surface,
                          child: Text(
                            initials,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _isLoading ? '...' : name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        copy.profileDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 0,
                      color: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        child: _isEditing
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: copy.fullName,
                                      prefixIcon: const Icon(
                                        Icons.badge_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: copy.phone,
                                      prefixIcon: const Icon(
                                        Icons.call_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isSaving
                                              ? null
                                              : () => setState(
                                                  () => _isEditing = false,
                                                ),
                                          child: Text(copy.profileCancelCta),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isSaving
                                              ? null
                                              : _saveProfile,
                                          child: Text(
                                            _isSaving
                                                ? copy.savingEllipsis
                                                : copy.profileSaveCta,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Column(
                                children: [
                                  _ProfileDetailTile(
                                    icon: Icons.badge_outlined,
                                    label: copy.fullName,
                                    value: _isLoading ? '...' : name,
                                  ),
                                  _ProfileDetailTile(
                                    icon: Icons.mail_outline_rounded,
                                    label: copy.email,
                                    value: _isLoading ? '...' : email,
                                  ),
                                  _ProfileDetailTile(
                                    icon: Icons.call_outlined,
                                    label: copy.phone,
                                    value: _isLoading ? '...' : phone,
                                  ),
                                  _ProfileDetailTile(
                                    icon: Icons.credit_card_outlined,
                                    label: copy.idCard,
                                    value: _isLoading ? '...' : idCard,
                                  ),
                                  _ProfileDetailTile(
                                    icon: Icons.directions_car_filled_outlined,
                                    label: copy.accountType,
                                    value: copy.passengerRole,
                                    isLast: true,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(AppRouter.changePassword),
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: Text(copy.changePasswordCta),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildRideHistorySection(context, copy, theme),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideHistorySection(
    BuildContext context,
    AppCopy copy,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final visibleRides = _showAllRides
        ? _rides
        : _rides.take(_collapsedRideCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.history_rounded, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.rideHistoryTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    copy.rideHistoryDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isHistoryLoading && _rides.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_rides.length}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isHistoryLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_historyFailed)
          _RideHistoryNotice(
            icon: Icons.cloud_off_rounded,
            message: copy.rideHistoryLoadFailed,
            action: TextButton(
              onPressed: _loadRideHistory,
              child: Text(copy.rideHistoryRetryCta),
            ),
          )
        else if (_rides.isEmpty)
          _RideHistoryNotice(
            icon: Icons.directions_car_outlined,
            message: copy.rideHistoryEmpty,
          )
        else ...[
          ...visibleRides.map(
            (ride) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RideHistoryTile(
                ride: ride,
                driver: _driversById[ride.driverId],
                copy: copy,
              ),
            ),
          ),
          if (_rides.length > _collapsedRideCount)
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAllRides = !_showAllRides),
                icon: Icon(
                  _showAllRides
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _showAllRides
                      ? copy.rideHistoryShowLess
                      : copy.rideHistoryShowAll(_rides.length),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _readValue(String key, {String? fallback}) {
    final raw = _profile[key];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return fallback ?? AppCopy.of(context).unknownValue;
  }
}

class _ProfileDetailTile extends StatelessWidget {
  const _ProfileDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One ride in the profile's Ride History: when, where from and to, which
/// driver, and what it cost.
class _RideHistoryTile extends StatelessWidget {
  const _RideHistoryTile({
    required this.ride,
    required this.driver,
    required this.copy,
  });

  final RiderRideRecord ride;
  final DriverSummary? driver;
  final AppCopy copy;

  static const _months = [
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

  String _formatDate(DateTime d) {
    if (!ride.hasDate) return '-';
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${_months[d.month - 1]} ${d.year}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = ride.isCompleted;
    final chipColor = isCompleted ? Colors.green.shade700 : colorScheme.error;
    final driverSummary = driver;
    final driverName = driverSummary != null && driverSummary.name.isNotEmpty
        ? driverSummary.name
        : (ride.driverId.isEmpty
              ? copy.rideHistoryNoDriver
              : copy.rideHistoryUnknownDriver);
    final vehicle = driverSummary?.vehicleLabel ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatDate(ride.completedAt),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isCompleted
                      ? copy.rideHistoryCompletedChip
                      : copy.rideHistoryCancelledChip,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteLine(
            icon: Icons.circle,
            iconColor: Colors.green.shade600,
            iconSize: 10,
            label: copy.pickupHistoryLabel,
            value: ride.pickupLabel,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
            child: Container(width: 2, height: 12, color: theme.dividerColor),
          ),
          _RouteLine(
            icon: Icons.location_on_rounded,
            iconColor: colorScheme.primary,
            iconSize: 14,
            label: copy.dropoffHistoryLabel,
            value: ride.dropoffLabel,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.rideHistoryDriverLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (vehicle.isNotEmpty)
                      Text(
                        vehicle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ride.priceLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                  if (ride.rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        Text(
                          '${ride.rating}/5',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 14,
          height: 18,
          child: Center(
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideHistoryNotice extends StatelessWidget {
  const _RideHistoryNotice({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 6), action!],
        ],
      ),
    );
  }
}
