import 'package:flutter/material.dart';

const parentIdleAsset = 'assets/characters/oyabun_idle.webp';
const parentIdlePosterAsset = 'assets/characters/oyabun_idle_poster.png';

/// Allows previews/tests to pause the idle loop independently of one-shot UI
/// transitions. OS reduced motion and background lifecycle always take priority.
class CharacterPlaybackScope extends InheritedWidget {
  const CharacterPlaybackScope({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CharacterPlaybackScope>()
          ?.enabled ??
      false;

  @override
  bool updateShouldNotify(CharacterPlaybackScope oldWidget) =>
      enabled != oldWidget.enabled;
}

class ParentCharacter extends StatefulWidget {
  const ParentCharacter({super.key, required this.idle});
  final bool idle;

  // Updated to the shared crop of the actual movie and its matching poster.
  static const aspectRatio = 432 / 345;

  @override
  State<ParentCharacter> createState() => _ParentCharacterState();
}

class _ParentCharacterState extends State<ParentCharacter>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() => _foreground = state == AppLifecycleState.resumed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _poster() => Image.asset(
    parentIdlePosterAsset,
    semanticLabel: '親分',
    fit: BoxFit.contain,
    alignment: Alignment.bottomCenter,
    errorBuilder: (_, error, stack) => Image.asset(
      'assets/characters/oyabun.png',
      semanticLabel: '親分',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final play =
        widget.idle &&
        _foreground &&
        CharacterPlaybackScope.enabledOf(context) &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!play) return _poster();
    return Image.asset(
      parentIdleAsset,
      semanticLabel: '親分',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      errorBuilder: (_, error, stack) => _poster(),
    );
  }
}
