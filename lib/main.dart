import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/tsunagun_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in [
      ('Kaisei Tokumin', 'assets/fonts/OFL-KaiseiTokumin.txt'),
      ('M PLUS Rounded 1c', 'assets/fonts/OFL-MPlusRounded1c.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        font.$1,
      ], await rootBundle.loadString(font.$2));
    }
  });
  runApp(const TsunagunApp());
}
