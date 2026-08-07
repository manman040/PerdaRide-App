import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/widgets/auth_gradient_scaffold.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  bool _isSaving = false;
  bool _isDone = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('New password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirm) {
      _showMessage('New password and confirmation do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _authRepository.changePassword(
        currentPassword: current,
        newPassword: newPassword,
      );
      if (!mounted) return;
      setState(() {
        _isDone = true;
      });
    } catch (e) {
      _showMessage(_friendlyError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _friendlyError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('wrong-password') || lower.contains('invalid-credential')) {
      return 'Current password is incorrect.';
    }
    if (lower.contains('weak-password')) {
      return 'New password is too weak.';
    }
    if (lower.contains('network-request-failed')) {
      return 'Network issue. Please check your connection.';
    }
    return 'Could not change password. Please try again.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthGradientScaffold(
      header: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change',
            style: TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Password',
            style: TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
        children: [
          if (_isDone) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8EC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCDEED4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF2E9B51)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your password has been updated.',
                      style: TextStyle(height: 1.45, color: Color(0xFF2E9B51)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                side: const BorderSide(color: Color(0xFFF2B067)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Back to Profile'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Enter your current password and choose a new one.',
              style: TextStyle(color: Color(0xFF9A8A7A), height: 1.4),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'New password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Confirm new password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9B22), Color(0xFFF68B1F)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(_isSaving ? 'SAVING...' : 'UPDATE PASSWORD'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
