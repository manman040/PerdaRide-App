import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _startEditing() {
    _nameController.text = _readValue('name') == AppCopy.of(context).unknownValue
        ? ''
        : _readValue('name');
    _phoneController.text = _readValue('phone') == AppCopy.of(context).unknownValue
        ? ''
        : _readValue('phone');
    setState(() {
      _isEditing = true;
    });
  }

  Future<void> _saveProfile() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
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
                          backgroundColor: Colors.white,
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
                          color: const Color(0xFF202425),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        copy.profileDescription,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF7C6D60), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 0,
                      color: Colors.white,
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
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _isSaving
                                              ? null
                                              : () => setState(() => _isEditing = false),
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _isSaving ? null : _saveProfile,
                                          child: Text(_isSaving ? 'Saving...' : 'Save'),
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
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRouter.changePassword,
                        ),
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('Change Password'),
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
