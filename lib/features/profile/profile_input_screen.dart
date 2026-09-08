import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/room_service.dart';
import '../room/room_screen.dart';
import 'waiting_room_screen.dart';

const _hobbies = [
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
const _topicExamples = [
  ['最近ハマっているもの', '休日にしてみたいこと', '最近ちょっと嬉しかったこと'],
  ['一度行ってみたい場所', 'おすすめしたい作品', '今挑戦してみたいこと'],
  ['最近買ってよかったもの', '子どもの頃に好きだったもの', '理想の休日の過ごし方'],
];

class ProfileInputScreen extends StatefulWidget {
  static const routeName = '/profile-input';
  const ProfileInputScreen({super.key});
  @override
  State<ProfileInputScreen> createState() => _ProfileInputScreenState();
}

class _ProfileInputScreenState extends State<ProfileInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _topic = TextEditingController();
  final _custom = TextEditingController();
  final _nameFocus = FocusNode(),
      _customFocus = FocusNode(),
      _topicFocus = FocusNode();
  final _categoryKey = GlobalKey(),
      _hobbyKey = GlobalKey(),
      _topicKey = GlobalKey();
  ParticipantCategory? _category;
  final Set<String> _selectedHobbies = {};
  bool _submitting = false,
      _categoryError = false,
      _hobbyError = false,
      _pendingError = false;
  int _examples = 0;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
    _topic.addListener(_refresh);
    _custom.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _topic.removeListener(_refresh);
    _custom.removeListener(_refresh);
    _name.dispose();
    _topic.dispose();
    _custom.dispose();
    _nameFocus.dispose();
    _customFocus.dispose();
    _topicFocus.dispose();
    super.dispose();
  }

  void _addHobby() {
    final value = _custom.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _selectedHobbies.add(value);
      _custom.clear();
      _hobbyError = false;
      _pendingError = false;
    });
  }

  Future<void> _show(GlobalKey key, [FocusNode? focus]) async {
    if (key.currentContext != null) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 250),
      );
    }
    focus?.requestFocus();
  }

  void _chooseExample(String text) {
    if (_topic.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('入力中のネタがあります。消してから例を選んでください')),
      );
      return;
    }
    _topic.text = text;
    _topicFocus.requestFocus();
  }

  Future<void> _submit(RoomArgs args) async {
    if (_submitting) return;
    final formOk = _formKey.currentState!.validate();
    final categoryOk = _category != null;
    final hobbyOk = _selectedHobbies.isNotEmpty;
    final pending = _custom.text.trim().isNotEmpty;
    setState(() {
      _categoryError = !categoryOk;
      _hobbyError = !hobbyOk;
      _pendingError = pending;
    });
    if (!formOk || !categoryOk || !hobbyOk || pending) {
      if (_name.text.trim().isEmpty) {
        _nameFocus.requestFocus();
      } else if (!categoryOk) {
        await _show(_categoryKey);
      } else if (!hobbyOk || pending) {
        await _show(_hobbyKey, pending ? _customFocus : null);
      } else {
        await _show(_topicKey, _topicFocus);
      }
      return;
    }
    setState(() => _submitting = true);
    final participant = Participant(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      category: _category!,
      hobbies: _selectedHobbies.toList(),
      submittedTopic: _topic.text.trim(),
      ready: true,
    );
    try {
      final rooms = context.read<RoomProvider>();
      if (args.isHost) {
        if (args.expectedCount == null) {
          throw const FormatException('予定人数がありません');
        }
        await rooms.createRoom(
          expectedCount: args.expectedCount!,
          host: participant,
        );
      } else {
        if (args.code == null) throw const FormatException('部屋番号がありません');
        await rooms.joinRoom(args.code!, participant);
      }
      if (!mounted) return;
      context.read<ProfileProvider>().setProfile(participant);
      Navigator.of(context).pushReplacementNamed(WaitingRoomScreen.routeName);
    } on RoomNotFoundException {
      _error('部屋が見つかりません。部屋番号を確認して、もう一度お試しください');
    } on RoomFullException {
      _error('この部屋は満員です。別の部屋番号を確認してください');
    } on RoomAlreadyStartedException {
      _error('この部屋では会輪が始まっています。別の部屋へ参加してください');
    } catch (_) {
      _error('通信に失敗しました。入力内容は残っています。もう一度お試しください');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ModalRoute.of(context)?.settings.arguments;
    if (value is! RoomArgs) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('画面を開くための情報が不足しています')),
      );
    }
    final done = [
      _name.text.trim().isNotEmpty,
      _category != null,
      _selectedHobbies.isNotEmpty,
      _topic.text.trim().isNotEmpty,
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      appBar: AppBar(title: const Text('あなたの一皿を仕込む')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _submitting ? null : () => _submit(value),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFA74334),
          ),
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.room_service_outlined),
          label: Text(
            _submitting
                ? (value.isHost ? '部屋を作成しています…' : '部屋に参加しています…')
                : '準備完了',
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Welcome(),
                const SizedBox(height: 12),
                _Progress(done),
                const SizedBox(height: 16),
                _Sheet(
                  children: [
                    const _Title('一', 'お名前', '呼ばれたい名前（ニックネームでOK）'),
                    TextFormField(
                      controller: _name,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: const InputDecoration(
                        hintText: '例：りく',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? '呼ばれたい名前を入力してください'
                          : null,
                    ),
                    if (_name.text.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Center(
                          child: Chip(
                            avatar: const Icon(Icons.badge_outlined),
                            label: Text('${_name.text.trim()} さん'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _Title(
                      '二',
                      'あなたの区分',
                      '当てはまるものを1つ選択（必須）',
                      key: _categoryKey,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ParticipantCategory.values.map((c) {
                        final selected = _category == c;
                        return ChoiceChip(
                          label: Text(c.label),
                          avatar: selected
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          selected: selected,
                          selectedColor: const Color(0xFFF4C27A),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFFA74334)
                                : const Color(0xFFD7B787),
                          ),
                          onSelected: (_) => setState(() {
                            _category = c;
                            _categoryError = false;
                          }),
                        );
                      }).toList(),
                    ),
                    if (_categoryError) const _Error('区分を選んでください'),
                    const SizedBox(height: 24),
                    _Title(
                      '三',
                      '趣味・興味の小皿',
                      '1つ以上・複数選べます。気になればOK',
                      key: _hobbyKey,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 9,
                      children: _hobbies
                          .map(
                            (h) => _HobbyPlate(
                              hobby: h,
                              selected: _selectedHobbies.contains(h),
                              onTap: () => setState(() {
                                _selectedHobbies.contains(h)
                                    ? _selectedHobbies.remove(h)
                                    : _selectedHobbies.add(h);
                                _hobbyError = false;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '選んだ小皿 ${_selectedHobbies.length}枚',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedHobbies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          children: _selectedHobbies
                              .map(
                                (h) => InputChip(
                                  label: Text(h),
                                  onDeleted: () => setState(
                                    () => _selectedHobbies.remove(h),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (_hobbyError) const _Error('趣味・興味を1つ以上選んでください'),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _custom,
                            focusNode: _customFocus,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration: InputDecoration(
                              labelText: 'ほかの趣味',
                              errorText: _pendingError ? '「追加」を押してください' : null,
                            ),
                            onSubmitted: (_) => _addHobby(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 56,
                          child: FilledButton.tonalIcon(
                            onPressed: _addHobby,
                            icon: const Icon(Icons.add),
                            label: const Text('追加'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _Title(
                      '四',
                      '持ち込みネタ',
                      'みんなに聞いてみたいこと。短い一言でOK',
                      key: _topicKey,
                    ),
                    TextFormField(
                      controller: _topic,
                      focusNode: _topicFocus,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        hintText: '例：最近買ってよかったもの',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? '持ち込みネタを入力してください'
                          : null,
                    ),
                    const Text(
                      '例をタップすると入力できます',
                      style: TextStyle(fontSize: 12, color: Color(0xFF796450)),
                    ),
                    ..._topicExamples[_examples].map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: OutlinedButton.icon(
                          onPressed: () => _chooseExample(e),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(e),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _examples =
                              (_examples + 1) % _topicExamples.length,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('別の例を見る'),
                      ),
                    ),
                    const Divider(height: 32),
                    _Summary(
                      name: _name.text.trim(),
                      hobbies: _selectedHobbies.toList(),
                      topic: _topic.text.trim(),
                      count: done.where((e) => e).length,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value.isHost
                          ? '準備完了後、この内容で部屋を作ります。'
                          : '準備完了後、この内容で部屋へ参加します。',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF796450),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD89C), Color(0xFFF2B65D)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 29,
            backgroundColor: Colors.white,
            child: Icon(Icons.room_service, size: 34, color: Color(0xFFA74334)),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'いらっしゃい！',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 3),
              Text(
                'みんなで話すきっかけに、呼び名と好きなことを教えてください。',
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress(this.values);
  final List<bool> values;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '4項目中${values.where((e) => e).length}項目完了',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 42,
            height: 16,
            decoration: BoxDecoration(
              color: values[i]
                  ? const Color(0xFFA74334)
                  : const Color(0xFFEAD9BB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFB58A5F)),
            ),
            child: values[i]
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
      ],
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF4),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE2C99E)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F70421E),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.number, this.title, this.subtitle, {super.key});
  final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFA74334),
          child: Text(number, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF796450)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HobbyPlate extends StatelessWidget {
  const _HobbyPlate({
    required this.hobby,
    required this.selected,
    required this.onTap,
  });
  final String hobby;
  final bool selected;
  final VoidCallback onTap;
  IconData get icon => switch (hobby) {
    '旅行' => Icons.luggage_outlined,
    'ゲーム' => Icons.sports_esports_outlined,
    '映画' => Icons.movie_outlined,
    '音楽' => Icons.music_note,
    'アニメ' => Icons.auto_awesome,
    'スポーツ' => Icons.sports_soccer,
    'カフェ' => Icons.local_cafe_outlined,
    '食べ歩き' => Icons.restaurant,
    '読書' => Icons.menu_book,
    '写真' => Icons.photo_camera_outlined,
    '料理' => Icons.soup_kitchen_outlined,
    _ => Icons.favorite_outline,
  };
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$hobby、${selected ? '選択済み' : '未選択'}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 94,
        height: 68,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFDFA7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFA74334) : const Color(0xFFD8C09A),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18704422),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 23, color: const Color(0xFF8B4A35)),
                  const SizedBox(height: 3),
                  Text(
                    hobby,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  size: 17,
                  color: Color(0xFFA74334),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.name,
    required this.hobbies,
    required this.topic,
    required this.count,
  });
  final String name, topic;
  final List<String> hobbies;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDCC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD29A51), width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.ramen_dining, color: Color(0xFFA74334)),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'あなたの一皿',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '$count / 4',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFA74334),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('呼び名：${name.isEmpty ? '未入力' : name}'),
        Text('小皿：${hobbies.isEmpty ? '未選択' : hobbies.join('・')}'),
        Text('ネタ：${topic.isEmpty ? '未入力' : topic}'),
        if (count < 4)
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              '未完了の項目を入力すると一皿が完成します。',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A4C3A)),
            ),
          ),
      ],
    ),
  );
}
