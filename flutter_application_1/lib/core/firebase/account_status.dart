/// Reads the admin-controlled `status` flag on a `users/{uid}` or
/// `drivers/{uid}` record.
///
/// The admin panel writes `disabled` to lock an account, and the database
/// rules stop the account owner from changing that field back. Splash, login
/// and both dashboards call [isDisabled] and sign the account out when it is
/// set, so an admin "Disable" actually takes effect in the app.
class AccountStatus {
  AccountStatus._();

  static const _disabledValues = {'disabled', 'suspended', 'banned', 'blocked'};

  static bool isDisabled(Object? record) {
    if (record is! Map) return false;
    final status = (record['status'] ?? '').toString().trim().toLowerCase();
    return _disabledValues.contains(status);
  }
}
