import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'device/diagnostics.dart';
import 'device/workshop_device.dart';

/// Device-team entry point. Does not depend on any of the game screens.
void main() {
  final device = WorkshopDevice(
    simulated: kIsWeb || const bool.fromEnvironment('SIMULATE_INPUT'),
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '磨くでヤンス！ 端末の計測',
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'WorkshopSans'),
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: DiagnosticsPage(device: device),
    ),
  );
}
