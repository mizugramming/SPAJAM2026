import 'package:flutter/material.dart';

import '../game/game.dart';
import 'phrase_text.dart';

class GameSettingsPage extends StatefulWidget {
  const GameSettingsPage({
    super.key,
    required this.strokesToGold,
    required this.onSave,
    required this.onOpenDiagnostics,
  });

  final int strokesToGold;
  final Future<void> Function(int value) onSave;
  final VoidCallback onOpenDiagnostics;

  @override
  State<GameSettingsPage> createState() => _GameSettingsPageState();
}

class _GameSettingsPageState extends State<GameSettingsPage> {
  late final _count = TextEditingController(
    text: widget.strokesToGold.toString(),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _count.text.trim().replaceAllMapped(
      RegExp('[０-９]'),
      (m) => (m[0]!.codeUnitAt(0) - 0xFF10).toString(),
    );
    final value = int.tryParse(text, radix: 10);
    if (value == null ||
        value < GameController.minStrokesToGold ||
        value > GameController.maxStrokesToGold) {
      setState(() {
        _error =
            '${GameController.minStrokesToGold}〜${GameController.maxStrokesToGold}の整数を入力してください。';
      });
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSave(value);
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存できませんでした。もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text('磨く回数', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const PhraseText(
                  '粗目でメダルを\n金にするまでの\n往復数です。\n「漢」を磨く回数も\n同じ割合で変わります。',
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('strokes-to-gold'),
                  controller: _count,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: '往復数',
                    suffixText: '往復',
                    helperText:
                        '${GameController.minStrokesToGold}〜${GameController.maxStrokesToGold}往復（標準${GameController.defaultStrokesToGold}往復）',
                    helperMaxLines: 2,
                    errorText: _error,
                    errorMaxLines: 4,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('save-settings'),
                  onPressed: _saving ? null : _save,
                  child: const Text('設定を保存'),
                ),
                const Divider(height: 44),
                ListTile(
                  key: const ValueKey('open-device-lab'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('端末の計測'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_saving,
                  onTap: widget.onOpenDiagnostics,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
