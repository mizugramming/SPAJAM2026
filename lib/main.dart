import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device/diagnostics.dart';
import 'device/workshop_device.dart';
import 'game/game.dart';
import 'ui/game_settings.dart';
import 'ui/phrase_text.dart';
import 'ui/workshop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'WorkshopSans (Noto Sans JP)',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'YujiSyuku',
    ], await rootBundle.loadString('assets/fonts/OFL-YujiSyuku.txt'));
  });
  const key = 'strokesToGold';
  final preferences = SharedPreferencesAsync();
  int? savedCount;
  try {
    savedCount = await preferences.getInt(key);
  } catch (error) {
    debugPrint('研磨回数の設定を読み込めませんでした: $error');
  }
  runApp(
    WorkshopApp(
      initialStrokesToGold: savedCount ?? GameController.defaultStrokesToGold,
      persistStrokesToGold: (value) => preferences.setInt(key, value),
    ),
  );
}

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({
    super.key,
    this.simulated = kIsWeb || const bool.fromEnvironment('SIMULATE_INPUT'),
    this.initialStrokesToGold = GameController.defaultStrokesToGold,
    this.persistStrokesToGold,
  });
  final bool simulated;
  final int initialStrokesToGold;
  final Future<void> Function(int)? persistStrokesToGold;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '磨くでヤンス！',
    theme: workshopTheme,
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _Session(
      simulated: simulated,
      initialStrokesToGold: initialStrokesToGold,
      persistStrokesToGold: persistStrokesToGold,
    ),
  );
}

class _Session extends StatefulWidget {
  const _Session({
    required this.simulated,
    required this.initialStrokesToGold,
    this.persistStrokesToGold,
  });
  final bool simulated;
  final int initialStrokesToGold;
  final Future<void> Function(int)? persistStrokesToGold;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session>
    with WidgetsBindingObserver
    implements WorkshopActions {
  final game = GameController();
  late final device = WorkshopDevice(simulated: widget.simulated);
  StreamSubscription<int>? _events;
  Timer? _readyTimer;
  bool _paperLanded = false;
  bool _motion = false;
  bool _inContact = false;
  bool _busy = false;
  bool _background = false;
  bool _showTitle = true;
  bool _inLab = false;
  bool _confirmingExit = false;
  String? _error;
  int _operation = 0;
  @override
  Grit demoVoice = Grit.medium;

  @override
  void initState() {
    super.initState();
    game.setStrokesToGold(widget.initialStrokesToGold);
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
    if (game.phase != GamePhase.ready && _paperLanded) {
      _paperLanded = false;
      _readyTimer?.cancel();
    }
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
  void setVoiceProfile(VoiceProfile profile) => game.setVoiceProfile(profile);

  @override
  void retry() {
    _operation++;
    _busy = false;
    _error = null;
    game.reset();
  }

  @override
  void selectDemoVoice(Grit grit) {
    if (!_busy) setState(() => demoVoice = grit);
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
      final profile = game.voiceProfile;
      final sample = await device.capture(
        profile.demoHz(demoVoice),
        desk: true,
      );
      if (!mounted || op != _operation) return;
      if (!game.acceptVoice(sample)) {
        _error = pitchRetryMessage;
      }
    } catch (e) {
      if (mounted && op == _operation) _error = deviceMessage(e);
    } finally {
      if (mounted && op == _operation) setState(() => _busy = false);
    }
  }

  @override
  void paperLanded() {
    if (game.phase != GamePhase.ready) return;
    _paperLanded = true;
    _scheduleStart();
  }

  bool get _canStart =>
      game.phase == GamePhase.ready &&
      !_busy &&
      !_background &&
      !_confirmingExit &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive;

  /// Give the player a moment to move their hand into position after landing.
  void _scheduleStart() {
    _readyTimer?.cancel();
    if (_paperLanded && _canStart && _error == null) {
      _readyTimer = Timer(const Duration(milliseconds: 650), start);
    }
  }

  @override
  Future<void> start() async {
    if (!_canStart) return;
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
  Future<void> openSettings() async {
    if (_inLab || game.phase != GamePhase.select) return;
    _inLab = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (settingsContext) => GameSettingsPage(
          strokesToGold: game.strokesToGold,
          onSave: _saveStrokesToGold,
          onOpenDiagnostics: () => Navigator.of(settingsContext).push<void>(
            MaterialPageRoute(
              builder: (_) => DiagnosticsPage(
                device: device,
                profile: game.voiceProfile,
                onProfileChanged: setVoiceProfile,
              ),
            ),
          ),
        ),
      ),
    );
    _inLab = false;
  }

  Future<void> _saveStrokesToGold(int value) async {
    await widget.persistStrokesToGold?.call(value);
    if (mounted) game.setStrokesToGold(value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_inLab) return;
    if (state == AppLifecycleState.inactive && game.phase != GamePhase.ready) {
      return;
    }
    final background = state != AppLifecycleState.resumed;
    if (background == _background) {
      if (!background) _scheduleStart();
      return;
    }
    _background = background;
    if (background) {
      _readyTimer?.cancel();
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
      _scheduleStart();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readyTimer?.cancel();
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
    _readyTimer?.cancel();
    _operation++;
    _busy = false;
    game.setPaused(true);
    _stopMotion();
    unawaited(device.cancelCapture());
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: true,
        title: const PhraseText('素材選びに\n戻りますか？'),
        content: const PhraseText('磨いた分は\nリセットされます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('素材選びに戻る', softWrap: false),
            ),
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
      _scheduleStart();
      setState(() {});
    }
  }

  /// プレイを初期化してタイトル画面へ戻す。素材選択の「戻る」と結果の「タイトルへ」。
  void _backToTitle() {
    retry();
    setState(() => _showTitle = true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // タイトル画面でだけ端末の戻る操作でアプリを閉じる。
      canPop: game.phase == GamePhase.select && _showTitle,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (game.phase == GamePhase.select) {
          _backToTitle();
        } else {
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PhraseText(_error!, center: true),
                      ),
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
              onTitle: _backToTitle,
              actions: this,
              simulated: device.simulated,
              busy: _busy,
              error: _error,
            ),
    );
  }
}
