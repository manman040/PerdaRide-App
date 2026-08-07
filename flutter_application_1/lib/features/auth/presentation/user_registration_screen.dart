import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import 'registration_widgets.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  final _databaseRepository =
      FirebaseDatabaseRepository(PerdaRideFirebase.instance);

  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _idCardController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationScaffold(
      header: const RegistrationHeader(
        title: 'User Registration',
        subtitle: 'Create your passenger account',
      ),
      child: Column(
        children: [
          const SectionTitle('User Registration'),
          const PicturePickerCard(
            label: 'Profile Picture',
            icon: Icons.add_a_photo_outlined,
          ),
          const SizedBox(height: 28),
          RegistrationField(
            hint: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          RegistrationField(
            hint: 'Name',
            controller: _nameController,
          ),
          RegistrationField(
            hint: 'Identification card',
            controller: _idCardController,
          ),
          RegistrationField(
            hint: 'No. Phone',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          RegistrationField(
            hint: 'Password',
            controller: _passwordController,
            obscureText: true,
          ),
          RegistrationField(
            hint: 'Confirm Password',
            controller: _confirmPasswordController,
            obscureText: true,
          ),
          const SizedBox(height: 10),
          RegistrationActionButton(
            label: _isSubmitting ? 'Creating Account...' : 'Submit',
            onPressed: _isSubmitting ? () {} : _registerUser,
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final idCard = _idCardController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final validationError = _validateInputs(
      email: email,
      name: name,
      idCard: idCard,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );

    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final credential = await _authRepository.register(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User account creation failed. Please try again.',
        );
      }

      final userData = <String, dynamic>{
        'email': email,
        'name': name,
        'idCard': idCard,
        'phone': phone,
        'userType': 'user',
        'registrationDate': DateTime.now().millisecondsSinceEpoch,
      };

      await _databaseRepository.setData('users/${user.uid}', userData);

      if (!mounted) return;
      _showMessage('Account created successfully!');
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(e));
    } catch (_) {
      if (!mounted) return;
      _showMessage('Registration failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateInputs({
    required String email,
    required String name,
    required String idCard,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    if (email.isEmpty) return 'Please enter your email';
    if (!_emailPattern.hasMatch(email)) return 'Please enter a valid email';
    if (name.isEmpty) return 'Please enter your name';
    if (idCard.isEmpty) return 'Please enter your identification card';
    if (phone.isEmpty) return 'Please enter your phone number';
    if (password.isEmpty) return 'Please enter your password';
    if (confirmPassword.isEmpty) return 'Please confirm your password';
    if (password != confirmPassword) return 'Passwords do not match';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Registration failed.';
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
