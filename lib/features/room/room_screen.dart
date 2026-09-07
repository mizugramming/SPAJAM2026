import 'package:flutter/material.dart';

import '../profile/profile_input_screen.dart';

class RoomArgs {
  const RoomArgs({required this.isHost, this.expectedCount, this.code});

  final bool isHost;
  final int? expectedCount; // isHost=trueのとき使用
  final String? code; // isHost=falseのとき使用
}

class RoomScreen extends StatefulWidget {
  static const routeName = '/';

  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  static const _countOptions = [3, 4, 5, 6];

  int _expectedCount = 4;
  bool _isJoining = false;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _goToProfile(RoomArgs args) {
    Navigator.of(context).pushNamed(ProfileInputScreen.routeName, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.set_meal, size: 64),
              const SizedBox(height: 16),
              Text('会輪', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('ネタが回れば、会話が回る。'),
              const SizedBox(height: 32),
              if (!_isJoining) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('予定参加人数')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final count in _countOptions)
                      ChoiceChip(
                        label: Text('$count人'),
                        selected: _expectedCount == count,
                        onSelected: (_) => setState(() => _expectedCount = count),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _goToProfile(RoomArgs(isHost: true, expectedCount: _expectedCount)),
                    child: const Text('部屋を作る'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isJoining = true),
                    child: const Text('部屋に入る'),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: '部屋番号(6文字)'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final code = _codeController.text.trim().toUpperCase();
                      if (code.isEmpty) return;
                      _goToProfile(RoomArgs(isHost: false, code: code));
                    },
                    child: const Text('入る'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isJoining = false),
                  child: const Text('戻る'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
