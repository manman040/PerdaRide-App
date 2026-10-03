import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  final _databaseRepository =
      FirebaseDatabaseRepository(PerdaRideFirebase.instance);

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  Map<String, dynamic> _profile = const {};
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    super.dispose();
  }

  String _editableValue(String key) {
    final raw = _profile[key];
    return raw is String ? raw.trim() : '';
  }

  void _startEditing() {
    _nameController.text = _editableValue('name');
    _phoneController.text = _editableValue('phone');
    _vehicleBrandController.text = _editableValue('vehicleBrand');
    _vehicleModelController.text = _editableValue('vehicleModel');
    _vehicleYearController.text = _editableValue('vehicleYear');
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
      final updates = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicleBrand': _vehicleBrandController.text.trim(),
        'vehicleModel': _vehicleModelController.text.trim(),
        'vehicleYear': _vehicleYearController.text.trim(),
      };
      await _databaseRepository.updateData('drivers/${user.uid}', updates);
      if (!mounted) return;
      setState(() {
        _profile = {..._profile, ...updates};
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.profileUpdatedMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${copy.updateProfileFailedError}: $e')),
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
      final snapshot = await _databaseRepository.getData('drivers/${user.uid}');
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

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = _readValue('name');
    final email = _readValue('email', fallback: _authRepository.currentUser?.email);
    final phone = _readValue('phone');
    final vehicle = [
      _readValue('vehicleBrand'),
      _readValue('vehicleModel'),
    ].where((item) => item != copy.unknownValue).join(' ');
    final year = _readValue('vehicleYear');
    final capacity = _readValue('passengerCapacity');
    final safeName = name == copy.unknownValue ? '' : name.trim();
    final initials = safeName.isEmpty ? 'D' : safeName[0].toUpperCase();

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
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                  ],
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
                      copy.driverProfileTitle,
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
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        copy.driverProfileDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: _isEditing
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: copy.fullName,
                                      prefixIcon: const Icon(Icons.badge_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: copy.phone,
                                      prefixIcon: const Icon(Icons.call_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _vehicleBrandController,
                                    decoration: InputDecoration(
                                      labelText: copy.vehicleBrandLabel,
                                      prefixIcon: const Icon(Icons.directions_car_filled_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _vehicleModelController,
                                    decoration: InputDecoration(
                                      labelText: copy.vehicleModelLabel,
                                      prefixIcon: const Icon(Icons.directions_car_filled_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _vehicleYearController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: copy.vehicleYearLabel,
                                      prefixIcon: const Icon(Icons.calendar_month_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isSaving
                                              ? null
                                              : () => setState(() => _isEditing = false),
                                          child: Text(copy.cancelCta),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isSaving ? null : _saveProfile,
                                          child: Text(_isSaving ? copy.savingProfileCta : copy.saveCta),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : Column(
                                children: [
                                  _DriverDetailTile(
                                    icon: Icons.badge_outlined,
                                    label: copy.fullName,
                                    value: _isLoading ? '...' : name,
                                  ),
                                  _DriverDetailTile(
                                    icon: Icons.mail_outline_rounded,
                                    label: copy.email,
                                    value: _isLoading ? '...' : email,
                                  ),
                                  _DriverDetailTile(
                                    icon: Icons.call_outlined,
                                    label: copy.phone,
                                    value: _isLoading ? '...' : phone,
                                  ),
                                  _DriverDetailTile(
                                    icon: Icons.directions_car_filled_outlined,
                                    label: copy.driverVehicleLabel,
                                    value: _isLoading ? '...' : _fallback(vehicle, copy),
                                  ),
                                  _DriverDetailTile(
                                    icon: Icons.calendar_month_outlined,
                                    label: copy.vehicleYearLabel,
                                    value: _isLoading ? '...' : year,
                                  ),
                                  _DriverDetailTile(
                                    icon: Icons.people_alt_outlined,
                                    label: copy.capacityLabel,
                                    value: _isLoading ? '...' : capacity,
                                  ),
                                  _DriverDetailTile(
                                    icon: Icons.work_outline_rounded,
                                    label: copy.accountType,
                                    value: copy.driverRole,
                                    isLast: true,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRouter.changePassword,
                        ),
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: Text(copy.changePasswordMenuCta),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
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

  String _readValue(String key, {String? fallback}) {
    final raw = _profile[key];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return fallback ?? AppCopy.of(context).unknownValue;
  }

  String _fallback(String value, AppCopy copy) {
    return value.trim().isEmpty ? copy.unknownValue : value;
  }
}

class _DriverDetailTile extends StatelessWidget {
  const _DriverDetailTile({
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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
