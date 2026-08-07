import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_router.dart';
import '../data/driver_registration_draft.dart';
import 'registration_widgets.dart';

class DriverVehicleDetailsScreen extends StatefulWidget {
  const DriverVehicleDetailsScreen({super.key});

  @override
  State<DriverVehicleDetailsScreen> createState() =>
      _DriverVehicleDetailsScreenState();
}

class _DriverVehicleDetailsScreenState
    extends State<DriverVehicleDetailsScreen> {
  static const List<String> _malaysiaBrands = [
    'Perodua',
    'Proton',
    'Toyota',
    'Honda',
    'Nissan',
    'Mazda',
    'Mitsubishi',
    'Hyundai',
    'Kia',
    'BMW',
    'Mercedes-Benz',
    'Volkswagen',
    'Ford',
    'Lexus',
    'Subaru',
    'Isuzu',
    'Volvo',
    'Peugeot',
    'Chery',
    'BYD',
  ];
  final List<String> _yearsMake = List<String>.generate(
    17,
    (index) => '${2010 + index}',
  );
  static const List<String> _capacity = ['4', '5', '6', '7', '8'];

  final _draft = DriverRegistrationDraft.instance;
  final _picker = ImagePicker();

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _plateController = TextEditingController();
  final _capacityController = TextEditingController();
  String? _brandValue;
  String? _yearValue;
  String? _capacityValue;
  String? _frontPath;
  String? _backPath;
  String? _leftPath;
  String? _rightPath;

  @override
  void initState() {
    super.initState();
    _brandValue = _draft.brand.isEmpty ? null : _draft.brand;
    _yearValue = _draft.yearMake.isEmpty ? null : _draft.yearMake;
    _capacityValue = _draft.passengerCapacity.isEmpty
        ? null
        : _draft.passengerCapacity;
    _modelController.text = _draft.model;
    _plateController.text = _draft.plateNumber;
    _frontPath = _draft.carPhotoFrontPath;
    _backPath = _draft.carPhotoBackPath;
    _leftPath = _draft.carPhotoLeftPath;
    _rightPath = _draft.carPhotoRightPath;
    if (_brandValue != null) _brandController.text = _brandValue!;
    if (_yearValue != null) _yearController.text = _yearValue!;
    if (_capacityValue != null) _capacityController.text = _capacityValue!;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegistrationScaffold(
      header: const RegistrationHeader(
        title: 'Driver Registration',
        subtitle: 'Step 2 of 3',
      ),
      child: Column(
        children: [
          const SectionTitle('Vehicle Details'),
          _DropdownField(
            hint: 'Brand',
            value: _brandValue,
            items: _malaysiaBrands,
            onChanged: (value) {
              setState(() {
                _brandValue = value;
                _brandController.text = value ?? '';
              });
            },
          ),
          RegistrationField(hint: 'Model', controller: _modelController),
          RegistrationField(
            hint: 'Plate Number',
            controller: _plateController,
            textCapitalization: TextCapitalization.characters,
          ),
          _DropdownField(
            hint: 'Years Make',
            value: _yearValue,
            items: _yearsMake,
            onChanged: (value) {
              setState(() {
                _yearValue = value;
                _yearController.text = value ?? '';
              });
            },
          ),
          _DropdownField(
            hint: 'Passenger Capacity',
            value: _capacityValue,
            items: _capacity,
            onChanged: (value) {
              setState(() {
                _capacityValue = value;
                _capacityController.text = value ?? '';
              });
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Cars Photo',
            style: TextStyle(fontSize: 14, color: Color(0xFF6E6258)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PicturePickerCard(
                  label: 'Front',
                  icon: Icons.add_a_photo_outlined,
                  imagePath: _frontPath,
                  onTap: () => _pickCarPhoto('front'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PicturePickerCard(
                  label: 'Back',
                  icon: Icons.add_a_photo_outlined,
                  imagePath: _backPath,
                  onTap: () => _pickCarPhoto('back'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PicturePickerCard(
                  label: 'Left',
                  icon: Icons.add_a_photo_outlined,
                  imagePath: _leftPath,
                  onTap: () => _pickCarPhoto('left'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PicturePickerCard(
                  label: 'Right',
                  icon: Icons.add_a_photo_outlined,
                  imagePath: _rightPath,
                  onTap: () => _pickCarPhoto('right'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          RegistrationActionButton(
            label: 'Continue',
            onPressed: _continueToDocuments,
          ),
        ],
      ),
    );
  }

  Future<void> _pickCarPhoto(String side) async {
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
        switch (side) {
          case 'front':
            _frontPath = file.path;
            break;
          case 'back':
            _backPath = file.path;
            break;
          case 'left':
            _leftPath = file.path;
            break;
          case 'right':
            _rightPath = file.path;
            break;
        }
      });
    } on MissingPluginException {
      _showMessage(
        'Image picker not ready yet. Run flutter pub get and fully restart app.',
      );
    } on PlatformException catch (e) {
      _showMessage('Unable to open picker: ${e.message ?? e.code}');
    }
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  void _continueToDocuments() {
    if (_brandValue == null ||
        _modelController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty ||
        _yearValue == null ||
        _capacityValue == null) {
      _showMessage('Please complete all vehicle details.');
      return;
    }
    if (_frontPath == null ||
        _backPath == null ||
        _leftPath == null ||
        _rightPath == null) {
      _showMessage('Please upload all 4 car photos: front, back, left, right.');
      return;
    }

    _draft.brand = _brandValue!;
    _draft.model = _modelController.text.trim();
    _draft.plateNumber = _plateController.text.trim().toUpperCase();
    _draft.yearMake = _yearValue!;
    _draft.passengerCapacity = _capacityValue!;
    _draft.carPhotoFrontPath = _frontPath;
    _draft.carPhotoBackPath = _backPath;
    _draft.carPhotoLeftPath = _leftPath;
    _draft.carPhotoRightPath = _rightPath;

    Navigator.of(context).pushNamed(AppRouter.driverDocumentUpload);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final String hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint),
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }
}
