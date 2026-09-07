import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/room_service.dart';
import '../room/room_screen.dart';
import 'waiting_room_screen.dart';

const _hobbyCandidates = [
  '旅行',
  'ゲーム',
  '映画',
  '音楽',
  'アニメ',
  'スポーツ',
  'カフェ',
  '食べ歩き',
  '読書',
  '写真',
  '料理',
];

class ProfileInputScreen extends StatefulWidget {
  static const routeName = '/profile-input';

  const ProfileInputScreen({super.key});

  @override
  State<ProfileInputScreen> createState() => _ProfileInputScreenState();
}

class _ProfileInputScreenState extends State<ProfileInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _customHobbyController = TextEditingController();
  ParticipantCategory _category = ParticipantCategory.student;
  final Set<String> _hobbies = {};
  bool _isSubmitting = false;
  bool _showHobbyError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _customHobbyController.dispose();
    super.dispose();
  }

  void _addCustomHobby() {
    final value = _customHobbyController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _hobbies.add(value);
      _showHobbyError = false;
      _customHobbyController.clear();
    });
  }

  Future<void> _submit(RoomArgs args) async {
    final formIsValid = _formKey.currentState!.validate();
    final hobbiesAreValid = _hobbies.isNotEmpty;
    setState(() => _showHobbyError = !hobbiesAreValid);
    if (!formIsValid || !hobbiesAreValid) return;

    setState(() => _isSubmitting = true);

    final participant = Participant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      category: _category,
      hobbies: _hobbies.toList(),
      submittedTopic: _topicController.text.trim(),
      ready: true,
    );

    final roomProvider = context.read<RoomProvider>();
    final profileProvider = context.read<ProfileProvider>();
    try {
      if (args.isHost) {
        final expectedCount = args.expectedCount;
        if (expectedCount == null) throw const FormatException('予定人数がありません');
        await roomProvider.createRoom(
          expectedCount: expectedCount,
          host: participant,
        );
      } else {
        final code = args.code;
        if (code == null) throw const FormatException('部屋番号がありません');
        await roomProvider.joinRoom(code, participant);
      }
      if (!mounted) return;
      profileProvider.setProfile(participant);
      Navigator.of(context).pushReplacementNamed(WaitingRoomScreen.routeName);
    } on RoomNotFoundException {
      _showError('入力した部屋番号の部屋が見つかりません');
    } on RoomFullException {
      _showError('この部屋は満員です');
    } on RoomAlreadyStartedException {
      _showError('この部屋では、すでに会輪が始まっています');
    } catch (_) {
      _showError('通信に失敗しました。時間をおいてもう一度お試しください');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is! RoomArgs) {
      return Scaffold(
        appBar: AppBar(),
        body: const SafeArea(child: Center(child: Text('画面を開くための情報が不足しています'))),
      );
    }
    final args = arguments;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール入力')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSubmitting,
          child: Opacity(
            opacity: _isSubmitting ? 0.6 : 1,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: const InputDecoration(
                      labelText: '名前',
                      hintText: '例: 山田 太郎',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '名前を入力してください'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text('区分', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final category in ParticipantCategory.values)
                        ChoiceChip(
                          label: Text(category.label),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '趣味(複数選択可)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hobby in {..._hobbyCandidates, ..._hobbies})
                        FilterChip(
                          label: Text(hobby),
                          selected: _hobbies.contains(hobby),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _hobbies.add(hobby);
                              _showHobbyError = false;
                            } else {
                              _hobbies.remove(hobby);
                            }
                          }),
                        ),
                    ],
                  ),
                  if (_showHobbyError) ...[
                    const SizedBox(height: 8),
                    Text(
                      '趣味を1つ以上選んでください',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customHobbyController,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(20),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'その他の趣味を追加',
                          ),
                          onSubmitted: (_) => _addCustomHobby(),
                        ),
                      ),
                      IconButton(
                        onPressed: _addCustomHobby,
                        icon: const Icon(Icons.add_circle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _topicController,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    decoration: const InputDecoration(
                      labelText: '自分から出したい会話テーマ',
                      hintText: '例: 最近買ってよかったもの',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '会話テーマを入力してください'
                        : null,
                    onFieldSubmitted: (_) => _submit(args),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => _submit(args),
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('準備完了'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
