class MapboxConfig {
  MapboxConfig._();

  static const accessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static bool get hasAccessToken => accessToken.isNotEmpty;
}
