import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app/app.dart';
import 'core/config/mapbox_config.dart';
import 'core/firebase/firebase_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (MapboxConfig.hasAccessToken) {
    MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  }
  await Firebase.initializeApp();
  unawaited(PerdaRideApp.loadSettings());
  runApp(const PerdaRideApp());
  unawaited(FirebasePushService.instance.initialize());
}
