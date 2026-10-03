import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_router.dart';
import '../../../core/settings/app_copy.dart';
import '../data/driver_registration_draft.dart';
import 'registration_widgets.dart';

class DriverDocumentUploadScreen extends StatefulWidget {
  const DriverDocumentUploadScreen({super.key});

  @override
  State<DriverDocumentUploadScreen> createState() =>
      _DriverDocumentUploadScreenState();
}

class _DriverDocumentUploadScreenState
    extends State<DriverDocumentUploadScreen> {
  final _draft = DriverRegistrationDraft.instance;
  final _picker = ImagePicker();

  String? _icFrontPath;
  String? _icBackPath;
  String? _licenseFrontPath;
  String? _licenseBackPath;
  String? _grantPath;

  @override
  void initState() {
    super.initState();
    _icFrontPath = _draft.icPhotoFrontPath;
    _icBackPath = _draft.icPhotoBackPath;
    _licenseFrontPath = _draft.licensePhotoFrontPath;
    _licenseBackPath = _draft.licensePhotoBackPath;
    _grantPath = _draft.grantPhotoPath;
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    return RegistrationScaffold(
      header: RegistrationHeader(
        title: copy.driverRegistrationTitle,
        subtitle: copy.driverRegistrationStep3Subtitle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(copy.documentUploadTitle),
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
          const SizedBox(height: 18),
          RegistrationActionButton(
            label: copy.nextCta,
            onPressed: _goToReviewPage,
          ),
        ],
      ),
    );
  }

  Future<void> _pickSlot(String slot) async {
    final path = await _pickPhotoFlow(slot);
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
      }
    });
  }

  Future<String?> _pickPhotoFlow(String _) async {
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

  void _goToReviewPage() {
    final copy = AppCopy.of(context);
    if (_icFrontPath == null ||
        _icBackPath == null ||
        _licenseFrontPath == null ||
        _licenseBackPath == null ||
        _grantPath == null) {
      _showMessage(copy.completeDocumentPhotosError);
      return;
    }

    _draft.icPhotoFrontPath = _icFrontPath;
    _draft.icPhotoBackPath = _icBackPath;
    _draft.licensePhotoFrontPath = _licenseFrontPath;
    _draft.licensePhotoBackPath = _licenseBackPath;
    _draft.grantPhotoPath = _grantPath;
    Navigator.of(context).pushNamed(AppRouter.driverRegistrationReview);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
