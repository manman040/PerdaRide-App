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
      ? 'Lihat maklumat yang disimpan untuk akaun PerdaRide anda.'
      : 'View the details stored for your PerdaRide account.';
  String get driverProfileTitle => _isMalay ? 'Profil Pemandu' : 'Driver Profile';
  String get driverProfileDescription => _isMalay
      ? 'Semak butiran akaun dan kenderaan pemandu anda.'
      : 'Review your driver account and vehicle details.';
  String get driverVehicleLabel => _isMalay ? 'Kenderaan' : 'Vehicle';
  String get vehicleYearLabel => _isMalay ? 'Tahun Kenderaan' : 'Vehicle Year';
  String get capacityLabel => _isMalay ? 'Kapasiti Penumpang' : 'Passenger Capacity';
  String get driverHistoryMenu => _isMalay ? 'SEJARAH' : 'HISTORY';
  String get totalEarningMenu => _isMalay ? 'JUMLAH PENDAPATAN' : 'TOTAL EARNING';
  String get driverDashboardLabel =>
      _isMalay ? 'Papan Pemuka Pemandu' : 'Driver Dashboard';
  String get driverDashboardSubtitle => _isMalay
      ? 'Urus perjalanan dan profil anda'
      : 'Manage your rides and profile';
  String get driverHistoryTitle => _isMalay ? 'Sejarah Perjalanan' : 'Ride History';
  String get totalEarningTitle =>
      _isMalay ? 'Jumlah Pendapatan' : 'Total Earning';
  String get pickupHistoryLabel => _isMalay ? 'Ambil' : 'Pickup';
  String get dropoffHistoryLabel => _isMalay ? 'Hantar' : 'Drop-off';
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
  String get logoutSuccess =>
      _isMalay ? 'Anda telah log keluar.' : 'You have been logged out.';
  String get logoutError => _isMalay
      ? 'Log keluar gagal. Sila cuba lagi.'
      : 'Sign out failed. Please try again.';
}
