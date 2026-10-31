import 'package:flutter/material.dart';

import 'player_ui.dart';

/// Player entry form. The parent owns joining, shared state, and navigation.
class PlayerJoinView extends StatefulWidget {
  const PlayerJoinView({
    super.key,
    required this.onJoin,
    this.errorMessage,
    this.initialRoomCode = '',
    this.initialDisplayName = '',
  });

  final Future<void> Function(String roomCode, String displayName) onJoin;
  final String? errorMessage;
  final String initialRoomCode;
  final String initialDisplayName;

  @override
  State<PlayerJoinView> createState() => _PlayerJoinViewState();
}

class _PlayerJoinViewState extends State<PlayerJoinView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomCodeController;
  late final TextEditingController _displayNameController;
  bool _isJoining = false;
  String? _unexpectedError;

  @override
  void initState() {
    super.initState();
    _roomCodeController = TextEditingController(text: widget.initialRoomCode);
    _displayNameController = TextEditingController(text: widget.initialDisplayName);
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _clearUnexpectedError(String _) {
    if (_unexpectedError != null) {
      setState(() => _unexpectedError = null);
    }
  }

  Future<void> _join() async {
    if (_isJoining || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final roomCode = _roomCodeController.text.trim();
    final displayName = _displayNameController.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _isJoining = true;
      _unexpectedError = null;
    });

    String? failure;
    try {
      await widget.onJoin(roomCode, displayName);
    } catch (_) {
      failure = '参加できませんでした。もう一度お試しください。';
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isJoining = false;
      _unexpectedError = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    final errorMessage = _unexpectedError ?? widget.errorMessage;
    final hasError = errorMessage != null && errorMessage.trim().isNotEmpty;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: PlayerPage(
        title: 'ゲームに参加',
        eyebrow: 'NIGHT MISSION / ENTRY',
        description: 'ルームコードとプレイヤー名を入力してください。',
        actions: ElevatedButton.icon(
          key: const ValueKey('playerJoinSubmit'),
          onPressed: _isJoining ? null : _join,
          icon: _isJoining
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.login),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_isJoining ? '参加中…' : '参加する')),
        ),
        children: [
          PlayerSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(child: _MissionSignal()),
                const SizedBox(height: 20),
                Text(
                  '準備を整えて、\n探索を始めよう。',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: PlayerNight.text,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '主催者から届いたコードで参加。あなたの名前でミッションへ。',
                  style: theme.textTheme.bodyMedium?.copyWith(color: PlayerNight.muted, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PlayerSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    '探索の準備',
                    style: theme.textTheme.titleMedium?.copyWith(color: PlayerNight.cyan, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('playerJoinRoomCode'),
                  controller: _roomCodeController,
                  enabled: !_isJoining,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                    labelText: 'ルームコード',
                    helperText: '主催者から案内されたコードを入力してください。',
                    helperMaxLines: 4,
                    errorMaxLines: 4,
                    border: OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  onChanged: _clearUnexpectedError,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ルームコードを入力してください。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('playerJoinDisplayName'),
                  controller: _displayNameController,
                  enabled: !_isJoining,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    labelText: 'プレイヤー名',
                    helperText: 'ゲーム内で表示する名前を入力してください。',
                    helperMaxLines: 4,
                    errorMaxLines: 4,
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: _clearUnexpectedError,
                  onFieldSubmitted: (_) => _join(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'プレイヤー名を入力してください。';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 16),
            PlayerNotice(message: errorMessage, icon: Icons.error_outline, isError: true),
          ],
          if (_isJoining) ...[
            const SizedBox(height: 16),
            const PlayerNotice(message: '参加を受け付けています。しばらくお待ちください。', busy: true),
          ],
        ],
      ),
    );
  }
}

class _MissionSignal extends StatelessWidget {
  const _MissionSignal();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 88,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final diameter in [88.0, 64.0])
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: PlayerNight.line),
            ),
          ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: PlayerNight.lime, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.explore_outlined, size: 28, color: PlayerNight.ink),
        ),
        Positioned(
          top: 3,
          right: 17,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: PlayerNight.cyan, shape: BoxShape.circle),
          ),
        ),
      ],
    ),
  );
}
