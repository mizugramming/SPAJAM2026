import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'device/diagnostics.dart';
import 'device/workshop_device.dart';
import 'game/game.dart';
import 'ui/workshop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'WorkshopSans (Noto Sans JP)',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const WorkshopApp());
}

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({
    super.key,
    this.simulated = kIsWeb || const bool.fromEnvironment('SIMULATE_INPUT'),
  });
  final bool simulated;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'いろみがき',
    theme: workshopTheme,
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _Session(simulated: simulated),
  );
}

class _Session extends StatefulWidget {
  const _Session({required this.simulated});
  final bool simulated;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session>
    with WidgetsBindingObserver
    implements WorkshopActions {
  final game = GameController();
  late final device = WorkshopDevice(simulated: widget.simulated);
  StreamSubscription<int>? _events;
  bool _motion = false;
  bool _inContact = false;
  bool _busy = false;
  bool _background = false;
  bool _showTitle = true;
  bool _inLab = false;
  bool _confirmingExit = false;
  VoiceMode _mode = VoiceMode.pitch;
  String? _error;
  int _operation = 0;
  @override
  double demoPitch = 190;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game.addListener(_changed);
    _events = device.motionEvents.listen(
      _handleMotion,
      onError: (Object e) {
        if (mounted && !_inLab) setState(() => _error = deviceMessage(e));
      },
    );
  }

  void _changed() {
    if (_motion && game.phase != GamePhase.polishing) _stopMotion();
    setState(() {});
  }

  void _stopMotion() {
    _motion = false;
    _inContact = false;
    unawaited(device.stopMotion());
    unawaited(device.stopPulse());
  }

  @override
  void choose(WorkMaterial material) {
    _error = null;
    game.select(material);
  }

  @override
  void retry() {
    _operation++;
    _busy = false;
    _error = null;
    game.reset();
  }

  @override
  void selectDemoPitch(double hz) {
    if (!_busy) setState(() => demoPitch = hz);
  }

  @override
  void useVoiceMode(VoiceMode mode) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  @override
  Future<void> capture() async {
    if (_busy || _background || game.phase != GamePhase.voice) return;
    final op = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sample = await device.capture(demoPitch, desk: true);
      if (!mounted || op != _operation) return;
      if (!game.acceptVoice(sample, _mode)) {
        _error = _mode == VoiceMode.pitch
            ? '高さを読み取れませんでした。一定の声で試すか、音量で選んでください。'
            : '音が小さいようです。もう一度、少し大きな声を出してください。';
      }
    } catch (e) {
      if (mounted && op == _operation) _error = deviceMessage(e);
    } finally {
      if (mounted && op == _operation) setState(() => _busy = false);
    }
  }

  @override
  Future<void> start() async {
    if (_busy || _background || game.phase != GamePhase.ready) return;
    await _startMotion(resume: false);
  }

  Future<void> _startMotion({required bool resume}) async {
    final op = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await device.startPolishingMotion(
        game.grit!,
        game.progress,
        game.remainingPolishTime,
        sessionId: op,
      );
      if (!mounted || op != _operation) return;
      _motion = true;
      if (resume) {
        game.setPaused(false);
      } else {
        game.startPolishing();
      }
    } catch (e) {
      if (mounted && op == _operation) _error = deviceMessage(e);
    } finally {
      if (mounted && op == _operation) setState(() => _busy = false);
    }
  }

  void _handleMotion(int event) {
    if (!_motion || _background || game.phase != GamePhase.polishing) return;
    switch (event) {
      case WorkshopDevice.contactStarted:
        if (!_inContact) setState(() => _inContact = true);
      case WorkshopDevice.contactEnded:
        if (_inContact) setState(() => _inContact = false);
      case WorkshopDevice.strokeCompleted:
        _stroke();
    }
  }

  void _stroke() {
    final pulse = game.stroke();
    if (pulse != null && device.vibrationEnabled) {
      final sessionId = _operation;
      unawaited(
        device
            .pulse(
              pulse,
              followStroke: true,
              progress: game.progress,
              sessionId: sessionId,
            )
            .catchError((Object e) {
              if (!mounted || !_motion || sessionId != _operation) return;
              device.vibrationEnabled = false;
              setState(() => _error = deviceMessage(e));
            }),
      );
    }
  }

  @override
  void simulateStroke() {
    if (device.simulated) _handleMotion(WorkshopDevice.strokeCompleted);
  }

  @override
  Future<void> openDiagnostics() async {
    if (_inLab || game.phase != GamePhase.select) return;
    _inLab = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DiagnosticsPage(device: device)),
    );
    _inLab = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || _inLab) return;
    final background = state != AppLifecycleState.resumed;
    if (background == _background) return;
    _background = background;
    if (background) {
      _operation++;
      _busy = false;
      game.setPaused(true);
      unawaited(device.cancelCapture());
      _stopMotion();
      setState(() {});
    } else if (_confirmingExit) {
      return;
    } else if (game.phase == GamePhase.polishing) {
      unawaited(_startMotion(resume: true));
    } else {
      game.setPaused(false);
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operation++;
    game.removeListener(_changed);
    _stopMotion();
    unawaited(device.cancelCapture());
    _events?.cancel();
    game.dispose();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    if (_confirmingExit) return;
    if (game.phase == GamePhase.result) {
      retry();
      return;
    }
    _confirmingExit = true;
    _operation++;
    _busy = false;
    game.setPaused(true);
    _stopMotion();
    unawaited(device.cancelCapture());
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('素材選びに戻りますか？'),
        content: const Text('磨いた分はリセットされます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('素材選びに戻る'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _confirmingExit = false;
    if (exit == true) {
      game.setPaused(_background);
      retry();
    } else if (!_background && game.phase == GamePhase.polishing) {
      await _startMotion(resume: true);
    } else {
      game.setPaused(_background);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: game.phase == GamePhase.select,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && game.phase != GamePhase.select) {
          unawaited(_confirmExit());
        }
      },
      child:
          !_motion &&
              !_busy &&
              game.phase == GamePhase.polishing &&
              _error != null
          ? Scaffold(
              body: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      FilledButton(
                        onPressed: () => _startMotion(resume: true),
                        child: const Text('計測を再開'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Workshop(
              game: game,
              inContact: _inContact,
              onEnter: _showTitle
                  ? () => setState(() => _showTitle = false)
                  : null,
              actions: this,
              simulated: device.simulated,
              busy: _busy,
              error: _error,
              voiceMode: _mode,
            ),
    );
  }
}
