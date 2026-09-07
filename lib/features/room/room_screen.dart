import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    Navigator.of(
      context,
    ).pushNamed(ProfileInputScreen.routeName, arguments: args);
  }

  String get _roomCode => _codeController.text.trim().toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.set_meal, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      '会輪',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('ネタが回れば、会話が回る。'),
                    const SizedBox(height: 32),
                    if (!_isJoining) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('予定参加人数'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final count in _countOptions)
                            ChoiceChip(
                              label: Text('$count人'),
                              selected: _expectedCount == count,
                              onSelected: (_) =>
                                  setState(() => _expectedCount = count),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _goToProfile(
                            RoomArgs(
                              isHost: true,
                              expectedCount: _expectedCount,
                            ),
                          ),
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
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-HJKMNP-Za-hjkmnp-z2-9]'),
                          ),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: '部屋番号',
                          hintText: '例: A7K3PX',
                          counterText: '6文字',
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (_roomCode.length == 6) {
                            _goToProfile(
                              RoomArgs(isHost: false, code: _roomCode),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _roomCode.length == 6
                              ? () => _goToProfile(
                                  RoomArgs(isHost: false, code: _roomCode),
                                )
                              : null,
                          child: const Text('入る'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _codeController.clear();
                          setState(() => _isJoining = false);
                        },
                        child: const Text('戻る'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
