import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/widgets/auth_gradient_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  final _databaseRepository =
      FirebaseDatabaseRepository(PerdaRideFirebase.instance);
  bool _showSignUpOptions = false;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthGradientScaffold(
      header: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello',
            style: TextStyle(
              color: Color(0xFF1D1B1A),
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Sign in!',
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
          const SizedBox(height: 8),
          _InputLabel(label: 'Gmail'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Joydee@gmail.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
              suffixIcon: Icon(Icons.check_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 18),
          _InputLabel(
            label: 'Password',
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.forgotPassword);
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF715746),
                ),
              ),
            ),
          ),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: '.........',
              prefixIcon: Icon(Icons.lock_outline_rounded),
              suffixIcon: Icon(Icons.visibility_off_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF9B22),
                  Color(0xFFF68B1F),
                ],
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
              onPressed: _isSigningIn ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(_isSigningIn ? 'SIGNING IN...' : 'SIGN IN'),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have account?",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9A8A7A),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showSignUpOptions = !_showSignUpOptions;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 6),
                ),
                child: Text(
                  _showSignUpOptions ? 'Close' : 'Sign up',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF68B1F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _showSignUpOptions
                ? Padding(
                    key: const ValueKey('login-sign-up-options'),
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      children: [
                        _RoleOptionButton(
                          label: 'Register as User',
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              AppRouter.userRegistration,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _RoleOptionButton(
                          label: 'Register as Driver',
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              AppRouter.driverRegistration,
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password.');
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      final credential = await _authRepository.signIn(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        _showMessage('Login failed. Please try again.');
        return;
      }

      final driverSnapshot =
          await _databaseRepository.getData('drivers/${user.uid}');
      final usersSnapshot = await _databaseRepository.getData('users/${user.uid}');

      if (!mounted) return;

      if (driverSnapshot.exists) {
        final driverValue = driverSnapshot.value;
        final rawStatus = driverValue is Map
            ? driverValue['registrationStatus']
            : null;
        final status = (rawStatus?.toString() ?? 'approved').trim();
        Navigator.of(context).pushNamedAndRemoveUntil(
          status.isEmpty || status == 'approved'
              ? AppRouter.driverDashboard
              : AppRouter.driverPendingApproval,
          (route) => false,
        );
        return;
      }

      if (usersSnapshot.exists) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.userDashboard,
          (route) => false,
        );
        return;
      }

      _showMessage('Account profile not found. Please register again.');
    } catch (e) {
      _showMessage(_friendlySignInError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  String _friendlySignInError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid-credential') ||
        lower.contains('wrong-password') ||
        lower.contains('user-not-found')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('network-request-failed')) {
      return 'Network issue. Please check your connection.';
    }
    return 'Sign in failed. Please try again.';
    }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RoleOptionButton extends StatelessWidget {
  const _RoleOptionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: Color(0xFFF2B067)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Text(label),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({
    required this.label,
    this.trailing,
  });

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFC81D39),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
