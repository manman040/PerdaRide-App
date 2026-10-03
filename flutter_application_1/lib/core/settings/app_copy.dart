import 'package:flutter/material.dart';

import 'app_settings_controller.dart';

class AppCopy {
  const AppCopy._(this.language);

  final AppLanguage language;

  static AppCopy of(BuildContext context) {
    final controller = AppSettingsScope.of(context);
    return AppCopy._(controller.value.language);
  }

  bool get _isMalay => language == AppLanguage.bahasaMelayu;

  String get profileMenu => _isMalay ? 'PROFIL SAYA' : 'MY PROFILE';
  String get notificationsMenu => _isMalay ? 'PEMBERITAHUAN' : 'NOTIFICATION';
  String get settingsMenu => _isMalay ? 'TETAPAN' : 'SETTINGS';
  String get logoutMenu => _isMalay ? 'LOG KELUAR' : 'LOG OUT';
  String get locationDetected =>
      _isMalay ? 'Lokasi Dikesan' : 'Location Detected';
  String get pickupLocation => _isMalay ? 'Lokasi Ambil' : 'Pickup Location';
  String get loadingPlace =>
      _isMalay ? 'Memuatkan lokasi...' : 'Loading place...';
  String get searchHint => _isMalay ? 'Mahu ke mana?' : 'Where to?';
  String get pickupRequiredMessage => _isMalay
      ? 'Pilih lokasi ambil dahulu dengan mengetik peta atau membuat carian.'
      : 'Select pickup location first by tapping map or searching.';
  String get locationNotFound => _isMalay
      ? 'Lokasi tidak dijumpai. Cuba kata kunci lain.'
      : 'Location not found. Try another keyword.';
  String get featureNotConnected => _isMalay
      ? 'Fungsi ini belum disambungkan.'
      : 'This feature is not connected yet.';
  String get profileTitle => _isMalay ? 'Profil Saya' : 'My Profile';
  String get notificationsTitle => _isMalay ? 'Pemberitahuan' : 'Notifications';
  String get settingsTitle => _isMalay ? 'Tetapan' : 'Settings';
  String get contactInformation =>
      _isMalay ? 'Maklumat Akaun' : 'Account Information';
  String get fullName => _isMalay ? 'Nama Penuh' : 'Full Name';
  String get email => 'Email';
  String get phone => _isMalay ? 'Nombor Telefon' : 'Phone Number';
  String get idCard => _isMalay ? 'Kad Pengenalan' : 'Identification Card';
  String get accountType => _isMalay ? 'Jenis Akaun' : 'Account Type';
  String get passengerRole => _isMalay ? 'Penumpang' : 'Passenger';
  String get driverRole => _isMalay ? 'Pemandu' : 'Driver';
  String get unknownValue => _isMalay ? 'Belum tersedia' : 'Not available';
  String get profileDescription => _isMalay
      ? 'Lihat maklumat yang disimpan untuk akaun Urban Drive anda.'
      : 'View the details stored for your Urban Drive account.';
  String get driverProfileTitle =>
      _isMalay ? 'Profil Pemandu' : 'Driver Profile';
  String get driverProfileDescription => _isMalay
      ? 'Semak butiran akaun dan kenderaan pemandu anda.'
      : 'Review your driver account and vehicle details.';
  String get driverVehicleLabel => _isMalay ? 'Kenderaan' : 'Vehicle';
  String get vehicleYearLabel => _isMalay ? 'Tahun Kenderaan' : 'Vehicle Year';
  String get capacityLabel =>
      _isMalay ? 'Kapasiti Penumpang' : 'Passenger Capacity';
  String get driverHistoryMenu => _isMalay ? 'SEJARAH' : 'HISTORY';
  String get totalEarningMenu =>
      _isMalay ? 'JUMLAH PENDAPATAN' : 'TOTAL EARNING';
  String get driverDashboardLabel =>
      _isMalay ? 'Papan Pemuka Pemandu' : 'Driver Dashboard';
  String get driverDashboardSubtitle => _isMalay
      ? 'Urus perjalanan dan profil anda'
      : 'Manage your rides and profile';
  String get driverHistoryTitle =>
      _isMalay ? 'Sejarah Perjalanan' : 'Ride History';
  String get totalEarningTitle =>
      _isMalay ? 'Jumlah Pendapatan' : 'Total Earning';
  String get pickupHistoryLabel => _isMalay ? 'Ambil' : 'Pickup';
  String get dropoffHistoryLabel => _isMalay ? 'Hantar' : 'Drop-off';
  // --- Rider profile: ride history ---
  String get rideHistoryTitle =>
      _isMalay ? 'Sejarah Perjalanan' : 'Ride History';
  String get rideHistoryDescription => _isMalay
      ? 'Perjalanan anda yang lepas, terkini dahulu.'
      : 'Your past rides, newest first.';
  String get rideHistoryEmpty => _isMalay
      ? 'Tiada perjalanan lagi. Perjalanan yang selesai akan dipaparkan di sini.'
      : 'No rides yet. Rides you complete will appear here.';
  String get rideHistoryLoadFailed => _isMalay
      ? 'Sejarah perjalanan tidak dapat dimuatkan.'
      : 'Could not load your ride history.';
  String get rideHistoryRetryCta => _isMalay ? 'Cuba lagi' : 'Try again';
  String get rideHistoryDriverLabel => _isMalay ? 'Pemandu' : 'Driver';
  String get rideHistoryNoDriver =>
      _isMalay ? 'Tiada pemandu ditetapkan' : 'No driver assigned';
  String get rideHistoryUnknownDriver => _isMalay ? 'Pemandu' : 'Driver';
  String get rideHistoryCompletedChip => _isMalay ? 'Selesai' : 'Completed';
  String get rideHistoryCancelledChip => _isMalay ? 'Dibatalkan' : 'Cancelled';
  String rideHistoryShowAll(int count) =>
      _isMalay ? 'Lihat semua ($count)' : 'Show all ($count)';
  String get rideHistoryShowLess => _isMalay ? 'Tunjuk kurang' : 'Show less';
  String get totalCommissionLabel =>
      _isMalay ? 'Jumlah Komisen' : 'Total Commission';
  String get payAllCommissionLabel =>
      _isMalay ? 'Bayar Semua Komisen' : 'Pay All Commission';
  String get ridesLabel => _isMalay ? 'perjalanan' : 'rides';
  String get applyLabel => _isMalay ? 'Guna' : 'Apply';
  String get resetLabel => _isMalay ? 'Set Semula' : 'Reset';
  String get commissionLabel => _isMalay ? 'Komisen' : 'Commission';
  String get payLabel => _isMalay ? 'Bayar' : 'Pay';
  String get noNotificationsTitle =>
      _isMalay ? 'Tiada pemberitahuan lagi' : 'No notifications yet';
  String get noNotificationsDescription => _isMalay
      ? 'Kalau anda mahu cepat siap, utamakan push notification dahulu. Skrin ini boleh kekal sebagai pusat sejarah notifikasi kemudian.'
      : 'If you want to move faster, prioritize push notifications first. This screen can stay as the notification history center later.';
  String get pushNotificationHint => _isMalay
      ? 'Cadangan: sambungkan FCM untuk status tempahan, pemandu diterima, dan kemas kini perjalanan.'
      : 'Suggestion: connect FCM for booking status, driver acceptance, and ride updates.';
  String get appearanceSection => _isMalay ? 'Penampilan' : 'Appearance';
  String get darkModeTitle => _isMalay ? 'Mod Gelap' : 'Dark Mode';
  String get darkModeDescription => _isMalay
      ? 'Gunakan tema gelap di seluruh aplikasi.'
      : 'Use a darker color palette across the app.';
  String get languageSection => _isMalay ? 'Bahasa' : 'Language';
  String get languageDescription => _isMalay
      ? 'Pilih bahasa paparan utama aplikasi.'
      : 'Choose the main display language for the app.';
  String get english => 'English';
  String get bahasaMelayu => 'Bahasa Melayu';
  String get systemDefault => _isMalay ? 'Ikut sistem' : 'Follow system';
  String get lightMode => _isMalay ? 'Cerah' : 'Light';
  String get darkMode => _isMalay ? 'Gelap' : 'Dark';
  String get notificationsSection =>
      _isMalay ? 'Pemberitahuan' : 'Notifications';
  String get pushNotificationsToggleTitle =>
      _isMalay ? 'Pemberitahuan Tolak' : 'Push Notifications';
  String get pushNotificationsToggleDescription => _isMalay
      ? 'Terima makluman segera semasa aplikasi dibuka untuk kemas kini tempahan.'
      : 'Get instant alerts while the app is open for booking updates.';
  String get settingsFooter => _isMalay
      ? 'Boleh tambah kawalan lain kemudian seperti privasi, bantuan, dan pengurusan akaun.'
      : 'You can add more controls later like privacy, help, and account management.';
  String get addLocationCta => _isMalay ? 'Tambah Lokasi' : 'Add Location';

  // Welcome screen
  String get welcomeBack => _isMalay ? 'Selamat Kembali' : 'Welcome Back';
  String get welcomeTagline => _isMalay
      ? 'Tempahan penumpang dan operasi pemandu\ndalam satu pengalaman yang kemas.'
      : 'Passenger booking and driver operations\nin one clean experience.';
  String get loginCta => _isMalay ? 'LOG MASUK' : 'LOGIN';
  String get signUpCta => _isMalay ? 'DAFTAR' : 'SIGN UP';
  String get closeSignUpCta => _isMalay ? 'TUTUP PENDAFTARAN' : 'CLOSE SIGN UP';
  String get registerAsUser =>
      _isMalay ? 'Daftar sebagai Pengguna' : 'Register as User';
  String get registerAsDriver =>
      _isMalay ? 'Daftar sebagai Pemandu' : 'Register as Driver';

  // Login screen
  String get helloGreeting => _isMalay ? 'Helo' : 'Hello';
  String get signInGreeting => _isMalay ? 'Log masuk!' : 'Sign in!';
  String get gmailLabel => _isMalay ? 'Emel' : 'Gmail';
  String get passwordLabel => _isMalay ? 'Kata Laluan' : 'Password';
  String get forgotPasswordCta =>
      _isMalay ? 'Lupa kata laluan?' : 'Forgot password?';
  String get signingInCta => _isMalay ? 'MELOG MASUK...' : 'SIGNING IN...';
  String get signInCta => _isMalay ? 'LOG MASUK' : 'SIGN IN';
  String get noAccountPrompt =>
      _isMalay ? 'Tiada akaun?' : "Don't have account?";
  String get closeLabel => _isMalay ? 'Tutup' : 'Close';
  String get signUpLinkCta => _isMalay ? 'Daftar' : 'Sign up';
  String get enterEmailPasswordError => _isMalay
      ? 'Sila masukkan emel dan kata laluan.'
      : 'Please enter email and password.';
  String get loginFailedError => _isMalay
      ? 'Log masuk gagal. Sila cuba lagi.'
      : 'Login failed. Please try again.';
  String get profileNotFoundError => _isMalay
      ? 'Profil akaun tidak dijumpai. Sila daftar semula.'
      : 'Account profile not found. Please register again.';
  String get invalidCredentialError => _isMalay
      ? 'Emel atau kata laluan tidak sah.'
      : 'Invalid email or password.';
  String get networkIssueError => _isMalay
      ? 'Isu rangkaian. Sila semak sambungan anda.'
      : 'Network issue. Please check your connection.';
  String get signInFailedError => _isMalay
      ? 'Log masuk gagal. Sila cuba lagi.'
      : 'Sign in failed. Please try again.';
  String get accountDisabledError => _isMalay
      ? 'Akaun anda telah dinyahaktifkan oleh pentadbir. Sila hubungi pihak Urban Drive.'
      : 'Your account has been disabled by the administrator. Please contact Urban Drive.';

  // Forgot password screen
  String get forgotTitle => _isMalay ? 'Lupa' : 'Forgot';
  String get passwordTitle => _isMalay ? 'Kata Laluan?' : 'Password?';
  String get enterEmailError => _isMalay
      ? 'Sila masukkan alamat emel anda.'
      : 'Please enter your email address.';
  String get invalidEmailError =>
      _isMalay ? 'Alamat emel tidak sah.' : 'Invalid email address.';
  String get noAccountForEmailError => _isMalay
      ? 'Tiada akaun dijumpai untuk emel tersebut.'
      : 'No account found for that email.';
  String get resetEmailFailedError => _isMalay
      ? 'Gagal menghantar emel set semula. Sila cuba lagi.'
      : 'Could not send reset email. Please try again.';
  String get resetEmailSentMessage => _isMalay
      ? 'Pautan set semula kata laluan telah dihantar ke emel anda. Sila semak peti masuk anda.'
      : 'A password reset link has been sent to your email. Please check your inbox.';
  String get backToLogin => _isMalay ? 'Kembali ke Log Masuk' : 'Back to Login';
  String get forgotPasswordDescription => _isMalay
      ? 'Masukkan alamat emel yang berkaitan dengan akaun anda dan kami akan menghantar pautan untuk menetapkan semula kata laluan anda.'
      : "Enter the email address associated with your account and we'll send you a link to reset your password.";
  String get sendingCta => _isMalay ? 'MENGHANTAR...' : 'SENDING...';
  String get sendResetLinkCta =>
      _isMalay ? 'HANTAR PAUTAN SET SEMULA' : 'SEND RESET LINK';

  // Change password screen
  String get changeTitle => _isMalay ? 'Tukar' : 'Change';
  String get fillAllFieldsError =>
      _isMalay ? 'Sila isi semua ruangan.' : 'Please fill in all fields.';
  String get passwordTooShortError => _isMalay
      ? 'Kata laluan baharu mesti sekurang-kurangnya 6 aksara.'
      : 'New password must be at least 6 characters.';
  String get passwordMismatchError => _isMalay
      ? 'Kata laluan baharu dan pengesahan tidak sepadan.'
      : 'New password and confirmation do not match.';
  String get currentPasswordIncorrectError => _isMalay
      ? 'Kata laluan semasa tidak betul.'
      : 'Current password is incorrect.';
  String get passwordTooWeakError => _isMalay
      ? 'Kata laluan baharu terlalu lemah.'
      : 'New password is too weak.';
  String get changePasswordFailedError => _isMalay
      ? 'Gagal menukar kata laluan. Sila cuba lagi.'
      : 'Could not change password. Please try again.';
  String get passwordUpdatedMessage => _isMalay
      ? 'Kata laluan anda telah dikemas kini.'
      : 'Your password has been updated.';
  String get backToProfile =>
      _isMalay ? 'Kembali ke Profil' : 'Back to Profile';
  String get changePasswordDescription => _isMalay
      ? 'Masukkan kata laluan semasa anda dan pilih kata laluan baharu.'
      : 'Enter your current password and choose a new one.';
  String get currentPasswordHint =>
      _isMalay ? 'Kata laluan semasa' : 'Current password';
  String get newPasswordHint =>
      _isMalay ? 'Kata laluan baharu' : 'New password';
  String get confirmNewPasswordHint =>
      _isMalay ? 'Sahkan kata laluan baharu' : 'Confirm new password';
  String get savingCta => _isMalay ? 'MENYIMPAN...' : 'SAVING...';
  String get updatePasswordCta =>
      _isMalay ? 'KEMAS KINI KATA LALUAN' : 'UPDATE PASSWORD';
  String get logoutSuccess =>
      _isMalay ? 'Anda telah log keluar.' : 'You have been logged out.';
  String get logoutError => _isMalay
      ? 'Log keluar gagal. Sila cuba lagi.'
      : 'Sign out failed. Please try again.';

  // Splash screen
  String get splashTagline => _isMalay
      ? 'Perkhidmatan penumpang dan pemandu dalam satu aplikasi.'
      : 'Passenger and driver services in one app.';

  // Booking chat sheet (shared)
  String get chatWithPassengerTitle =>
      _isMalay ? 'Sembang dengan Penumpang' : 'Chat with Passenger';
  String get chatWithDriverTitle =>
      _isMalay ? 'Sembang dengan Pemandu' : 'Chat with Driver';
  String get noMessagesYet =>
      _isMalay ? 'Belum ada mesej. Ucap hai!' : 'No messages yet. Say hello!';
  String get typeMessageHint =>
      _isMalay ? 'Taip mesej anda' : 'Type your message';
  String get sendMessageFailedGeneric =>
      _isMalay ? 'Gagal menghantar mesej.' : 'Failed to send message.';
  String get newMessageFromDriverTitle =>
      _isMalay ? 'Mesej baharu daripada pemandu' : 'New message from driver';
  String get newMessageFromPassengerTitle => _isMalay
      ? 'Mesej baharu daripada penumpang'
      : 'New message from passenger';
  String get youLabel => _isMalay ? 'Anda' : 'You';
  String get markAllRead => _isMalay ? 'Tanda semua dibaca' : 'Mark all read';

  // === REGISTRATION_SCREENS_SECTION ===
  // Shared registration field labels/hints
  String get nameFieldLabel => _isMalay ? 'Nama' : 'Name';
  String get phoneFieldHint => _isMalay ? 'No. Telefon' : 'No. Phone';
  String get confirmPasswordHint =>
      _isMalay ? 'Sahkan Kata Laluan' : 'Confirm Password';
  String get profilePictureLabel =>
      _isMalay ? 'Gambar Profil' : 'Profile Picture';
  String get brandFieldLabel => _isMalay ? 'Jenama' : 'Brand';
  String get modelFieldLabel => _isMalay ? 'Model' : 'Model';
  String get plateNumberFieldLabel => _isMalay ? 'Nombor Plat' : 'Plate Number';
  String get yearsMakeFieldLabel => _isMalay ? 'Tahun Pembuatan' : 'Years Make';
  String get frontLabel => _isMalay ? 'Depan' : 'Front';
  String get backLabel => _isMalay ? 'Belakang' : 'Back';
  String get leftLabel => _isMalay ? 'Kiri' : 'Left';
  String get rightLabel => _isMalay ? 'Kanan' : 'Right';
  String get phoneLabel => _isMalay ? 'Telefon' : 'Phone';
  String get idCardShortLabel => _isMalay ? 'No. IC' : 'ID Card';

  // Shared registration actions
  String get continueCta => _isMalay ? 'Teruskan' : 'Continue';
  String get nextCta => _isMalay ? 'Seterusnya' : 'Next';
  String get cameraOption => _isMalay ? 'Kamera' : 'Camera';
  String get galleryOption => _isMalay ? 'Galeri' : 'Gallery';

  // Shared registration errors
  String get imagePickerNotReadyError => _isMalay
      ? 'Pemilih imej belum sedia. Jalankan flutter pub get dan mulakan semula aplikasi.'
      : 'Image picker not ready yet. Run flutter pub get and fully restart app.';
  String get unableToOpenPickerPrefix =>
      _isMalay ? 'Tidak dapat membuka pemilih:' : 'Unable to open picker:';
  String get validEmailError =>
      _isMalay ? 'Sila masukkan emel yang sah.' : 'Please enter a valid email.';
  String get passwordMinLengthError => _isMalay
      ? 'Kata laluan mesti sekurang-kurangnya 6 aksara.'
      : 'Password must be at least 6 characters.';
  String get passwordsDoNotMatchError =>
      _isMalay ? 'Kata laluan tidak sepadan.' : 'Passwords do not match.';
  String get emailAlreadyRegisteredError => _isMalay
      ? 'Emel ini telah didaftarkan.'
      : 'This email is already registered.';
  String get weakPasswordError =>
      _isMalay ? 'Kata laluan terlalu lemah.' : 'Password is too weak.';
  String get networkErrorTryAgainError => _isMalay
      ? 'Ralat rangkaian. Semak sambungan anda dan cuba lagi.'
      : 'Network error. Check your connection and try again.';
  String get registrationFailedError =>
      _isMalay ? 'Pendaftaran gagal.' : 'Registration failed.';

  // User registration screen
  String get userRegistrationTitle =>
      _isMalay ? 'Pendaftaran Pengguna' : 'User Registration';
  String get userRegistrationSubtitle =>
      _isMalay ? 'Cipta akaun penumpang anda' : 'Create your passenger account';
  String get creatingAccountCta =>
      _isMalay ? 'Mencipta Akaun...' : 'Creating Account...';
  String get submitCta => _isMalay ? 'Hantar' : 'Submit';
  String get enterYourEmailError =>
      _isMalay ? 'Sila masukkan emel anda' : 'Please enter your email';
  String get enterYourNameError =>
      _isMalay ? 'Sila masukkan nama anda' : 'Please enter your name';
  String get enterIdCardError => _isMalay
      ? 'Sila masukkan kad pengenalan anda'
      : 'Please enter your identification card';
  String get enterPhoneNumberError => _isMalay
      ? 'Sila masukkan nombor telefon anda'
      : 'Please enter your phone number';
  String get enterYourPasswordError => _isMalay
      ? 'Sila masukkan kata laluan anda'
      : 'Please enter your password';
  String get confirmYourPasswordError => _isMalay
      ? 'Sila sahkan kata laluan anda'
      : 'Please confirm your password';
  String get userAccountCreationFailedError => _isMalay
      ? 'Gagal mencipta akaun pengguna. Sila cuba lagi.'
      : 'User account creation failed. Please try again.';
  String get registrationFailedTryAgainError => _isMalay
      ? 'Pendaftaran gagal. Sila cuba lagi.'
      : 'Registration failed. Please try again.';
  String get accountCreatedSuccessMessage =>
      _isMalay ? 'Akaun berjaya dicipta!' : 'Account created successfully!';

  // Driver registration flow (shared across steps)
  String get driverRegistrationTitle =>
      _isMalay ? 'Pendaftaran Pemandu' : 'Driver Registration';
  String get driverRegistrationStep1Subtitle =>
      _isMalay ? 'Langkah 1 daripada 3' : 'Step 1 of 3';
  String get driverRegistrationStep2Subtitle =>
      _isMalay ? 'Langkah 2 daripada 3' : 'Step 2 of 3';
  String get driverRegistrationStep3Subtitle =>
      _isMalay ? 'Langkah 3 daripada 3' : 'Step 3 of 3';

  // Driver vehicle details screen
  String get vehicleDetailsTitle =>
      _isMalay ? 'Butiran Kenderaan' : 'Vehicle Details';
  String get carsPhotoLabel => _isMalay ? 'Gambar Kereta' : 'Cars Photo';
  String get completeVehicleDetailsError => _isMalay
      ? 'Sila lengkapkan semua butiran kenderaan.'
      : 'Please complete all vehicle details.';
  String get uploadAllCarPhotosError => _isMalay
      ? 'Sila muat naik semua 4 gambar kereta: depan, belakang, kiri, kanan.'
      : 'Please upload all 4 car photos: front, back, left, right.';

  // Driver document upload screen
  String get documentUploadTitle =>
      _isMalay ? 'Muat Naik Dokumen' : 'Document Upload';
  String get icPhotoCardTitle => _isMalay ? 'Gambar IC' : 'IC Photo';
  String get grantPhotoCardTitle => _isMalay ? 'Gambar Geran' : 'Grant Photo';
  String get licensePhotoCardTitle =>
      _isMalay ? 'Gambar Lesen' : 'License Photo';
  String get photoSlotLabel => _isMalay ? 'Gambar' : 'Photo';
  String get completeDocumentPhotosError => _isMalay
      ? 'Sila lengkapkan semua gambar dokumen.'
      : 'Please complete all document photos.';

  // Driver registration review screen
  String get reviewAndSubmitSubtitle =>
      _isMalay ? 'Semak & Hantar' : 'Review & Submit';
  String get finalReviewTitle => _isMalay ? 'Semakan Akhir' : 'Final Review';
  String get finalReviewDescription => _isMalay
      ? 'Semak pendaftaran pemandu anda sebelum menghantarnya kepada admin.'
      : 'Check your driver registration before sending it to admin.';
  String get personalInformationTitle =>
      _isMalay ? 'Maklumat Peribadi' : 'Personal Information';
  String get vehicleInformationTitle =>
      _isMalay ? 'Maklumat Kenderaan' : 'Vehicle Information';
  String get documentChecklistTitle =>
      _isMalay ? 'Senarai Semak Dokumen' : 'Document Checklist';
  String get uploadedImagesTitle =>
      _isMalay ? 'Gambar Dimuat Naik' : 'Uploaded Images';
  String get profilePhotoChipLabel =>
      _isMalay ? 'Gambar Profil' : 'Profile Photo';
  String get carFrontChipLabel => _isMalay ? 'Kereta Depan' : 'Car Front';
  String get carBackChipLabel => _isMalay ? 'Kereta Belakang' : 'Car Back';
  String get carLeftChipLabel => _isMalay ? 'Kereta Kiri' : 'Car Left';
  String get carRightChipLabel => _isMalay ? 'Kereta Kanan' : 'Car Right';
  String get icFrontChipLabel => _isMalay ? 'IC Depan' : 'IC Front';
  String get icBackChipLabel => _isMalay ? 'IC Belakang' : 'IC Back';
  String get licenseFrontChipLabel =>
      _isMalay ? 'Lesen Depan' : 'License Front';
  String get licenseBackChipLabel =>
      _isMalay ? 'Lesen Belakang' : 'License Back';
  String get grantChipLabel => _isMalay ? 'Geran' : 'Grant';
  String get profileSectionLabel => _isMalay ? 'Profil' : 'Profile';
  String get carSectionLabel => _isMalay ? 'Kereta' : 'Car';
  String get icSectionLabel => 'IC';
  String get licenseSectionLabel => _isMalay ? 'Lesen' : 'License';
  String get otherSectionLabel => _isMalay ? 'Lain-lain' : 'Other';
  String get noImagesUploadedMessage =>
      _isMalay ? 'Tiada gambar dimuat naik lagi.' : 'No images uploaded yet.';
  String get reviewCarefullyNotice => _isMalay
      ? 'Sila semak maklumat anda dengan teliti sebelum menghantar. Permohonan anda akan dihantar kepada admin untuk kelulusan.'
      : 'Please review your information carefully before submitting. '
            'Your application will be sent to admin for approval.';
  String get submittingCta => _isMalay ? 'Menghantar...' : 'Submitting...';
  String get submitApplicationCta =>
      _isMalay ? 'Hantar Permohonan' : 'Submit Application';
  String get registrationIncompleteError => _isMalay
      ? 'Data pendaftaran tidak lengkap. Sila semak langkah sebelumnya.'
      : 'Registration data is incomplete. Please check previous steps.';
  String get driverAccountCreationFailedError => _isMalay
      ? 'Gagal mencipta akaun pemandu.'
      : 'Driver account creation failed.';
  String get driverRegistrationSubmittedMessage => _isMalay
      ? 'Pendaftaran pemandu berjaya dihantar!'
      : 'Driver registration submitted successfully!';
  String get submitFailedAtPrefix =>
      _isMalay ? 'Penyerahan gagal pada' : 'Submit failed at';
  String get failedToSubmitAtPrefix => _isMalay
      ? 'Gagal menghantar pendaftaran pemandu pada'
      : 'Failed to submit driver registration at';
  String get stageUploadingImages =>
      _isMalay ? 'memuat naik gambar' : 'uploading images';
  String get stageCreatingAccount =>
      _isMalay ? 'mencipta akaun' : 'creating account';
  String get stageSavingDriverProfile =>
      _isMalay ? 'menyimpan profil pemandu' : 'saving driver profile';
  String get stageSavingApprovalRequest =>
      _isMalay ? 'menyimpan permintaan kelulusan' : 'saving approval request';
  // Add new getters for driver/user registration flow screens above this line.
  // === END REGISTRATION_SCREENS_SECTION ===

  // === PASSENGER_FLOW_SECTION ===
  // Add new getters for passenger booking-flow screens above this line.
  String get detectingLocationLabel =>
      _isMalay ? 'Mengesan lokasi semasa...' : 'Detecting current location...';
  String get detectingShortLabel => _isMalay ? 'Mengesan...' : 'Detecting...';
  String get detectMyLocationCta =>
      _isMalay ? 'Kesan Lokasi Saya' : 'Detect My Location';
  String get locationServiceDisabledError => _isMalay
      ? 'Sila hidupkan perkhidmatan lokasi pada telefon anda.'
      : 'Please enable location service on your phone.';
  String get locationPermissionRequiredError => _isMalay
      ? 'Kebenaran lokasi diperlukan.'
      : 'Location permission is required.';
  String get locationDetectionFailedError => _isMalay
      ? 'Tidak dapat mengesan lokasi anda sekarang.'
      : 'Unable to detect your location now.';
  String get loadingProfileLabel =>
      _isMalay ? 'Memuatkan profil...' : 'Loading profile...';
  String get dropoffLocationTitle =>
      _isMalay ? 'Lokasi Hantar' : 'Drop Off Location';
  String get searchDropoffHint =>
      _isMalay ? 'Cari lokasi hantar' : 'Search drop-off location';
  String get dropoffTitleLabel => _isMalay ? 'Hantar' : 'Drop Off';
  String get resolvingLocationName =>
      _isMalay ? 'Menyelesaikan nama lokasi...' : 'Resolving location name...';
  String get confirmDropoffCta =>
      _isMalay ? 'Sahkan Hantar' : 'Confirm Drop Off';
  String get dropoffNotFoundError => _isMalay
      ? 'Lokasi hantar tidak dijumpai.'
      : 'Drop-off location not found.';
  String get editBookingTitle => _isMalay ? 'Edit Tempahan' : 'Edit Booking';
  String get bookingPreviewTitle =>
      _isMalay ? 'Pratonton Tempahan' : 'Booking Preview';
  String get paymentMethodLabel =>
      _isMalay ? 'Kaedah Pembayaran' : 'Payment Method';
  String get choosePaymentMethodPlaceholder =>
      _isMalay ? 'Pilih kaedah pembayaran' : 'Choose payment method';
  String get packageTypeLabel => _isMalay ? 'Pakej' : 'Package';
  String get selectPackagePlaceholder =>
      _isMalay ? 'Pilih pakej' : 'Select package';
  String get bookingSubmittingCta =>
      _isMalay ? 'Menghantar...' : 'Submitting...';
  String get saveChangesCta => _isMalay ? 'Simpan Perubahan' : 'Save Changes';
  String get confirmBookingCta =>
      _isMalay ? 'Sahkan Tempahan' : 'Confirm Booking';
  String get estimatedFareLabel =>
      _isMalay ? 'Anggaran tambang' : 'Estimated fare';
  String get etaLabel => 'ETA';
  String get choosePaymentMethodTitle =>
      _isMalay ? 'Pilih Kaedah Pembayaran' : 'Choose Payment Method';
  String get selectPackageTitle => _isMalay ? 'Pilih Pakej' : 'Select Package';
  String get failedToSaveChangesError =>
      _isMalay ? 'Gagal menyimpan perubahan:' : 'Failed to save changes:';
  String get failedToCreateBookingError =>
      _isMalay ? 'Gagal membuat tempahan:' : 'Failed to create booking:';
  String get editCta => 'Edit';
  String get loadingDriverRouteLabel =>
      _isMalay ? 'Memuatkan laluan pemandu...' : 'Loading driver route...';
  String get waitingForDriverLocationLabel => _isMalay
      ? 'Menunggu lokasi pemandu...'
      : 'Waiting for driver location...';
  String get showDriverLocationCta =>
      _isMalay ? 'Tunjuk Lokasi Pemandu' : 'Show Driver Location';
  String get cancellingLabel => _isMalay ? 'Membatalkan...' : 'Cancelling...';
  String get cancelBookingCta =>
      _isMalay ? 'Batalkan Tempahan' : 'Cancel Booking';
  String get vehicleUnknownLabel => _isMalay ? 'Kenderaan: -' : 'Vehicle: -';
  String get platePrefixLabel => _isMalay ? 'Plat:' : 'Plate:';
  String get unableToStartCallError =>
      _isMalay ? 'Tidak dapat memulakan panggilan.' : 'Unable to start a call.';
  String get waitingForDriverLiveLocationError => _isMalay
      ? 'Menunggu lokasi langsung pemandu...'
      : 'Waiting for driver live location...';
  String get bookingPendingTitle =>
      _isMalay ? 'Tempahan sedang menunggu...' : 'Booking pending...';
  String get bookingPendingSubtitle =>
      _isMalay ? 'Menunggu pemandu menerima' : 'Waiting for driver to accept';
  String get driverAcceptedTitle =>
      _isMalay ? 'Pemandu telah menerima' : 'Driver accepted';
  String get driverAcceptedSubtitle => _isMalay
      ? 'Pemandu sedang menuju ke lokasi ambil anda'
      : 'Driver is heading to your pickup point';
  String get driverArrivedTitle =>
      _isMalay ? 'Pemandu telah tiba' : 'Driver arrived';
  String get driverArrivedSubtitle => _isMalay
      ? 'Pemandu anda telah tiba di lokasi ambil'
      : 'Your driver has arrived at pickup';
  String get rideInProgressTitle =>
      _isMalay ? 'Perjalanan sedang berlangsung' : 'Ride in progress';
  String get rideInProgressSubtitle =>
      _isMalay ? 'Nikmati perjalanan anda' : 'Enjoy your trip';
  String get rideCompletedTitle =>
      _isMalay ? 'Perjalanan selesai' : 'Ride completed';
  String get rideCompletedSubtitle => _isMalay
      ? 'Terima kasih kerana menaiki Urban Drive'
      : 'Thank you for riding with Urban Drive';
  String get bookingCancelledTitle =>
      _isMalay ? 'Tempahan dibatalkan' : 'Booking cancelled';
  String get bookingCancelledSubtitle => _isMalay
      ? 'Anda boleh membuat tempahan baharu bila-bila masa'
      : 'You can create a new booking anytime';
  String get rateYourDriverLabel =>
      _isMalay ? 'Nilaikan pemandu anda' : 'Rate your driver';
  String get writeCommentHint =>
      _isMalay ? 'Tulis komen (pilihan)' : 'Write a comment (optional)';
  String get ratingSubmittedLabel =>
      _isMalay ? 'Penilaian telah dihantar' : 'Rating submitted';
  String get submitRatingCta => _isMalay ? 'Hantar Penilaian' : 'Submit Rating';
  String get backToHomeCta =>
      _isMalay ? 'Kembali ke Laman Utama' : 'Back to Home';
  String get driverNotFoundForRatingError => _isMalay
      ? 'Pemandu tidak dijumpai untuk penilaian.'
      : 'Driver not found for rating.';
  String get thanksRatingSubmittedMessage => _isMalay
      ? 'Terima kasih! Penilaian telah dihantar.'
      : 'Thanks! Rating submitted.';
  String get failedToSubmitRatingError =>
      _isMalay ? 'Gagal menghantar penilaian:' : 'Failed to submit rating:';
  String get userProfileUpdatedMessage =>
      _isMalay ? 'Profil telah dikemas kini.' : 'Profile updated.';
  String get failedToUpdateProfileError =>
      _isMalay ? 'Gagal mengemas kini profil:' : 'Failed to update profile:';
  String get profileCancelCta => _isMalay ? 'Batal' : 'Cancel';
  String get savingEllipsis => _isMalay ? 'Menyimpan...' : 'Saving...';
  String get profileSaveCta => _isMalay ? 'Simpan' : 'Save';
  String get changePasswordCta =>
      _isMalay ? 'Tukar Kata Laluan' : 'Change Password';
  // === END PASSENGER_FLOW_SECTION ===

  // === DRIVER_FLOW_SECTION ===
  // Driver dashboard screen
  String get driverWaitingForJobsStatus =>
      _isMalay ? 'Menunggu tempahan' : 'Waiting for jobs';
  String get driverOfflineStatus => _isMalay ? 'Luar talian' : 'Offline';
  String get detectingLocationMessage =>
      _isMalay ? 'Mengesan lokasi semasa...' : 'Detecting current location...';
  String get tripsMetricLabel => _isMalay ? 'Perjalanan' : 'Trips';
  String get earningsMetricLabel => _isMalay ? 'Pendapatan' : 'Earnings';
  String get availableJobsCta =>
      _isMalay ? 'Tempahan Tersedia' : 'Available Jobs';
  String get goOnlineForJobsCta =>
      _isMalay ? 'Buka Talian untuk Dapat Tempahan' : 'Go Online to Get Jobs';
  String get loadingProfileMessage =>
      _isMalay ? 'Memuatkan profil...' : 'Loading profile...';
  String get updateAvailabilityFailedError =>
      _isMalay ? 'Gagal mengemas kini status' : 'Failed to update availability';
  String get enableLocationServiceMessage => _isMalay
      ? 'Sila hidupkan perkhidmatan lokasi pada telefon anda.'
      : 'Please enable location service on your phone.';
  String get locationPermissionRequiredMessage => _isMalay
      ? 'Kebenaran lokasi diperlukan.'
      : 'Location permission is required.';
  String get unableDetectLocationMessage => _isMalay
      ? 'Tidak dapat mengesan lokasi anda sekarang.'
      : 'Unable to detect your location now.';
  String get retryLocationCta => _isMalay ? 'Cuba Lagi' : 'Retry';

  // Driver available bookings screen
  String get availableBookingsTitle =>
      _isMalay ? 'Tempahan Tersedia' : 'Available Bookings';
  String get offlineBookingsMessage => _isMalay
      ? 'Anda sedang luar talian. Hidupkan suis tempahan di papan pemuka untuk terima tempahan.'
      : 'You are offline. Turn ON your job toggle on dashboard to receive bookings.';
  String get noAvailableBookingsMessage => _isMalay
      ? 'Tiada tempahan tersedia buat masa ini.'
      : 'No available bookings right now.';
  String get bookingDetailsTitle =>
      _isMalay ? 'Butiran Tempahan' : 'Booking Details';
  String get rejectCta => _isMalay ? 'Tolak' : 'Reject';
  String get acceptingCta => _isMalay ? 'Menerima...' : 'Accepting...';
  String get acceptCta => _isMalay ? 'Terima' : 'Accept';
  String get bookingRejectedMessage =>
      _isMalay ? 'Tempahan telah ditolak.' : 'Booking rejected.';
  String get driverNotLoggedInMessage =>
      _isMalay ? 'Pemandu tidak log masuk.' : 'Driver is not logged in.';
  String get acceptFailedError =>
      _isMalay ? 'Gagal menerima tempahan' : 'Accept failed';
  String get bookingAlreadyTakenMessage => _isMalay
      ? 'Tempahan ini baru sahaja diambil oleh pemandu lain.'
      : 'This booking was just taken by another driver.';
  String get seeDetailBookingCta =>
      _isMalay ? 'Lihat Butiran Tempahan' : 'See Detail Booking';

  // Driver active ride screen
  String get headingToPickupStatus => _isMalay
      ? 'Menuju ke lokasi ambil penumpang'
      : 'Heading to passenger pickup';
  String get driverArrivedPickupStatus => _isMalay
      ? 'Pemandu telah tiba di lokasi ambil'
      : 'Driver arrived at pickup';
  String get rideInProgressStatus =>
      _isMalay ? 'Perjalanan sedang berlangsung' : 'Ride in progress';
  String get rideCompletedStatus =>
      _isMalay ? 'Perjalanan selesai' : 'Ride completed';
  String get acceptedStageLabel => _isMalay ? 'DITERIMA' : 'ACCEPTED';
  String get arrivedPickupStageLabel =>
      _isMalay ? 'TIBA DI LOKASI AMBIL' : 'ARRIVED PICKUP';
  String get inProgressStageLabel =>
      _isMalay ? 'SEDANG BERLANGSUNG' : 'IN PROGRESS';
  String get completedStageLabel => _isMalay ? 'SELESAI' : 'COMPLETED';
  String get arrivedActionCta => _isMalay ? 'Sudah Tiba' : 'Arrived';
  String get startRideCta => _isMalay ? 'Mula Perjalanan' : 'Start Ride';
  String get completeRideCta =>
      _isMalay ? 'Selesaikan Perjalanan' : 'Complete Ride';
  String get doneCta => _isMalay ? 'Selesai' : 'Done';
  String get navigateToDropoffCta =>
      _isMalay ? 'Navigasi ke Destinasi' : 'Navigate to Drop-off';
  String get navigateToPassengerCta =>
      _isMalay ? 'Navigasi ke Penumpang' : 'Navigate to Passenger';
  String get cancelRideCta => _isMalay ? 'Batalkan Perjalanan' : 'Cancel Ride';
  String get rideCancelledByPassengerTitle =>
      _isMalay ? 'Perjalanan dibatalkan' : 'Ride cancelled';
  String get rideCancelledByPassengerMessage => _isMalay
      ? 'Penumpang telah membatalkan perjalanan ini.'
      : 'The passenger has cancelled this ride.';
  String get okCta => _isMalay ? 'OK' : 'OK';
  String get findingRouteMessage =>
      _isMalay ? 'Mencari laluan anda...' : 'Finding your route...';
  String get directionsUnavailableMessage =>
      _isMalay ? 'Arah perjalanan tidak tersedia' : 'Directions unavailable';
  String get thenLabel => _isMalay ? 'Kemudian' : 'Then';
  String get endNavigationCta =>
      _isMalay ? 'Tamatkan Navigasi' : 'End Navigation';
  String get waitingForLocationMessage =>
      _isMalay ? 'Menunggu lokasi semasa.' : 'Waiting for current location.';
  String get toDestinationLabel => _isMalay ? 'Ke' : 'To';
  String get arriveAtLabel => _isMalay ? 'tiba' : 'arrive';

  // Driver history screen
  String get pleaseLoginAsDriverMessage =>
      _isMalay ? 'Sila log masuk sebagai pemandu.' : 'Please log in as driver.';
  String get failedToLoadHistoryError =>
      _isMalay ? 'Gagal memuatkan sejarah' : 'Failed to load history';
  String get noCompletedRidesMessage =>
      _isMalay ? 'Tiada perjalanan selesai lagi.' : 'No completed rides yet.';
  String get unknownPassengerLabel =>
      _isMalay ? 'Penumpang Tidak Diketahui' : 'Unknown Passenger';
  String get commentPrefixLabel => _isMalay ? 'Komen' : 'Comment';

  // Driver total earning screen
  String get failedToLoadEarningsError =>
      _isMalay ? 'Gagal memuatkan pendapatan' : 'Failed to load earnings';
  String get monthLabel => _isMalay ? 'BULAN' : 'MONTH';
  String get yearLabel => _isMalay ? 'TAHUN' : 'YEAR';
  String get totalEarnedLabel => _isMalay ? 'Jumlah Diperoleh' : 'Total Earned';
  String get outstandingLabel => _isMalay ? 'Belum Dijelaskan' : 'Outstanding';
  String get paidLabel => _isMalay ? 'Telah Dibayar' : 'Paid';
  String get creatingBillCta =>
      _isMalay ? 'Mencipta bil...' : 'Creating bill...';
  String get noEarningRecordsMessage => _isMalay
      ? 'Tiada rekod pendapatan untuk penapis ini.'
      : 'No earning records for this filter.';
  String get driverNotLoggedInError =>
      _isMalay ? 'Pemandu tidak log masuk.' : 'Driver not logged in.';
  String get payAllFailedError =>
      _isMalay ? 'Gagal membayar semua' : 'Pay all failed';
  String get commissionOverdueMessage => _isMalay
      ? 'Bayaran komisen tertunggak sejak'
      : 'Commission payment overdue since';
  String get payCommissionByMessage => _isMalay
      ? 'Jelaskan komisen tertunggak anda sebelum'
      : 'Pay your outstanding commission by';

  // Driver pending approval screen
  String get registrationStatusTitle =>
      _isMalay ? 'Status Pendaftaran' : 'Registration Status';
  String get registrationRejectedTitle => _isMalay
      ? 'Pendaftaran anda telah ditolak'
      : 'Your registration was rejected';
  String get registrationUnderReviewTitle => _isMalay
      ? 'Pendaftaran pemandu anda sedang disemak'
      : 'Your driver registration is under review';
  String get contactSupportMessage => _isMalay
      ? 'Sila hubungi sokongan untuk maklumat lanjut.'
      : 'Please contact support for more information.';
  String get registrationReviewDescription => _isMalay
      ? 'Pasukan admin kami sedang menyemak dokumen yang anda hantar. Anda boleh mengakses papan pemuka pemandu sebaik sahaja diluluskan.'
      : 'Our admin team is reviewing your submitted documents. You will be able to access your driver dashboard once approved.';
  String get refreshingCta => _isMalay ? 'Menyegar semula...' : 'Refreshing...';
  String get refreshStatusCta =>
      _isMalay ? 'Segar Semula Status' : 'Refresh Status';
  String get logOutCta => _isMalay ? 'Log Keluar' : 'Log Out';

  // Driver profile screen
  String get profileUpdatedMessage =>
      _isMalay ? 'Profil telah dikemas kini.' : 'Profile updated.';
  String get updateProfileFailedError =>
      _isMalay ? 'Gagal mengemas kini profil' : 'Failed to update profile';
  String get vehicleBrandLabel =>
      _isMalay ? 'Jenama Kenderaan' : 'Vehicle Brand';
  String get vehicleModelLabel =>
      _isMalay ? 'Model Kenderaan' : 'Vehicle Model';
  String get cancelCta => _isMalay ? 'Batal' : 'Cancel';
  String get savingProfileCta => _isMalay ? 'Menyimpan...' : 'Saving...';
  String get saveCta => _isMalay ? 'Simpan' : 'Save';
  String get changePasswordMenuCta =>
      _isMalay ? 'Tukar Kata Laluan' : 'Change Password';

  // Driver pending approval screen -- resubmission state
  String get resubmissionNeededTitle => _isMalay
      ? 'Sesetengah dokumen perlu dibetulkan'
      : 'Some documents need fixing';
  String get resubmissionNeededDescription => _isMalay
      ? 'Admin meminta anda muat naik semula dokumen berikut sebelum pendaftaran anda dapat diluluskan.'
      : 'The admin needs you to re-upload the documents below before your registration can be approved.';
  String get fixDocumentsCta => _isMalay ? 'Betulkan Dokumen' : 'Fix Documents';
  String get idCardDocLabel => _isMalay ? 'Kad Pengenalan' : 'ID Card';
  String get licenseDocLabel => _isMalay ? 'Lesen Memandu' : 'Driving License';
  String get carGrantDocLabel => _isMalay ? 'Geran Kereta' : 'Car Grant';
  String get carImageDocLabel => _isMalay ? 'Gambar Kereta' : 'Car Image';

  // Driver document resubmit screen
  String get fixDocumentsTitle =>
      _isMalay ? 'Betulkan Dokumen' : 'Fix Documents';
  String get fixDocumentsSubtitle => _isMalay
      ? 'Muat naik semula dokumen yang ditolak sahaja'
      : 'Re-upload only the rejected documents';
  String get whyRejectedLabel =>
      _isMalay ? 'Sebab ditolak' : 'Why it was rejected';
  String get completeAllFlaggedDocumentsError => _isMalay
      ? 'Sila lengkapkan semua dokumen yang ditandakan di bawah.'
      : 'Please complete all the flagged documents below.';
  String get resubmittingCta =>
      _isMalay ? 'Menghantar semula...' : 'Resubmitting...';
  String get resubmitCta => _isMalay ? 'Hantar Semula' : 'Resubmit';
  String get resubmitSuccessMessage => _isMalay
      ? 'Dokumen dihantar semula. Admin akan menyemak semula permohonan anda.'
      : 'Documents resubmitted. The admin will review your application again.';
  String get resubmitFailedError => _isMalay
      ? 'Gagal menghantar semula dokumen'
      : 'Failed to resubmit documents';
  // Add new getters for driver-side screens above this line.
  // === END DRIVER_FLOW_SECTION ===
}
