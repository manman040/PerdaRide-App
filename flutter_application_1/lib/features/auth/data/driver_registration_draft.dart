class DriverRegistrationDraft {
  DriverRegistrationDraft._();

  static final DriverRegistrationDraft instance = DriverRegistrationDraft._();

  String email = '';
  String name = '';
  String idCard = '';
  String phone = '';
  String password = '';

  String brand = '';
  String model = '';
  String yearMake = '';
  String plateNumber = '';
  String passengerCapacity = '';

  String? profilePicturePath;
  String? carPhotoFrontPath;
  String? carPhotoBackPath;
  String? carPhotoLeftPath;
  String? carPhotoRightPath;

  String? icPhotoFrontPath;
  String? icPhotoBackPath;
  String? licensePhotoFrontPath;
  String? licensePhotoBackPath;
  String? grantPhotoPath;

  void clear() {
    email = '';
    name = '';
    idCard = '';
    phone = '';
    password = '';
    brand = '';
    model = '';
    yearMake = '';
    plateNumber = '';
    passengerCapacity = '';
    profilePicturePath = null;
    carPhotoFrontPath = null;
    carPhotoBackPath = null;
    carPhotoLeftPath = null;
    carPhotoRightPath = null;
    icPhotoFrontPath = null;
    icPhotoBackPath = null;
    licensePhotoFrontPath = null;
    licensePhotoBackPath = null;
    grantPhotoPath = null;
  }
}
