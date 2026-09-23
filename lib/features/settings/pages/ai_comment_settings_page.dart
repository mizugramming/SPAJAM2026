import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/providers/ai_comment_settings_provider.dart';

class AiCommentSettingsPage extends ConsumerStatefulWidget {
  const AiCommentSettingsPage({super.key});

  @override
  ConsumerState<AiCommentSettingsPage> createState() =>
      _AiCommentSettingsPageState();
}

class _AiCommentSettingsPageState extends ConsumerState<AiCommentSettingsPage> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _loadedInitial = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save({bool? enabled}) async {
    setState(() => _saving = true);
    await ref
        .read(aiCommentSettingsProvider.notifier)
        .save(enabled: enabled, apiKey: _keyController.text.trim());
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiCommentSettingsProvider);
    final settings = settingsAsync.value;
    if (settings != null && !_loadedInitial) {
      _keyController.text = settings.apiKey;
      _loadedInitial = true;
    }

    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AIコメント'),
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DesignTokens.surface.withValues(alpha: .7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DesignTokens.border),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: DesignTokens.gold,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '送信される内容について',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'この記録は、基本的に端末の中だけに保存されます。\n'
                            'ただしAIコメントをオンにすると、その日の記録(気持ち・'
                            'テーマ・時刻・メモの文章)がOpenAIのAPIへ送信され、'
                            '一言コメントの生成に使われます。\n'
                            'オフのままなら、これまでどおり何も送信されません。',
                            style: TextStyle(
                              fontSize: 12,
                              color: DesignTokens.muted,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('AIコメントを有効にする'),
                      subtitle: const Text(
                        '星座のメッセージをAI生成のコメントに置き換えます',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: settings.enabled,
                      onChanged: (value) {
                        if (value && _keyController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('先にAPIキーを入力して保存してください'),
                            ),
                          );
                          return;
                        }
                        _save(enabled: value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keyController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'OpenAI APIキー',
                        hintText: 'sk-...',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'キーはこの端末内(ローカル設定)にのみ保存されます。暗号化はされないため、'
                      '共有端末では入力しないでください。',
                      style: TextStyle(fontSize: 11, color: DesignTokens.muted),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('キーを保存'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
