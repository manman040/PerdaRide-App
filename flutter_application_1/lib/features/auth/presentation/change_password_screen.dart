import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
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
    final copy = AppCopy.of(context);
    final current = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      _showMessage(copy.fillAllFieldsError);
      return;
    }
    if (newPassword.length < 6) {
      _showMessage(copy.passwordTooShortError);
      return;
    }
    if (newPassword != confirm) {
      _showMessage(copy.passwordMismatchError);
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
      _showMessage(_friendlyError(copy, e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _friendlyError(AppCopy copy, String message) {
    final lower = message.toLowerCase();
    if (lower.contains('wrong-password') || lower.contains('invalid-credential')) {
      return copy.currentPasswordIncorrectError;
    }
    if (lower.contains('weak-password')) {
      return copy.passwordTooWeakError;
    }
    if (lower.contains('network-request-failed')) {
      return copy.networkIssueError;
    }
    return copy.changePasswordFailedError;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return AuthGradientScaffold(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.changeTitle,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            copy.passwordLabel,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
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
                color: const Color(0xFF2E9B51).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF2E9B51).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9B51)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      copy.passwordUpdatedMessage,
                      style: const TextStyle(height: 1.45, color: Color(0xFF2E9B51)),
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
              child: Text(copy.backToProfile),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              copy.changePasswordDescription,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: copy.currentPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: copy.newPasswordHint,
                prefixIcon: const Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: copy.confirmNewPasswordHint,
                prefixIcon: const Icon(Icons.lock_reset_rounded),
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
                child: Text(_isSaving ? copy.savingCta : copy.updatePasswordCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
