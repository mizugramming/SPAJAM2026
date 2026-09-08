import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/participant.dart';
import '../../models/room.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../conversation/conversation_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  static const routeName = '/waiting-room';
  const WaitingRoomScreen({super.key});
  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false, _starting = false;
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();
  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  void _navigate(Room? room) {
    if (_navigated || room == null || room.status != RoomStatus.inProgress) {
      return;
    }
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(ConversationScreen.routeName);
      }
    });
  }

  Future<void> _start(Room room) async {
    if (_starting ||
        room.participants.isEmpty ||
        room.status != RoomStatus.waiting) {
      return;
    }
    setState(() => _starting = true);
    final choices = List.of(room.participants)..shuffle();
    final first = choices.first;
    final people = [
      for (final p in room.participants)
        p.id == first.id ? p.copyWith(selectionCount: p.selectionCount + 1) : p,
    ];
    try {
      await context.read<RoomProvider>().updateRoom(
        room.copyWith(
          status: RoomStatus.inProgress,
          currentRound: 1,
          currentSelectorId: first.id,
          participants: people,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会輪を開始できませんでした。通信状態を確認して、もう一度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('部屋番号をコピーしました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room,
        me = context.watch<ProfileProvider>().profile;
    if (room == null || me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _navigate(room);
    final isHost =
        room.participants.isNotEmpty && room.participants.first.id == me.id;
    final allReady =
        room.participants.length >= room.expectedCount &&
        room.participants.every((p) => p.ready);
    final ready = room.participants.where((p) => p.ready).length;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      appBar: AppBar(
        title: const Text('会輪のお待ち処'),
        actions: [
          if (kDebugMode && isHost)
            IconButton(
              tooltip: '人数を待たずに入る(テスト用/臨時)',
              icon: const Icon(Icons.bolt),
              onPressed: _starting ? null : () => _start(room),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                children: [
                  FadeTransition(
                    opacity: _arrival,
                    child: SlideTransition(
                      position:
                          Tween(
                            begin: const Offset(0, .15),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _arrival,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                      child: const _Arrival(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RoomCode(code: room.code, onCopy: () => _copy(room.code)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'カウンターのお席',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '準備完了 $ready／${room.expectedCount}人',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA74334),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < room.expectedCount; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _Seat(
                        index: i,
                        participant: i < room.participants.length
                            ? room.participants[i]
                            : null,
                        myId: me.id,
                        hostId: room.participants.first.id,
                      ),
                    ),
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    collapsedBackgroundColor: Colors.white,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: Color(0xFFE2C99E)),
                    ),
                    leading: const Icon(
                      Icons.account_circle_outlined,
                      color: Color(0xFFA74334),
                    ),
                    title: const Text(
                      '自分の一皿を確認',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${me.name}・${me.category.label}'),
                            const SizedBox(height: 6),
                            Text('趣味：${me.hobbies.join('・')}'),
                            const SizedBox(height: 6),
                            Text('持ち込みネタ：${me.submittedTopic}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFCF4),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: isHost
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          allReady
                              ? '全員の一皿がそろいました。会輪を始められます。'
                              : 'あと ${room.expectedCount - room.participants.length} 人の参加を待っています。',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: allReady && !_starting
                                ? () => _start(room)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFA74334),
                            ),
                            icon: _starting
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(_starting ? '会輪を始めています…' : '会輪をはじめる'),
                          ),
                        ),
                      ],
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '準備できました。ホストが会輪を始めるまでお待ちください。',
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrival extends StatelessWidget {
  const _Arrival();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD99F), Color(0xFFF1B65E)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: Colors.white,
          child: Icon(Icons.room_service, size: 32, color: Color(0xFFA74334)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '一皿、届きました！',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 3),
              Text('準備できました。あとはみんなを待つだけです。', style: TextStyle(height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoomCode extends StatelessWidget {
  const _RoomCode({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF4),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFD5A35B), width: 2),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.confirmation_number_outlined,
          color: Color(0xFFA74334),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '部屋番号',
                style: TextStyle(fontSize: 12, color: Color(0xFF796450)),
              ),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '部屋番号をコピー',
          onPressed: onCopy,
          icon: const Icon(Icons.copy),
        ),
      ],
    ),
  );
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.index,
    required this.participant,
    required this.myId,
    required this.hostId,
  });
  final int index;
  final Participant? participant;
  final String myId, hostId;
  @override
  Widget build(BuildContext context) {
    final p = participant, occupied = p != null;
    return Semantics(
      label: occupied
          ? '${p.name}、${p.ready ? '準備完了' : '準備中'}'
          : '席${index + 1}、参加待ち',
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: occupied ? Colors.white : const Color(0xFFF0E5D2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: occupied ? const Color(0xFFD49C51) : const Color(0xFFD8C8AE),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 17,
              decoration: BoxDecoration(
                color: occupied
                    ? const Color(0xFFFFD58B)
                    : const Color(0xFFE2D5C1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFB58455), width: 1.5),
              ),
              child: occupied
                  ? const Icon(Icons.check, size: 12, color: Color(0xFF7A3B2E))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    occupied ? p.name : 'お席 ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    occupied ? (p.ready ? '準備完了' : '準備中') : '参加待ち',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF796450),
                    ),
                  ),
                ],
              ),
            ),
            if (occupied && p.id == myId) const _Badge('あなた'),
            if (occupied && p.id == hostId)
              const Padding(
                padding: EdgeInsets.only(left: 5),
                child: _Badge('ホスト'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFA74334),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
