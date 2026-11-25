import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/services/cloudinary_upload_service.dart';
import '../../../core/settings/app_copy.dart';
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
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return RegistrationScaffold(
      header: RegistrationHeader(
        title: copy.driverRegistrationTitle,
        subtitle: copy.reviewAndSubmitSubtitle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HeroSummary(),
          const SizedBox(height: 18),
          _reviewCard(
            context,
            title: copy.personalInformationTitle,
            icon: Icons.person_outline_rounded,
            child: Column(
              children: [
                _detailRow(context, copy.email, _draft.email),
                _detailRow(context, copy.nameFieldLabel, _draft.name),
                _detailRow(context, copy.idCardShortLabel, _draft.idCard),
                _detailRow(context, copy.phoneLabel, _draft.phone, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reviewCard(
            context,
            title: copy.vehicleInformationTitle,
            icon: Icons.directions_car_outlined,
            child: Column(
              children: [
                _detailRow(context, copy.brandFieldLabel, _draft.brand),
                _detailRow(context, copy.modelFieldLabel, _draft.model),
                _detailRow(context, copy.yearsMakeFieldLabel, _draft.yearMake),
                _detailRow(
                  context,
                  copy.plateNumberFieldLabel,
                  _draft.plateNumber,
                ),
                _detailRow(
                  context,
                  copy.capacityLabel,
                  _draft.passengerCapacity,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reviewCard(
            context,
            title: copy.documentChecklistTitle,
            icon: Icons.verified_user_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statusChip(
                  context,
                  copy.profilePhotoChipLabel,
                  _draft.profilePicturePath != null,
                ),
                _statusChip(
                  context,
                  copy.carFrontChipLabel,
                  _draft.carPhotoFrontPath != null,
                ),
                _statusChip(
                  context,
                  copy.carBackChipLabel,
                  _draft.carPhotoBackPath != null,
                ),
                _statusChip(
                  context,
                  copy.carLeftChipLabel,
                  _draft.carPhotoLeftPath != null,
                ),
                _statusChip(
                  context,
                  copy.carRightChipLabel,
                  _draft.carPhotoRightPath != null,
                ),
                _statusChip(
                  context,
                  copy.icFrontChipLabel,
                  _draft.icPhotoFrontPath != null,
                ),
                _statusChip(
                  context,
                  copy.icBackChipLabel,
                  _draft.icPhotoBackPath != null,
                ),
                _statusChip(
                  context,
                  copy.licenseFrontChipLabel,
                  _draft.licensePhotoFrontPath != null,
                ),
                _statusChip(
                  context,
                  copy.licenseBackChipLabel,
                  _draft.licensePhotoBackPath != null,
                ),
                _statusChip(
                  context,
                  copy.grantChipLabel,
                  _draft.grantPhotoPath != null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reviewCard(
            context,
            title: copy.uploadedImagesTitle,
            icon: Icons.photo_library_outlined,
            child: _hasAnyUploadedImage
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _imageSection(context, copy.profileSectionLabel, [
                        _thumbCard(
                          context,
                          copy.profileSectionLabel,
                          _draft.profilePicturePath,
                        ),
                      ]),
                      _imageSection(context, copy.carSectionLabel, [
                        _thumbCard(context, copy.frontLabel, _draft.carPhotoFrontPath),
                        _thumbCard(context, copy.backLabel, _draft.carPhotoBackPath),
                        _thumbCard(context, copy.leftLabel, _draft.carPhotoLeftPath),
                        _thumbCard(context, copy.rightLabel, _draft.carPhotoRightPath),
                      ]),
                      _imageSection(context, copy.icSectionLabel, [
                        _thumbCard(
                          context,
                          copy.icFrontChipLabel,
                          _draft.icPhotoFrontPath,
                        ),
                        _thumbCard(context, copy.icBackChipLabel, _draft.icPhotoBackPath),
                      ]),
                      _imageSection(context, copy.licenseSectionLabel, [
                        _thumbCard(
                          context,
                          copy.licenseFrontChipLabel,
                          _draft.licensePhotoFrontPath,
                        ),
                        _thumbCard(
                          context,
                          copy.licenseBackChipLabel,
                          _draft.licensePhotoBackPath,
                        ),
                      ]),
                      _imageSection(
                        context,
                        copy.otherSectionLabel,
                        [_thumbCard(context, copy.grantChipLabel, _draft.grantPhotoPath)],
                        isLast: true,
                      ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      copy.noImagesUploadedMessage,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF68B1F),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    copy.reviewCarefullyNotice,
                    style: TextStyle(
                      height: 1.45,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          RegistrationActionButton(
            label: _isSubmitting ? copy.submittingCta : copy.submitApplicationCta,
            onPressed: _isSubmitting ? () {} : _submitDriverRegistration,
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFF68B1F)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
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

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String label, bool ok) {
    final theme = Theme.of(context);
    const okAccent = Color(0xFF2E9B51);
    const warnAccent = Color(0xFFD96A43);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (ok ? okAccent : warnAccent).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (ok ? okAccent : warnAccent).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: ok ? okAccent : warnAccent,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageSection(
    BuildContext context,
    String title,
    List<Widget?> children, {
    bool isLast = false,
  }) {
    final visible = children.whereType<Widget>().toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: visible),
        ],
      ),
    );
  }

  Widget? _thumbCard(BuildContext context, String label, String? path) {
    if (path == null || path.isEmpty) return null;
    final theme = Theme.of(context);
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
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDriverRegistration() async {
    final copy = AppCopy.of(context);
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
      _showMessage(copy.registrationIncompleteError);
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
          message: copy.driverAccountCreationFailedError,
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
      _showMessage(copy.driverRegistrationSubmittedMessage);
      _draft.clear();
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.driverPendingApproval,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      await _rollbackFailedRegistration(user);
      if (!mounted) return;
      _showMessage(
        '${copy.submitFailedAtPrefix} ${_stageLabel(copy, _submitStage)}: '
        '${_friendlyAuthError(copy, e)}',
      );
    } on FirebaseException catch (e) {
      await _rollbackFailedRegistration(user);
      if (!mounted) return;
      final message = e.message ?? e.code;
      _showMessage(
        '${copy.submitFailedAtPrefix} ${_stageLabel(copy, _submitStage)} '
        '[${e.plugin}:${e.code}]: $message',
      );
    } catch (_) {
      await _rollbackFailedRegistration(user);
      if (!mounted) return;
      _showMessage(
        '${copy.failedToSubmitAtPrefix} ${_stageLabel(copy, _submitStage)}.',
      );
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

  /// Translates the internal `_submitStage` key (an implementation-detail
  /// identifier, not user data) into the copy shown inside failure snackbars.
  String _stageLabel(AppCopy copy, String stage) {
    switch (stage) {
      case 'uploading images':
        return copy.stageUploadingImages;
      case 'creating account':
        return copy.stageCreatingAccount;
      case 'saving driver profile':
        return copy.stageSavingDriverProfile;
      case 'saving approval request':
        return copy.stageSavingApprovalRequest;
      default:
        return stage;
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
    final copy = AppCopy.of(context);
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
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.finalReviewTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  copy.finalReviewDescription,
                  style: const TextStyle(
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
