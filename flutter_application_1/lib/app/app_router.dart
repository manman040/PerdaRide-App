import 'package:flutter/material.dart';

import '../features/auth/presentation/change_password_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/auth/presentation/driver_document_upload_screen.dart';
import '../features/auth/presentation/driver_registration_screen.dart';
import '../features/auth/presentation/driver_registration_review_screen.dart';
import '../features/auth/presentation/driver_vehicle_details_screen.dart';
import '../features/auth/presentation/user_registration_screen.dart';
import '../features/driver/presentation/driver_active_ride_screen.dart';
import '../features/driver/presentation/driver_dashboard_screen.dart';
import '../features/driver/presentation/driver_document_resubmit_screen.dart';
import '../features/driver/presentation/driver_history_screen.dart';
import '../features/driver/presentation/driver_pending_approval_screen.dart';
import '../features/driver/presentation/driver_profile_screen.dart';
import '../features/driver/presentation/driver_total_earning_screen.dart';
import '../features/driver/presentation/driver_available_bookings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/user/presentation/booking_preview_screen.dart';
import '../features/user/presentation/user_booking_status_screen.dart';
import '../features/user/presentation/dropoff_location_screen.dart';
import '../features/user/presentation/my_profile_screen.dart';
import '../features/user/presentation/notifications_screen.dart';
import '../features/user/presentation/settings_screen.dart';
import '../features/user/presentation/user_dashboard_screen.dart';

class AppRouter {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const changePassword = '/change-password';
  static const userRegistration = '/user-registration';
  static const driverRegistration = '/driver-registration';
  static const driverVehicleDetails = '/driver-vehicle-details';
  static const driverDocumentUpload = '/driver-document-upload';
  static const driverRegistrationReview = '/driver-registration-review';
  static const userDashboard = '/user-dashboard';
  static const dropoffLocation = '/dropoff-location';
  static const bookingPreview = '/booking-preview';
  static const userBookingStatus = '/user-booking-status';
  static const myProfile = '/my-profile';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const driverDashboard = '/driver-dashboard';
  static const driverActiveRide = '/driver-active-ride';
  static const driverPendingApproval = '/driver-pending-approval';
  static const driverDocumentResubmit = '/driver-document-resubmit';
  static const driverProfile = '/driver-profile';
  static const driverHistory = '/driver-history';
  static const driverTotalEarning = '/driver-total-earning';
  static const driverAvailableBookings = '/driver-available-bookings';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return _buildRoute(const SplashScreen(), routeSettings);
      case welcome:
        return _buildRoute(const WelcomeScreen(), routeSettings);
      case login:
        final loginArgs = routeSettings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          LoginScreen(notice: loginArgs?['notice'] as String?),
          routeSettings,
        );
      case forgotPassword:
        return _buildRoute(const ForgotPasswordScreen(), routeSettings);
      case changePassword:
        return _buildRoute(const ChangePasswordScreen(), routeSettings);
      case userRegistration:
        return _buildRoute(const UserRegistrationScreen(), routeSettings);
      case driverRegistration:
        return _buildRoute(const DriverRegistrationScreen(), routeSettings);
      case driverVehicleDetails:
        return _buildRoute(const DriverVehicleDetailsScreen(), routeSettings);
      case driverDocumentUpload:
        return _buildRoute(const DriverDocumentUploadScreen(), routeSettings);
      case driverRegistrationReview:
        return _buildRoute(
          const DriverRegistrationReviewScreen(),
          routeSettings,
        );
      case userDashboard:
        return _buildRoute(const UserDashboardScreen(), routeSettings);
      case myProfile:
        return _buildRoute(const MyProfileScreen(), routeSettings);
      case notifications:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        return _buildRoute(
          NotificationsScreen(isDriver: args?['isDriver'] == true),
          routeSettings,
        );
      case settings:
        return _buildRoute(const SettingsScreen(), routeSettings);
      case dropoffLocation:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null ||
            args['pickupPoint'] == null ||
            args['pickupLabel'] == null) {
          return _buildRoute(const UserDashboardScreen(), routeSettings);
        }
        return _buildRoute(
          DropoffLocationScreen(
            pickupPoint: args['pickupPoint'],
            pickupLabel: args['pickupLabel'],
          ),
          routeSettings,
        );
      case bookingPreview:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null ||
            args['pickupPoint'] == null ||
            args['pickupLabel'] == null ||
            args['dropoffPoint'] == null ||
            args['dropoffLabel'] == null) {
          return _buildRoute(const UserDashboardScreen(), routeSettings);
        }
        return _buildRoute(
          BookingPreviewScreen(
            pickupPoint: args['pickupPoint'],
            pickupLabel: args['pickupLabel'],
            dropoffPoint: args['dropoffPoint'],
            dropoffLabel: args['dropoffLabel'],
            existingBookingId: args['existingBookingId'] as String?,
            initialPaymentMethod: args['initialPaymentMethod'] as String?,
            initialPackageLabel: args['initialPackageLabel'] as String?,
          ),
          routeSettings,
        );
      case driverDashboard:
        return _buildRoute(const DriverDashboardScreen(), routeSettings);
      case driverActiveRide:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null ||
            args['bookingId'] == null ||
            args['pickupPoint'] == null ||
            args['pickupLabel'] == null ||
            args['dropoffPoint'] == null ||
            args['dropoffLabel'] == null ||
            args['paymentMethod'] == null ||
            args['packageLabel'] == null ||
            args['priceLabel'] == null ||
            args['distanceKm'] == null) {
          return _buildRoute(const DriverDashboardScreen(), routeSettings);
        }
        return _buildRoute(
          DriverActiveRideScreen(
            bookingId: args['bookingId'],
            pickupPoint: args['pickupPoint'],
            pickupLabel: args['pickupLabel'],
            dropoffPoint: args['dropoffPoint'],
            dropoffLabel: args['dropoffLabel'],
            paymentMethod: args['paymentMethod'],
            packageLabel: args['packageLabel'],
            priceLabel: args['priceLabel'],
            initialDistanceLabel: args['distanceKm'],
          ),
          routeSettings,
        );
      case driverPendingApproval:
        return _buildRoute(
          const DriverPendingApprovalScreen(),
          routeSettings,
        );
      case driverDocumentResubmit:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        final rejectedDocuments =
            (args?['rejectedDocuments'] as List?)?.cast<String>() ??
            const <String>[];
        return _buildRoute(
          DriverDocumentResubmitScreen(
            rejectedDocuments: rejectedDocuments,
            rejectionReason: args?['rejectionReason'] as String?,
            rejectionMessage: args?['rejectionMessage'] as String?,
          ),
          routeSettings,
        );
      case driverProfile:
        return _buildRoute(const DriverProfileScreen(), routeSettings);
      case driverHistory:
        return _buildRoute(const DriverHistoryScreen(), routeSettings);
      case driverTotalEarning:
        return _buildRoute(const DriverTotalEarningScreen(), routeSettings);
      case userBookingStatus:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args == null ||
            args['bookingId'] == null ||
            args['pickupPoint'] == null ||
            args['pickupLabel'] == null ||
            args['dropoffPoint'] == null ||
            args['dropoffLabel'] == null ||
            args['paymentMethod'] == null ||
            args['packageLabel'] == null ||
            args['fareLabel'] == null) {
          return _buildRoute(const UserDashboardScreen(), routeSettings);
        }
        return _buildRoute(
          UserBookingStatusScreen(
            bookingId: args['bookingId'],
            pickupPoint: args['pickupPoint'],
            pickupLabel: args['pickupLabel'],
            dropoffPoint: args['dropoffPoint'],
            dropoffLabel: args['dropoffLabel'],
            paymentMethod: args['paymentMethod'],
            packageLabel: args['packageLabel'],
            fareLabel: args['fareLabel'],
          ),
          routeSettings,
        );
      case driverAvailableBookings:
        return _buildRoute(
          const DriverAvailableBookingsScreen(),
          routeSettings,
        );
      default:
        return _buildRoute(const SplashScreen(), routeSettings);
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget child,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => child,
      settings: settings,
    );
  }
}
