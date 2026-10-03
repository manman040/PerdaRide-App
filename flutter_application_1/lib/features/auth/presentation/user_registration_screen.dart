import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/settings/app_copy.dart';
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
    final copy = AppCopy.of(context);
    return RegistrationScaffold(
      header: RegistrationHeader(
        title: copy.userRegistrationTitle,
        subtitle: copy.userRegistrationSubtitle,
      ),
      child: Column(
        children: [
          SectionTitle(copy.userRegistrationTitle),
          PicturePickerCard(
            label: copy.profilePictureLabel,
            icon: Icons.add_a_photo_outlined,
          ),
          const SizedBox(height: 28),
          RegistrationField(
            hint: copy.email,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          RegistrationField(
            hint: copy.nameFieldLabel,
            controller: _nameController,
          ),
          RegistrationField(
            hint: copy.idCard,
            controller: _idCardController,
          ),
          RegistrationField(
            hint: copy.phoneFieldHint,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
          RegistrationField(
            hint: copy.passwordLabel,
            controller: _passwordController,
            obscureText: true,
          ),
          RegistrationField(
            hint: copy.confirmPasswordHint,
            controller: _confirmPasswordController,
            obscureText: true,
          ),
          const SizedBox(height: 10),
          RegistrationActionButton(
            label: _isSubmitting ? copy.creatingAccountCta : copy.submitCta,
            onPressed: _isSubmitting ? () {} : _registerUser,
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser() async {
    final copy = AppCopy.of(context);
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final idCard = _idCardController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final validationError = _validateInputs(
      copy,
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
          message: copy.userAccountCreationFailedError,
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
      _showMessage(copy.accountCreatedSuccessMessage);
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(copy, e));
    } catch (_) {
      if (!mounted) return;
      _showMessage(copy.registrationFailedTryAgainError);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateInputs(
    AppCopy copy, {
    required String email,
    required String name,
    required String idCard,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    if (email.isEmpty) return copy.enterYourEmailError;
    if (!_emailPattern.hasMatch(email)) return copy.validEmailError;
    if (name.isEmpty) return copy.enterYourNameError;
    if (idCard.isEmpty) return copy.enterIdCardError;
    if (phone.isEmpty) return copy.enterPhoneNumberError;
    if (password.isEmpty) return copy.enterYourPasswordError;
    if (confirmPassword.isEmpty) return copy.confirmYourPasswordError;
    if (password != confirmPassword) return copy.passwordsDoNotMatchError;
    if (password.length < 6) return copy.passwordMinLengthError;
    return null;
  }

  String _friendlyAuthError(AppCopy copy, FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return copy.emailAlreadyRegisteredError;
      case 'invalid-email':
        return copy.invalidEmailError;
      case 'weak-password':
        return copy.weakPasswordError;
      case 'network-request-failed':
        return copy.networkErrorTryAgainError;
      default:
        return e.message ?? copy.registrationFailedError;
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
