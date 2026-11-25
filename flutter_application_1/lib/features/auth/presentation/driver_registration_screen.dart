import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_router.dart';
import '../../../core/settings/app_copy.dart';
import '../data/driver_registration_draft.dart';
import 'registration_widgets.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  final _draft = DriverRegistrationDraft.instance;
  final _picker = ImagePicker();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _emailController.text = _draft.email;
    _nameController.text = _draft.name;
    _idCardController.text = _draft.idCard;
    _phoneController.text = _draft.phone;
    _profilePicturePath = _draft.profilePicturePath;
  }

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
        title: copy.driverRegistrationTitle,
        subtitle: copy.driverRegistrationStep1Subtitle,
      ),
      child: Column(
        children: [
          SectionTitle(copy.driverRegistrationTitle),
          PicturePickerCard(
            label: copy.profilePictureLabel,
            icon: Icons.add_a_photo_outlined,
            imagePath: _profilePicturePath,
            onTap: _pickProfilePhoto,
          ),
          const SizedBox(height: 28),
          RegistrationField(
            hint: copy.email,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          RegistrationField(hint: copy.nameFieldLabel, controller: _nameController),
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
            label: copy.continueCta,
            onPressed: _continueToVehicleDetails,
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final copy = AppCopy.of(context);
    try {
      final source = await _pickSource();
      if (source == null) return;
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 70,
      );
      if (file == null) return;
      setState(() {
        _profilePicturePath = file.path;
      });
    } on MissingPluginException {
      _showMessage(copy.imagePickerNotReadyError);
    } on PlatformException catch (e) {
      _showMessage('${copy.unableToOpenPickerPrefix} ${e.message ?? e.code}');
    }
  }

  Future<ImageSource?> _pickSource() async {
    final copy = AppCopy.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(copy.cameraOption),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(copy.galleryOption),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  void _continueToVehicleDetails() {
    final copy = AppCopy.of(context);
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final idCard = _idCardController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty ||
        name.isEmpty ||
        idCard.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage(copy.fillAllFieldsError);
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _showMessage(copy.validEmailError);
      return;
    }
    if (password.length < 6) {
      _showMessage(copy.passwordMinLengthError);
      return;
    }
    if (password != confirmPassword) {
      _showMessage(copy.passwordsDoNotMatchError);
      return;
    }

    _draft.email = email;
    _draft.name = name;
    _draft.idCard = idCard;
    _draft.phone = phone;
    _draft.password = password;
    _draft.profilePicturePath = _profilePicturePath;

    Navigator.of(context).pushNamed(AppRouter.driverVehicleDetails);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
