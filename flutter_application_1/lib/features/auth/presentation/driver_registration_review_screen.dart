import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/services/cloudinary_upload_service.dart';
import '../data/driver_registration_draft.dart';
import 'registration_widgets.dart';

class DriverRegistrationReviewScreen extends StatefulWidget {
  const DriverRegistrationReviewScreen({super.key});

  @override
  State<DriverRegistrationReviewScreen> createState() =>
      _DriverRegistrationReviewScreenState();
}

class _DriverRegistrationReviewScreenState
    extends State<DriverRegistrationReviewScreen> {
  final _draft = DriverRegistrationDraft.instance;
  final _authRepository = FirebaseAuthRepository(PerdaRideFirebase.instance);
  final _databaseRepository =
      FirebaseDatabaseRepository(PerdaRideFirebase.instance);
  final _uploadService = CloudinaryUploadService();
  bool _isSubmitting = false;
  String _submitStage = 'idle';

  bool get _hasAnyUploadedImage =>
      _draft.profilePicturePath != null ||
      _draft.carPhotoFrontPath != null ||
      _draft.carPhotoBackPath != null ||
      _draft.carPhotoLeftPath != null ||
      _draft.carPhotoRightPath != null ||
      _draft.icPhotoFrontPath != null ||
      _draft.icPhotoBackPath != null ||
      _draft.licensePhotoFrontPath != null ||
      _draft.licensePhotoBackPath != null ||
      _draft.grantPhotoPath != null;

  @override
  Widget build(BuildContext context) {
    return RegistrationScaffold(
      header: const RegistrationHeader(
        title: 'Driver Registration',
        subtitle: 'Review & Submit',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HeroSummary(),
          const SizedBox(height: 18),
          _reviewCard(
            title: 'Personal Information',
            icon: Icons.person_outline_rounded,
            child: Column(
              children: [
                _detailRow('Email', _draft.email),
                _detailRow('Name', _draft.name),
                _detailRow('ID Card', _draft.idCard),
                _detailRow('Phone', _draft.phone, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reviewCard(
            title: 'Vehicle Information',
            icon: Icons.directions_car_outlined,
            child: Column(
              children: [
                _detailRow('Brand', _draft.brand),
                _detailRow('Model', _draft.model),
                _detailRow('Years Make', _draft.yearMake),
                _detailRow('Plate Number', _draft.plateNumber),
                _detailRow(
                  'Passenger Capacity',
                  _draft.passengerCapacity,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reviewCard(
            title: 'Document Checklist',
            icon: Icons.verified_user_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statusChip('Profile Photo', _draft.profilePicturePath != null),
                _statusChip('Car Front', _draft.carPhotoFrontPath != null),
                _statusChip('Car Back', _draft.carPhotoBackPath != null),
                _statusChip('Car Left', _draft.carPhotoLeftPath != null),
                _statusChip('Car Right', _draft.carPhotoRightPath != null),
                _statusChip('IC Front', _draft.icPhotoFrontPath != null),
                _statusChip('IC Back', _draft.icPhotoBackPath != null),
                _statusChip(
                  'License Front',
                  _draft.licensePhotoFrontPath != null,
                ),
                _statusChip(
                  'License Back',
                  _draft.licensePhotoBackPath != null,
                ),
                _statusChip('Grant', _draft.grantPhotoPath != null),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reviewCard(
            title: 'Uploaded Images',
            icon: Icons.photo_library_outlined,
            child: _hasAnyUploadedImage
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _imageSection(
                        'Profile',
                        [_thumbCard('Profile', _draft.profilePicturePath)],
                      ),
                      _imageSection('Car', [
                        _thumbCard('Front', _draft.carPhotoFrontPath),
                        _thumbCard('Back', _draft.carPhotoBackPath),
                        _thumbCard('Left', _draft.carPhotoLeftPath),
                        _thumbCard('Right', _draft.carPhotoRightPath),
                      ]),
                      _imageSection('IC', [
                        _thumbCard('IC Front', _draft.icPhotoFrontPath),
                        _thumbCard('IC Back', _draft.icPhotoBackPath),
                      ]),
                      _imageSection('License', [
                        _thumbCard(
                          'License Front',
                          _draft.licensePhotoFrontPath,
                        ),
                        _thumbCard(
                          'License Back',
                          _draft.licensePhotoBackPath,
                        ),
                      ]),
                      _imageSection(
                        'Other',
                        [_thumbCard('Grant', _draft.grantPhotoPath)],
                        isLast: true,
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3E4D2)),
                    ),
                    child: const Text(
                      'No images uploaded yet.',
                      style: TextStyle(color: Color(0xFF8A786A)),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF3C893),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF68B1F),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please review your information carefully before submitting. '
                    'Your application will be sent to admin for approval.',
                    style: TextStyle(
                      height: 1.45,
                      color: Color(0xFF6A5541),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          RegistrationActionButton(
            label: _isSubmitting ? 'Submitting...' : 'Submit Application',
            onPressed: _isSubmitting ? () {} : _submitDriverRegistration,
          ),
        ],
      ),
    );
  }

  Widget _reviewCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFF68B1F)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D1B1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFF2E4D5),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A786A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Color(0xFF1D1B1A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFE9F8EC) : const Color(0xFFFFEFE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok ? const Color(0xFFCDEED4) : const Color(0xFFF4C7B5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: ok ? const Color(0xFF2E9B51) : const Color(0xFFD96A43),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF3D332C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageSection(
    String title,
    List<Widget?> children, {
    bool isLast = false,
  }) {
    final visible = children.whereType<Widget>().toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A786A),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: visible),
        ],
      ),
    );
  }

  Widget? _thumbCard(String label, String? path) {
    if (path == null || path.isEmpty) return null;
    return SizedBox(
      width: 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              width: 86,
              height: 86,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6A5541),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDriverRegistration() async {
    if (_draft.email.isEmpty ||
        _draft.password.isEmpty ||
        _draft.name.isEmpty ||
        _draft.brand.isEmpty ||
        _draft.model.isEmpty ||
        _draft.yearMake.isEmpty ||
        _draft.plateNumber.isEmpty ||
        _draft.passengerCapacity.isEmpty ||
        _draft.icPhotoFrontPath == null ||
        _draft.icPhotoBackPath == null ||
        _draft.licensePhotoFrontPath == null ||
        _draft.licensePhotoBackPath == null ||
        _draft.grantPhotoPath == null ||
        _draft.carPhotoFrontPath == null ||
        _draft.carPhotoBackPath == null ||
        _draft.carPhotoLeftPath == null ||
        _draft.carPhotoRightPath == null) {
      _showMessage('Registration data is incomplete. Please check previous steps.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitStage = 'uploading images';
    });

    User? user;
    try {
      // Upload documents BEFORE creating the account. Uploading 10 images
      // over a mobile connection is the most likely step to fail, and if
      // it fails after the Firebase Auth account already existed, that
      // account is stuck forever with no driver profile behind it --
      // every retry with the same email then fails with
      // "email-already-in-use" even though nothing shows up in the
      // database. Doing uploads first means a failure here never creates
      // an account at all, so the driver can just retry.
      final tempUploadId = DateTime.now().millisecondsSinceEpoch.toString();
      final uploaded = await _uploadDriverAssets(tempUploadId);

      _submitStage = 'creating account';
      final credential = await _authRepository.register(
        email: _draft.email,
        password: _draft.password,
      );
      user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Driver account creation failed.',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final driverData = <String, dynamic>{
        'userId': user.uid,
        'email': _draft.email,
        'name': _draft.name,
        'idCard': _draft.idCard,
        'phone': _draft.phone,
        'userType': 'driver',
        'registrationStatus': 'pending',
        'registrationDate': now,
        'vehicleBrand': _draft.brand,
        'vehicleModel': _draft.model,
        'vehicleYear': _draft.yearMake,
        'carPlateNumber': _draft.plateNumber,
        'plateNumber': _draft.plateNumber,
        'vehiclePlate': _draft.plateNumber,
        'passengerCapacity': _draft.passengerCapacity,
        'profilePicturePath': uploaded['profilePicturePath'],
        'carPhotoPath': uploaded['carPhotoFrontPath'],
        'carPhotoFrontPath': uploaded['carPhotoFrontPath'],
        'carPhotoBackPath': uploaded['carPhotoBackPath'],
        'carPhotoLeftPath': uploaded['carPhotoLeftPath'],
        'carPhotoRightPath': uploaded['carPhotoRightPath'],
        'car_photo_path': uploaded['carPhotoFrontPath'],
        'car_photo_front_path': uploaded['carPhotoFrontPath'],
        'car_photo_back_path': uploaded['carPhotoBackPath'],
        'car_photo_left_path': uploaded['carPhotoLeftPath'],
        'car_photo_right_path': uploaded['carPhotoRightPath'],
        'icPhotoPath': uploaded['icPhotoFrontPath'],
        'icPhotoFrontPath': uploaded['icPhotoFrontPath'],
        'icPhotoBackPath': uploaded['icPhotoBackPath'],
        'ic_photo_path': uploaded['icPhotoFrontPath'],
        'ic_photo_front_path': uploaded['icPhotoFrontPath'],
        'ic_photo_back_path': uploaded['icPhotoBackPath'],
        'licensePhotoPath': uploaded['licensePhotoFrontPath'],
        'licensePhotoFrontPath': uploaded['licensePhotoFrontPath'],
        'licensePhotoBackPath': uploaded['licensePhotoBackPath'],
        'license_photo_path': uploaded['licensePhotoFrontPath'],
        'license_photo_front_path': uploaded['licensePhotoFrontPath'],
        'license_photo_back_path': uploaded['licensePhotoBackPath'],
        'grantPhotoPath': uploaded['grantPhotoPath'],
        'grant_photo_path': uploaded['grantPhotoPath'],
      };

      final approvalData = <String, dynamic>{
        ...driverData,
        'driverId': user.uid,
        'status': 'pending',
        'submittedAt': now,
        'reviewedAt': null,
        'reviewedBy': null,
        'adminNotes': null,
      };

      _submitStage = 'saving driver profile';
      await _databaseRepository.setData('drivers/${user.uid}', driverData);
      _submitStage = 'saving approval request';
      await _databaseRepository.setData(
        'driver_approvals/${user.uid}',
        approvalData,
      );

      if (!mounted) return;
      _showMessage('Driver registration submitted successfully!');
      _draft.clear();
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.driverPendingApproval,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      await _rollbackFailedRegistration(user);
      if (!mounted) return;
      _showMessage(
        'Submit failed at $_submitStage: ${_friendlyAuthError(e)}',
      );
    } on FirebaseException catch (e) {
      await _rollbackFailedRegistration(user);
      if (!mounted) return;
      final message = e.message ?? e.code;
      _showMessage(
        'Submit failed at $_submitStage [${e.plugin}:${e.code}]: $message',
      );
    } catch (_) {
      await _rollbackFailedRegistration(user);
      if (!mounted) return;
      _showMessage('Failed to submit driver registration at $_submitStage.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitStage = 'idle';
        });
      }
    }
  }

  /// Undo whatever partially committed after the Auth account was created,
  /// so a failed submission never leaves an email permanently stuck on an
  /// account with no driver profile behind it.
  Future<void> _rollbackFailedRegistration(User? user) async {
    if (user == null) return;
    try {
      await _databaseRepository.removePath('drivers/${user.uid}');
    } catch (_) {}
    try {
      await _databaseRepository.removePath('driver_approvals/${user.uid}');
    } catch (_) {}
    try {
      await user.delete();
    } catch (_) {
      // Best-effort: if this fails (e.g. session no longer fresh), the
      // account will need manual removal from the Firebase console.
    }
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

  Future<Map<String, String?>> _uploadDriverAssets(String userId) async {
    // publicId embeds `_front_`/`_back_`/`_left_`/`_right_` markers because the
    // admin website's image viewer (driver-requests.php) still keys off those
    // exact substrings from the old Firebase-Storage filename convention to
    // decide which side an image belongs to -- without them it silently
    // discards the URL instead of showing it.
    Future<String?> uploadOptional(
      String? localPath,
      String folder,
      String publicId,
    ) async {
      if (localPath == null || localPath.isEmpty) return null;
      if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
        return localPath;
      }
      if (!File(localPath).existsSync()) {
        throw Exception('Selected image could not be found on device.');
      }
      return _uploadService.uploadFile(
        localPath: localPath,
        folder: folder,
        publicId: publicId,
      );
    }

    return {
      'profilePicturePath': await uploadOptional(
        _draft.profilePicturePath,
        'drivers/$userId/profile',
        'profile_photo',
      ),
      'carPhotoFrontPath': await uploadOptional(
        _draft.carPhotoFrontPath,
        'drivers/$userId/car',
        'car_front_photo',
      ),
      'carPhotoBackPath': await uploadOptional(
        _draft.carPhotoBackPath,
        'drivers/$userId/car',
        'car_back_photo',
      ),
      'carPhotoLeftPath': await uploadOptional(
        _draft.carPhotoLeftPath,
        'drivers/$userId/car',
        'car_left_photo',
      ),
      'carPhotoRightPath': await uploadOptional(
        _draft.carPhotoRightPath,
        'drivers/$userId/car',
        'car_right_photo',
      ),
      'icPhotoFrontPath': await uploadOptional(
        _draft.icPhotoFrontPath,
        'drivers/$userId/documents',
        'ic_front_photo',
      ),
      'icPhotoBackPath': await uploadOptional(
        _draft.icPhotoBackPath,
        'drivers/$userId/documents',
        'ic_back_photo',
      ),
      'licensePhotoFrontPath': await uploadOptional(
        _draft.licensePhotoFrontPath,
        'drivers/$userId/documents',
        'license_front_photo',
      ),
      'licensePhotoBackPath': await uploadOptional(
        _draft.licensePhotoBackPath,
        'drivers/$userId/documents',
        'license_back_photo',
      ),
      'grantPhotoPath': await uploadOptional(
        _draft.grantPhotoPath,
        'drivers/$userId/documents',
        'grant_photo',
      ),
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFA53B),
            Color(0xFFF68B1F),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22F68B1F),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Check your driver registration before sending it to admin.',
                  style: TextStyle(
                    color: Color(0xFFFFF3E3),
                    height: 1.45,
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
