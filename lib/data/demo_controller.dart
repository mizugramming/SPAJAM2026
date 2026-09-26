import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/reward_rules.dart';

/// One-device simulation. No authentication, networking, or persistent storage.
/// The outcome injection API must never be exposed by an online repository.
class DemoController extends ChangeNotifier {
  DemoController({bool autoTick = true}) : _autoTick = autoTick;

  static const nicknameLimit = 20;
  static const hobbyLimit = 60;
  static const commentLimit = 80;
  static const settlementGrace = Duration(seconds: 30);
  static const defaultDuration = Duration(minutes: 5);
  static const demoRoomCode = 'TSUNA';

  final bool _autoTick;
  final RewardRules _rules = const RewardRules();
  final Stopwatch _clock = Stopwatch();
  Duration _lastClockReading = Duration.zero;
  Timer? _timer;
  bool _disposed = false;

  AppPhase _phase = AppPhase.entry;
  bool _isHost = true;
  Duration _eventDuration = defaultDuration;
  Duration _remaining = defaultDuration;
  Duration _graceRemaining = Duration.zero;
  Profile _profileDraft = const Profile.empty();
  Profile? _savedProfile;
  Participant? _activePeer;
  EncounterResult? _lastResult;
  FinalSnapshot? _finalSnapshot;
  final Map<String, List<Follower>> _collections = {};
  final Set<String> _completedPeerIds = {};

  static const _fictionalPeers = [
    Participant(
      id: 'demo-red-1',
      profile: Profile(
        nickname: 'なぎ',
        hobby: '喫茶店めぐり',
        comment: 'おすすめの飲み物を教えてください。',
      ),
      team: Team.red,
    ),
    Participant(
      id: 'demo-red-2',
      profile: Profile(nickname: 'そら', hobby: '写真', comment: '旅先の空を撮るのが好きです。'),
      team: Team.red,
    ),
    Participant(
      id: 'demo-blue-1',
      profile: Profile(
        nickname: 'あお',
        hobby: '音楽',
        comment: '最近のお気に入りを聞かせてください。',
      ),
      team: Team.blue,
    ),
    Participant(
      id: 'demo-blue-2',
      profile: Profile(nickname: 'うみ', hobby: '料理', comment: '簡単なツナ料理を探しています。'),
      team: Team.blue,
    ),
    Participant(
      id: 'demo-blue-3',
      profile: Profile(nickname: 'しお', hobby: '散歩', comment: '知らない街を歩くのが好きです。'),
      team: Team.blue,
    ),
  ];

  AppPhase get phase => _phase;
  bool get isHost => _isHost;
  String get roomCode => demoRoomCode;
  String get roomName => 'つなぐん デモルーム';
  Duration get eventDuration => _eventDuration;
  Duration get remaining => _remaining;
  Duration get settlementRemaining => _graceRemaining;
  bool get isClosing => _remaining == Duration.zero && _finalSnapshot == null;
  Profile get profileDraft => _profileDraft;
  Participant get self => Participant(
    id: 'self',
    profile: _savedProfile ?? _profileDraft,
    team: Team.red,
    isSelf: true,
  );
  List<Participant> get peers => _fictionalPeers;
  List<Follower> get followers =>
      List.unmodifiable(_collections[self.id] ?? const <Follower>[]);
  Set<String> get completedPeerIds => Set.unmodifiable(_completedPeerIds);
  EncounterResult? get lastResult => _lastResult;
  Participant? get activePeer => _activePeer;
  FinalSnapshot? get finalSnapshot => _finalSnapshot;
  int get normalCount =>
      followers.where((f) => f.kind == FollowerKind.normal).length;
  int get boneCount => followers.length - normalCount;
  int get power => normalCount * 3 + boneCount;

  void createRoom(Duration duration) {
    if (_disposed || _phase != AppPhase.entry) return;
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', '時間は0より長くしてください。');
    }
    _isHost = true;
    _eventDuration = duration;
    _remaining = duration;
    _phase = AppPhase.profile;
    notifyListeners();
  }

  String? joinRoom(String code) {
    if (_disposed || _phase != AppPhase.entry) {
      return '参加手続きを開始できません。';
    }
    if (code.trim().toUpperCase() != demoRoomCode) {
      return 'デモの参加コードは TSUNA です。';
    }
    _isHost = false;
    _eventDuration = defaultDuration;
    _remaining = defaultDuration;
    _phase = AppPhase.profile;
    notifyListeners();
    return null;
  }

  void setProfile({String? nickname, String? hobby, String? comment}) {
    if (_disposed || _phase != AppPhase.profile) return;
    _profileDraft = _profileDraft.copyWith(
      nickname: nickname,
      hobby: hobby,
      comment: comment,
    );
    notifyListeners();
  }

  String? saveProfile() {
    if (_disposed || _phase != AppPhase.profile) return '入力画面から決定してください。';
    final profile = Profile(
      nickname: _profileDraft.nickname.trim(),
      hobby: _profileDraft.hobby.trim(),
      comment: _profileDraft.comment.trim(),
    );
    if (profile.nickname.isEmpty) return 'ニックネームを入力してください。';
    if (profile.hobby.isEmpty) return '趣味を入力してください。';
    if (profile.nickname.characters.length > nicknameLimit) {
      return 'ニックネームは$nicknameLimit文字以内にしてください。';
    }
    if (profile.hobby.characters.length > hobbyLimit) {
      return '趣味は$hobbyLimit文字以内にしてください。';
    }
    if (profile.comment.characters.length > commentLimit) {
      return 'ひとことは$commentLimit文字以内にしてください。';
    }
    _profileDraft = profile;
    _savedProfile = profile;
    _phase = AppPhase.lobby;
    notifyListeners();
    return null;
  }

  /// In participant mode, this simulates the fictional host starting the room.
  void startEvent() {
    if (_disposed || _phase != AppPhase.lobby) return;
    _phase = AppPhase.home;
    _remaining = _eventDuration;
    if (_autoTick) {
      _clock
        ..reset()
        ..start();
      _lastClockReading = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final reading = _clock.elapsed;
        final elapsed = reading - _lastClockReading;
        _lastClockReading = reading;
        advance(elapsed);
      });
    }
    notifyListeners();
  }

  void openPairing() {
    if (_disposed || _phase != AppPhase.home || _remaining <= Duration.zero) {
      return;
    }
    _activePeer = null;
    _lastResult = null;
    _phase = AppPhase.pairing;
    notifyListeners();
  }

  void closePairing() {
    if (_disposed || _phase != AppPhase.pairing) return;
    _activePeer = null;
    _phase = AppPhase.home;
    notifyListeners();
  }

  bool selectPeer(String id) {
    if (_disposed ||
        _phase != AppPhase.pairing ||
        _remaining <= Duration.zero ||
        _completedPeerIds.contains(id)) {
      return false;
    }
    for (final peer in peers) {
      if (peer.id == id) {
        _activePeer = peer;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool confirmPeer() {
    if (_disposed ||
        _phase != AppPhase.pairing ||
        _activePeer == null ||
        _remaining <= Duration.zero ||
        _completedPeerIds.contains(_activePeer!.id)) {
      return false;
    }
    _phase = AppPhase.game;
    notifyListeners();
    return true;
  }

  bool injectOutcome(Outcome outcome) {
    if (_disposed ||
        _phase != AppPhase.game ||
        _activePeer == null ||
        _finalSnapshot != null ||
        (_remaining <= Duration.zero && _graceRemaining <= Duration.zero)) {
      return false;
    }
    final peer = _activePeer!;
    if (_completedPeerIds.contains(peer.id)) return false;
    final cooperative = self.team == peer.team;
    final cooperativeOutcome =
        outcome == Outcome.coopSuccess || outcome == Outcome.coopFailure;
    if (cooperative != cooperativeOutcome) return false;

    // Build both immutable results first, then publish both together.
    final reward = _rules.settle(
      self: self,
      peer: peer,
      outcome: outcome,
      selfFollowers: followers,
      peerFollowers: _collections[peer.id] ?? const [],
    );
    _collections[self.id] = reward.selfFollowers;
    _collections[peer.id] = reward.peerFollowers;
    _completedPeerIds.add(peer.id);
    _lastResult = reward.selfResult;
    _phase = AppPhase.result;
    if (_remaining <= Duration.zero) _freeze();
    notifyListeners();
    return true;
  }

  void returnHome() {
    if (_disposed || _phase != AppPhase.result) return;
    if (_remaining <= Duration.zero) {
      _freeze();
    } else {
      _phase = AppPhase.returning;
    }
    notifyListeners();
  }

  void finishReturn() {
    if (_disposed || _phase != AppPhase.returning) return;
    _activePeer = null;
    if (_remaining <= Duration.zero) {
      _freeze();
    } else {
      _phase = AppPhase.home;
    }
    notifyListeners();
  }

  /// Advances the shared demo event clock, including any bounded settlement.
  /// Overshooting the deadline consumes the grace period in the same call.
  void advance(Duration elapsed) {
    if (_disposed ||
        elapsed <= Duration.zero ||
        _phase == AppPhase.entry ||
        _phase == AppPhase.profile ||
        _phase == AppPhase.lobby ||
        _finalSnapshot != null) {
      return;
    }
    var leftover = elapsed;
    if (_remaining > Duration.zero) {
      if (elapsed < _remaining) {
        _remaining -= elapsed;
        notifyListeners();
        return;
      }
      leftover -= _remaining;
      _remaining = Duration.zero;
      if (_phase != AppPhase.game) {
        _freeze();
        notifyListeners();
        return;
      }
      _graceRemaining = settlementGrace;
    }
    if (_phase == AppPhase.game) {
      _graceRemaining -= leftover;
      if (_graceRemaining <= Duration.zero) _freeze();
    } else {
      _freeze();
    }
    notifyListeners();
  }

  void _freeze() {
    _finalSnapshot ??= _rules.summarize([self, ...peers], _collections);
    _remaining = Duration.zero;
    _graceRemaining = Duration.zero;
    _activePeer = null;
    _phase = AppPhase.finale;
    _stopTimer();
  }

  void showResults() {
    if (_disposed || _phase != AppPhase.finale) return;
    _phase = AppPhase.results;
    notifyListeners();
  }

  void reset() {
    if (_disposed) return;
    _stopTimer();
    _phase = AppPhase.entry;
    _isHost = true;
    _eventDuration = defaultDuration;
    _remaining = defaultDuration;
    _graceRemaining = Duration.zero;
    _profileDraft = const Profile.empty();
    _savedProfile = null;
    _activePeer = null;
    _lastResult = null;
    _finalSnapshot = null;
    _collections.clear();
    _completedPeerIds.clear();
    notifyListeners();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _clock
      ..stop()
      ..reset();
    _lastClockReading = Duration.zero;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}
