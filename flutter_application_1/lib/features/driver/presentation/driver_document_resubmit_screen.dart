import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_auth_repository.dart';
import '../../../core/firebase/firebase_database_repository.dart';
import '../../../core/firebase/perdaride_firebase.dart';
import '../../../core/services/cloudinary_upload_service.dart';
import '../../../core/settings/app_copy.dart';
import '../../auth/presentation/registration_widgets.dart';

/// Lets a driver re-upload only the documents an admin flagged as rejected,
/// then flips the application back to `pending` for re-review. Reuses the
/// same upload widgets/publicId convention as the original registration
/// flow (driver_document_upload_screen.dart / driver_vehicle_details_screen.dart)
/// so the admin's image viewer (which keys off those exact publicId
/// substrings) keeps working unchanged.
class DriverDocumentResubmitScreen extends StatefulWidget {
  const DriverDocumentResubmitScreen({
    super.key,
    required this.rejectedDocuments,
    this.rejectionReason,
    this.rejectionMessage,
  });

  final List<String> rejectedDocuments;
  final String? rejectionReason;
  final String? rejectionMessage;

  @override
  State<DriverDocumentResubmitScreen> createState() =>
      _DriverDocumentResubmitScreenState();
}

class _DriverDocumentResubmitScreenState
    extends State<DriverDocumentResubmitScreen> {
  final _picker = ImagePicker();
  final _uploadService = CloudinaryUploadService();
  final _firebase = PerdaRideFirebase.instance;
  late final FirebaseAuthRepository _authRepository = FirebaseAuthRepository(
    _firebase,
  );
  late final FirebaseDatabaseRepository _databaseRepository =
      FirebaseDatabaseRepository(_firebase);

  String? _icFrontPath;
  String? _icBackPath;
  String? _licenseFrontPath;
  String? _licenseBackPath;
  String? _grantPath;
  String? _carFrontPath;
  String? _carBackPath;
  String? _carLeftPath;
  String? _carRightPath;

  bool _isSubmitting = false;

  bool get _needsIdCard => widget.rejectedDocuments.contains('idCard');
  bool get _needsLicense => widget.rejectedDocuments.contains('license');
  bool get _needsCarGrant => widget.rejectedDocuments.contains('carGrant');
  bool get _needsCarImage => widget.rejectedDocuments.contains('carImage');

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final theme = Theme.of(context);
    final hasReasonBanner = (widget.rejectionReason ?? '').isNotEmpty ||
        (widget.rejectionMessage ?? '').isNotEmpty;

    return RegistrationScaffold(
      header: RegistrationHeader(
        title: copy.fixDocumentsTitle,
        subtitle: copy.fixDocumentsSubtitle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasReasonBanner)
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD84315).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD84315).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.whyRejectedLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if ((widget.rejectionReason ?? '').isNotEmpty)
                    Text(
                      widget.rejectionReason!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if ((widget.rejectionMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.rejectionMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_needsIdCard)
            UploadOptionCard(
              title: copy.icPhotoCardTitle,
              slots: [
                UploadDocumentSlot(
                  label: copy.frontLabel,
                  path: _icFrontPath,
                  onTap: () => _pickSlot('ic_front'),
                ),
                UploadDocumentSlot(
                  label: copy.backLabel,
                  path: _icBackPath,
                  onTap: () => _pickSlot('ic_back'),
                ),
              ],
            ),
          if (_needsLicense)
            UploadOptionCard(
              title: copy.licensePhotoCardTitle,
              slots: [
                UploadDocumentSlot(
                  label: copy.frontLabel,
                  path: _licenseFrontPath,
                  onTap: () => _pickSlot('license_front'),
                ),
                UploadDocumentSlot(
                  label: copy.backLabel,
                  path: _licenseBackPath,
                  onTap: () => _pickSlot('license_back'),
                ),
              ],
            ),
          if (_needsCarGrant)
            UploadOptionCard(
              title: copy.grantPhotoCardTitle,
              slots: [
                UploadDocumentSlot(
                  label: copy.photoSlotLabel,
                  path: _grantPath,
                  onTap: () => _pickSlot('grant'),
                ),
              ],
            ),
          if (_needsCarImage) ...[
            Row(
              children: [
                Expanded(
                  child: PicturePickerCard(
                    label: copy.frontLabel,
                    icon: Icons.add_a_photo_outlined,
                    imagePath: _carFrontPath,
                    onTap: () => _pickSlot('car_front'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PicturePickerCard(
                    label: copy.backLabel,
                    icon: Icons.add_a_photo_outlined,
                    imagePath: _carBackPath,
                    onTap: () => _pickSlot('car_back'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PicturePickerCard(
                    label: copy.leftLabel,
                    icon: Icons.add_a_photo_outlined,
                    imagePath: _carLeftPath,
                    onTap: () => _pickSlot('car_left'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PicturePickerCard(
                    label: copy.rightLabel,
                    icon: Icons.add_a_photo_outlined,
                    imagePath: _carRightPath,
                    onTap: () => _pickSlot('car_right'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 8),
          RegistrationActionButton(
            label: _isSubmitting ? copy.resubmittingCta : copy.resubmitCta,
            onPressed: _isSubmitting ? () {} : _resubmit,
          ),
        ],
      ),
    );
  }

  Future<void> _pickSlot(String slot) async {
    final path = await _pickImage();
    if (path == null) return;
    setState(() {
      switch (slot) {
        case 'ic_front':
          _icFrontPath = path;
        case 'ic_back':
          _icBackPath = path;
        case 'license_front':
          _licenseFrontPath = path;
        case 'license_back':
          _licenseBackPath = path;
        case 'grant':
          _grantPath = path;
        case 'car_front':
          _carFrontPath = path;
        case 'car_back':
          _carBackPath = path;
        case 'car_left':
          _carLeftPath = path;
        case 'car_right':
          _carRightPath = path;
      }
    });
  }

  Future<String?> _pickImage() async {
    final copy = AppCopy.of(context);
    try {
      final source = await _pickSource();
      if (source == null) return null;
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 70,
      );
      return file?.path;
    } on MissingPluginException {
      _showMessage(copy.imagePickerNotReadyError);
      return null;
    } on PlatformException catch (e) {
      _showMessage('${copy.unableToOpenPickerPrefix} ${e.message ?? e.code}');
      return null;
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

  Future<void> _resubmit() async {
    final copy = AppCopy.of(context);
    if (_isSubmitting) return;

    if (_needsIdCard && (_icFrontPath == null || _icBackPath == null)) {
      _showMessage(copy.completeAllFlaggedDocumentsError);
      return;
    }
    if (_needsLicense &&
        (_licenseFrontPath == null || _licenseBackPath == null)) {
      _showMessage(copy.completeAllFlaggedDocumentsError);
      return;
    }
    if (_needsCarGrant && _grantPath == null) {
      _showMessage(copy.completeAllFlaggedDocumentsError);
      return;
    }
    if (_needsCarImage &&
        (_carFrontPath == null ||
            _carBackPath == null ||
            _carLeftPath == null ||
            _carRightPath == null)) {
      _showMessage(copy.completeAllFlaggedDocumentsError);
      return;
    }

    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final approvalUpdates = <String, dynamic>{};
      final driverUpdates = <String, dynamic>{};

      if (_needsIdCard) {
        final frontUrl = await _upload(
          _icFrontPath!,
          'drivers/$uid/documents',
          'ic_front_photo',
        );
        final backUrl = await _upload(
          _icBackPath!,
          'drivers/$uid/documents',
          'ic_back_photo',
        );
        for (final map in [approvalUpdates, driverUpdates]) {
          map['icPhotoFrontPath'] = frontUrl;
          map['ic_photo_front_path'] = frontUrl;
          map['icPhotoPath'] = frontUrl;
          map['ic_photo_path'] = frontUrl;
          map['icPhotoBackPath'] = backUrl;
          map['ic_photo_back_path'] = backUrl;
        }
        approvalUpdates['idCardRejected'] = false;
        approvalUpdates['id_card_rejected'] = false;
        approvalUpdates['document_decisions/idCard'] = 'accepted';
      }

      if (_needsLicense) {
        final frontUrl = await _upload(
          _licenseFrontPath!,
          'drivers/$uid/documents',
          'license_front_photo',
        );
        final backUrl = await _upload(
          _licenseBackPath!,
          'drivers/$uid/documents',
          'license_back_photo',
        );
        for (final map in [approvalUpdates, driverUpdates]) {
          map['licensePhotoFrontPath'] = frontUrl;
          map['license_photo_front_path'] = frontUrl;
          map['licensePhotoPath'] = frontUrl;
          map['license_photo_path'] = frontUrl;
          map['licensePhotoBackPath'] = backUrl;
          map['license_photo_back_path'] = backUrl;
        }
        approvalUpdates['licenseRejected'] = false;
        approvalUpdates['license_rejected'] = false;
        approvalUpdates['document_decisions/license'] = 'accepted';
      }

      if (_needsCarGrant) {
        final url = await _upload(
          _grantPath!,
          'drivers/$uid/documents',
          'grant_photo',
        );
        for (final map in [approvalUpdates, driverUpdates]) {
          map['grantPhotoPath'] = url;
          map['grant_photo_path'] = url;
        }
        approvalUpdates['carGrantRejected'] = false;
        approvalUpdates['car_grant_rejected'] = false;
        approvalUpdates['document_decisions/carGrant'] = 'accepted';
      }

      if (_needsCarImage) {
        final frontUrl = await _upload(
          _carFrontPath!,
          'drivers/$uid/car',
          'car_front_photo',
        );
        final backUrl = await _upload(
          _carBackPath!,
          'drivers/$uid/car',
          'car_back_photo',
        );
        final leftUrl = await _upload(
          _carLeftPath!,
          'drivers/$uid/car',
          'car_left_photo',
        );
        final rightUrl = await _upload(
          _carRightPath!,
          'drivers/$uid/car',
          'car_right_photo',
        );
        for (final map in [approvalUpdates, driverUpdates]) {
          map['carPhotoFrontPath'] = frontUrl;
          map['car_photo_front_path'] = frontUrl;
          map['carPhotoPath'] = frontUrl;
          map['car_photo_path'] = frontUrl;
          map['carPhotoBackPath'] = backUrl;
          map['car_photo_back_path'] = backUrl;
          map['carPhotoLeftPath'] = leftUrl;
          map['car_photo_left_path'] = leftUrl;
          map['carPhotoRightPath'] = rightUrl;
          map['car_photo_right_path'] = rightUrl;
        }
        approvalUpdates['carImageRejected'] = false;
        approvalUpdates['car_image_rejected'] = false;
        approvalUpdates['document_decisions/carImage'] = 'accepted';
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      approvalUpdates['rejected_documents'] = <String>[];
      approvalUpdates['needs_resubmission'] = false;
      approvalUpdates['status'] = 'pending';
      approvalUpdates['registrationStatus'] = 'pending';
      approvalUpdates['resubmittedAt'] = now;
      approvalUpdates['resubmitted_at'] = now;

      driverUpdates['registrationStatus'] = 'pending';
      driverUpdates['status'] = 'pending';
      driverUpdates['updatedAt'] = now;

      await _databaseRepository.updateData(
        'driver_approvals/$uid',
        approvalUpdates,
      );
      await _databaseRepository.updateData('drivers/$uid', driverUpdates);

      if (!mounted) return;
      _showMessage(copy.resubmitSuccessMessage);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _showMessage('${copy.resubmitFailedError}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String> _upload(String localPath, String folder, String publicId) {
    if (!File(localPath).existsSync()) {
      throw Exception('Selected image could not be found on device.');
    }
    return _uploadService.uploadFile(
      localPath: localPath,
      folder: folder,
      publicId: publicId,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
