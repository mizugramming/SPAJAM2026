import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../profile/profile_input_screen.dart';
import 'widgets/kaiwa_title_hero.dart';

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

  void _setJoining(bool value) {
    if (_isJoining == value) return;
    FocusScope.of(context).unfocus();
    setState(() => _isJoining = value);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8F0), Color(0xFFF8E5CF)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -72,
              left: -88,
              child: _BackgroundPlate(size: 210),
            ),
            const Positioned(
              bottom: -92,
              right: -78,
              child: _BackgroundPlate(size: 230),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final verticalPadding = keyboardVisible ? 12.0 : 18.0;
                  final minimumHeight =
                      constraints.maxHeight - verticalPadding * 2;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      verticalPadding,
                      16,
                      verticalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minimumHeight > 0 ? minimumHeight : 0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          KaiwaTitleHero(
                            compact: compact,
                            hideCharacter: keyboardVisible,
                          ),
                          SizedBox(height: compact ? 14 : 20),
                          _buildEntryPanel(context),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(242),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD7A449).withAlpha(115)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkBrown.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.group_add_outlined),
                  label: Text('つくる'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.login_rounded),
                  label: Text('参加する'),
                ),
              ],
              selected: {_isJoining},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _setJoining(selection.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isJoining
                ? _buildJoinContent(context)
                : _buildCreateContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateContent(BuildContext context) {
    return Column(
      key: const ValueKey('create-room'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '何人で始めますか？',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.darkBrown,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '一緒に話す人数を選んでください',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.darkBrown.withAlpha(155),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final count in _countOptions)
                ChoiceChip(
                  label: Text('$count人'),
                  selected: _expectedCount == count,
                  selectedColor: AppTheme.vermilion.withAlpha(38),
                  onSelected: (_) => setState(() => _expectedCount = count),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _goToProfile(
              RoomArgs(isHost: true, expectedCount: _expectedCount),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('部屋を作る'),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinContent(BuildContext context) {
    return Column(
      key: const ValueKey('join-room'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '部屋番号を入力',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.darkBrown,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ホストから共有された6文字を入力してください',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.darkBrown.withAlpha(155),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[A-HJKMNP-Za-hjkmnp-z2-9]'),
            ),
            LengthLimitingTextInputFormatter(6),
            const _UpperCaseTextFormatter(),
          ],
          decoration: InputDecoration(
            labelText: '6文字の部屋番号',
            hintText: '例: A7K3PX',
            prefixIcon: const Icon(Icons.tag_rounded),
            counterText: '${_roomCode.length} / 6',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_roomCode.length == 6) {
              _goToProfile(RoomArgs(isHost: false, code: _roomCode));
            }
          },
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _roomCode.length == 6
                ? () => _goToProfile(RoomArgs(isHost: false, code: _roomCode))
                : null,
            icon: const Icon(Icons.login_rounded),
            label: const Text('部屋に参加する'),
          ),
        ),
      ],
    );
  }
}

class _BackgroundPlate extends StatelessWidget {
  const _BackgroundPlate({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFD7A449).withAlpha(34),
            width: 18,
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      composing: TextRange.empty,
    );
  }
}
