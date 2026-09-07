import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../room/room_screen.dart';
import 'waiting_room_screen.dart';

const _hobbyCandidates = [
  '旅行', 'ゲーム', '映画', '音楽', 'アニメ', 'スポーツ', 'カフェ', '食べ歩き', '読書', '写真', '料理',
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
      _customHobbyController.clear();
    });
  }

  Future<void> _submit(RoomArgs args) async {
    if (!_formKey.currentState!.validate()) return;
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (args.isHost) {
        await roomProvider.createRoom(expectedCount: args.expectedCount!, host: participant);
      } else {
        await roomProvider.joinRoom(args.code!, participant);
      }
      profileProvider.setProfile(participant);
      navigator.pushReplacementNamed(WaitingRoomScreen.routeName);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('部屋への参加に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as RoomArgs;

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
                    decoration: const InputDecoration(labelText: '名前'),
                    validator: (value) => (value == null || value.trim().isEmpty) ? '名前を入力してください' : null,
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
                          onSelected: (_) => setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('趣味(複数選択可)', style: Theme.of(context).textTheme.labelLarge),
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
                            } else {
                              _hobbies.remove(hobby);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customHobbyController,
                          decoration: const InputDecoration(labelText: 'その他の趣味を追加'),
                          onSubmitted: (_) => _addCustomHobby(),
                        ),
                      ),
                      IconButton(onPressed: _addCustomHobby, icon: const Icon(Icons.add_circle)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: '自分から出したい会話テーマ',
                      hintText: '例: 最近買ってよかったもの',
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () => _submit(args),
                    child: const Text('準備完了'),
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
