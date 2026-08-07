import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/widgets/auth_gradient_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  bool _isSending = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _authRepository.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() {
        _emailSent = true;
      });
    } catch (e) {
      _showMessage(_friendlyResetError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _friendlyResetError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid-email')) {
      return 'Invalid email address.';
    }
    if (lower.contains('user-not-found')) {
      return 'No account found for that email.';
    }
    if (lower.contains('network-request-failed')) {
      return 'Network issue. Please check your connection.';
    }
    return 'Could not send reset email. Please try again.';
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
            'Forgot',
            style: TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Password?',
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
          if (_emailSent) ...[
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
                      'A password reset link has been sent to your email. '
                      'Please check your inbox.',
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
              child: const Text('Back to Login'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Enter the email address associated with your account and '
              "we'll send you a link to reset your password.",
              style: TextStyle(color: Color(0xFF9A8A7A), height: 1.4),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Joydee@gmail.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
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
                onPressed: _isSending ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(_isSending ? 'SENDING...' : 'SEND RESET LINK'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
