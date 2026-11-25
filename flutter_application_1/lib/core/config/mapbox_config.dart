class MapboxConfig {
  MapboxConfig._();

  static const _dartDefineToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  /// Public (pk.) token, safe to embed in client code per Mapbox's own docs.
  /// Used only when --dart-define-from-file wasn't passed at launch (e.g. a
  /// plain `flutter run`/F5 session, not the "PerdaRide (Debug)" launch
  /// config) so Mapbox-dependent features -- like driving directions --
  /// don't silently skip their real API call and fall back depending on how
  /// the app happened to be started.
  static const _fallbackToken =
      'pk.eyJ1IjoiYWltYW5taWxpMSIsImEiOiJjbXJ3c3Y1MDYwYW52MzZwc2xlN2U0N3d2In0.ueBsN4PBb8aXlmBSfhDrZA';

  static String get accessToken =>
      _dartDefineToken.isNotEmpty ? _dartDefineToken : _fallbackToken;

  static bool get hasAccessToken => accessToken.isNotEmpty;
}
