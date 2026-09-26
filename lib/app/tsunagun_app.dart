import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/demo_controller.dart';
import '../features/demo/demo_page.dart';

class TsunagunApp extends StatelessWidget {
  const TsunagunApp({super.key, this.controller});

  final DemoController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'つなぐん DEMO',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF186964),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          border: UnderlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      builder: (context, child) => PhoneViewport(child: child!),
      home: DemoPage(controller: controller),
    );
  }
}

/// All scenes and overlays share this viewport. 412 x 900 is a desktop
/// preview limit, not the target phone's measured logical resolution.
class PhoneViewport extends StatelessWidget {
  const PhoneViewport({super.key, required this.child});

  static const previewWidth = 412.0;
  static const previewHeight = 900.0;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop =
        kIsWeb ||
        switch (defaultTargetPlatform) {
          TargetPlatform.linux ||
          TargetPlatform.macOS ||
          TargetPlatform.windows => true,
          _ => false,
        };
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!desktop || constraints.maxWidth < 600) return child;
        return ColoredBox(
          color: const Color(0xFFE1E4E2),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: previewWidth,
                maxHeight: previewHeight,
              ),
              child: LayoutBuilder(
                builder: (context, viewport) => ClipRect(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: Size(viewport.maxWidth, viewport.maxHeight),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
