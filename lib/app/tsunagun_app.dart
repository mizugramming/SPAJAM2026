import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/demo_controller.dart';
import '../data/online_controller.dart';
import '../features/online/online_page.dart';
import '../data/conveyor_settings.dart';
import 'conveyor_settings_scope.dart';
import '../features/demo/demo_page.dart';
import '../features/demo/parent_character.dart';
import '../features/demo/result_sound_player.dart';
import 'tsunagun_theme.dart';
import 'tsunagun_typography.dart';

class TsunagunApp extends StatefulWidget {
  const TsunagunApp({
    super.key,
    this.controller,
    this.onlineController,
    this.conveyorSettings,
    this.resultSoundPlayer,
    this.animateCharacters = true,
    this.initialTypeface = TsunagunTypeface.kaiseiTokumin,
  });

  final DemoController? controller;

  /// App owns and restores the online session when supplied by main.
  final OnlineController? onlineController;
  final ConveyorSettings? conveyorSettings;
  final ResultSoundPlayer? resultSoundPlayer;
  final bool animateCharacters;
  final TsunagunTypeface initialTypeface;

  @override
  State<TsunagunApp> createState() => _TsunagunAppState();
}

class _TsunagunAppState extends State<TsunagunApp> {
  late TsunagunTypeface _typeface = widget.initialTypeface;
  late final ConveyorSettings _conveyorSettings =
      widget.conveyorSettings ??
      ConveyorSettings(store: MemoryConveyorLayoutStore());

  @override
  void initState() {
    super.initState();
    if (widget.onlineController != null) {
      unawaited(widget.onlineController!.restore());
    }
    if (!_conveyorSettings.isLoaded) _conveyorSettings.load();
  }

  @override
  void dispose() {
    if (widget.conveyorSettings == null) _conveyorSettings.dispose();
    widget.onlineController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ConveyorSettingsScope(
    settings: _conveyorSettings,
    child: TypographyScope(
      typeface: _typeface,
      onChanged: (typeface) => setState(() => _typeface = typeface),
      child: CharacterPlaybackScope(
        enabled: widget.animateCharacters,
        child: MaterialApp(
          title: widget.onlineController == null ? 'つなぐん DEMO' : 'つなぐん',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ja'),
          supportedLocales: const [Locale('ja')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: tsunagunTheme(typeface: _typeface),
          // Avoid interpolating geometry between unrelated font metrics.
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => PhoneViewport(child: child!),
          home: widget.onlineController != null
              ? OnlinePage(
                  controller: widget.onlineController!,
                  resultSoundPlayer: widget.resultSoundPlayer,
                )
              : DemoPage(
                  controller: widget.controller,
                  resultSoundPlayer: widget.resultSoundPlayer,
                ),
        ),
      ),
    ),
  );
}

/// All scenes and overlays share this viewport. Desktop previews keep a
/// provisional 412 x 900 canvas and shrink it to fit without changing its ratio.
/// Android/iOS, including their browsers, retain the actual device constraints.
class PhoneViewport extends StatelessWidget {
  const PhoneViewport({super.key, required this.child});

  static const previewWidth = 412.0;
  static const previewHeight = 900.0;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
    if (!desktop) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : previewWidth;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : previewHeight;
        final scale = math.min(
          1.0,
          math.min(width / previewWidth, height / previewHeight),
        );
        final offset = Offset(
          (width - previewWidth * scale) / 2,
          (height - previewHeight * scale) / 2,
        );
        // System insets are measured from the outer window. Remove the gutters
        // and convert the overlap to canvas coordinates before SafeArea/Scaffold
        // consume it. Text scaling and other accessibility settings stay intact.
        EdgeInsets canvasInsets(EdgeInsets insets) {
          final divisor = scale > 0 ? scale : 1.0;
          return EdgeInsets.fromLTRB(
            ((insets.left - offset.dx) / divisor).clamp(0.0, previewWidth),
            ((insets.top - offset.dy) / divisor).clamp(0.0, previewHeight),
            ((insets.right - offset.dx) / divisor).clamp(0.0, previewWidth),
            ((insets.bottom - offset.dy) / divisor).clamp(0.0, previewHeight),
          );
        }

        final media = MediaQuery.of(context);
        return ColoredBox(
          color: const Color(0xFFE1E4E2),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: ClipRect(
                  child: MediaQuery(
                    data: media.copyWith(
                      size: const Size(previewWidth, previewHeight),
                      padding: canvasInsets(media.padding),
                      viewPadding: canvasInsets(media.viewPadding),
                      viewInsets: canvasInsets(media.viewInsets),
                      systemGestureInsets: canvasInsets(
                        media.systemGestureInsets,
                      ),
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
