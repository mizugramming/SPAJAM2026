import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/demo_controller.dart';
import '../../domain/models.dart';
import 'can_stage.dart';

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, this.controller});
  final DemoController? controller;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final DemoController demo = widget.controller ?? DemoController();
  final nickname = TextEditingController();
  final hobby = TextEditingController();
  final comment = TextEditingController();
  final roomCode = TextEditingController();
  Timer? returnTimer;
  String? error;
  int durationMinutes = 3;
  int openSheets = 0;
  AppPhase? observedPhase;

  @override
  void initState() {
    super.initState();
    observedPhase = demo.phase;
    demo.addListener(handlePhase);
  }

  void handlePhase() {
    final reachedFinale =
        demo.phase == AppPhase.finale && observedPhase != AppPhase.finale;
    observedPhase = demo.phase;
    if (reachedFinale && openSheets > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && demo.phase == AppPhase.finale && openSheets > 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void dispose() {
    returnTimer?.cancel();
    demo.removeListener(handlePhase);
    nickname.dispose();
    hobby.dispose();
    comment.dispose();
    roomCode.dispose();
    if (widget.controller == null) demo.dispose();
    super.dispose();
  }

  void runAction(void Function() action) {
    setState(() => error = null);
    action();
  }

  void showError(String? message) => setState(() => error = message);

  void returnHome() {
    demo.returnHome();
    returnTimer?.cancel();
    returnTimer = Timer(const Duration(milliseconds: 800), demo.finishReturn);
  }

  void reset() {
    returnTimer?.cancel();
    nickname.clear();
    hobby.clear();
    comment.clear();
    roomCode.clear();
    runAction(demo.reset);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demo,
      builder: (context, _) {
        final phase = demo.phase;
        final inEvent = {
          AppPhase.home,
          AppPhase.pairing,
          AppPhase.game,
          AppPhase.result,
          AppPhase.returning,
        }.contains(phase);
        return PopScope(
          canPop: phase == AppPhase.entry,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && phase == AppPhase.pairing) demo.closePairing();
          },
          child: Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          const Text(
                            'つなぐん',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          Chip(
                            label: const Text('1台用 DEMO'),
                            avatar: const Icon(
                              Icons.science_outlined,
                              size: 16,
                            ),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (inEvent) ...[
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              '${demo.roomName} · ${demo.self.team.label}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              demo.isClosing
                                  ? '終了処理中'
                                  : '残り ${formatTime(demo.remaining)}',
                              key: const Key('remaining-time'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (phase != AppPhase.finale && phase != AppPhase.results)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          child: CanStage(
                            phase: phase,
                            profile: demo.profileDraft,
                            result: demo.lastResult,
                          ),
                        ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        child: Column(
                          key: ValueKey(phase),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: panel(phase),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error!,
                              key: const Key('form-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'このデモの相手は仮想の参加者です。端末間通信・保存は行わず、アプリを閉じるとリセットされます。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF65716C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> panel(AppPhase phase) {
    switch (phase) {
      case AppPhase.entry:
        return [
          heading('今日の出会いを、ひとつの缶に。'),
          const Text('一緒に遊んだ相手が、あなたの子分に。\n集まった仲間と、最後はチームで綱引き。'),
          const SizedBox(height: 20),
          const Text(
            '主催者として始める',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: durationMinutes,
            decoration: const InputDecoration(labelText: '交流する時間'),
            items: [1, 3, 5]
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes 分'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => durationMinutes = value!),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('create-room'),
            onPressed: () => runAction(
              () => demo.createRoom(Duration(minutes: durationMinutes)),
            ),
            child: const Text('ルームをつくる'),
          ),
          const SizedBox(height: 24),
          const Text(
            '参加者として始める',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('room-code'),
            controller: roomCode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'ルームコード',
              helperText: '体験用コード：TSUNA',
            ),
            onSubmitted: (_) => showError(demo.joinRoom(roomCode.text)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('join-room'),
            onPressed: () => showError(demo.joinRoom(roomCode.text)),
            child: const Text('ルームに参加する'),
          ),
        ];
      case AppPhase.profile:
        return [
          heading('はだ缶を、あなたの缶に。'),
          const Text('入力したことが、そのまま缶のラベルになります。'),
          const SizedBox(height: 16),
          profileField(
            'ニックネーム',
            nickname,
            'nickname',
            20,
            (value) => demo.setProfile(nickname: value),
          ),
          profileField(
            '趣味',
            hobby,
            'hobby',
            60,
            (value) => demo.setProfile(hobby: value),
          ),
          profileField(
            'ひとこと（任意）',
            comment,
            'comment',
            80,
            (value) => demo.setProfile(comment: value),
          ),
          FilledButton(
            key: const Key('save-profile'),
            onPressed: () {
              FocusScope.of(context).unfocus();
              showError(demo.saveProfile());
            },
            child: const Text('この缶で参加する'),
          ),
        ];
      case AppPhase.lobby:
        return [
          heading('まもなく、交流の時間。'),
          Text(
            '${demo.roomName}\nルームコード ${demo.roomCode} · ${demo.eventDuration.inMinutes}分',
          ),
          const SizedBox(height: 12),
          const Text('チームは開始時に決まります。'),
          const SizedBox(height: 20),
          if (!demo.isHost) const Text('主催者の開始を待っています。\nデモでは下のボタンで開始を再現できます。'),
          FilledButton(
            key: const Key('start-event'),
            onPressed: () => runAction(demo.startEvent),
            child: Text(demo.isHost ? '交流をはじめる' : '仮想主催者が開始（デモ）'),
          ),
        ];
      case AppPhase.home:
        return [
          heading('${demo.profileDraft.nickname}の仲間たち'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text('子分 ${demo.normalCount} 匹'),
                onPressed: () => showCollection(FollowerKind.normal),
              ),
              ActionChip(
                label: Text('骨 ${demo.boneCount} 匹'),
                onPressed: () => showCollection(FollowerKind.bone),
              ),
              Chip(label: Text('ちから ${demo.power}')),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('meet-peer'),
            onPressed: () => runAction(demo.openPairing),
            icon: const Icon(Icons.people_outline),
            label: const Text('相手とつながる'),
          ),
          const SizedBox(height: 8),
          const Text('同じチームなら協力。違うチームなら対戦。'),
          demoTimeControls(),
        ];
      case AppPhase.pairing:
        final peer = demo.activePeer;
        return [
          heading('仮想の相手を選ぶ'),
          const Text('本番の接続方法は今後実装します。まずは出会ってからの流れを体験。'),
          const SizedBox(height: 12),
          ...demo.peers.map((person) {
            final completed = demo.completedPeerIds.contains(person.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('peer-${person.id}'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: peer?.id == person.id
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Colors.white,
                ),
                onPressed: () {
                  if (completed) {
                    showProfile(person.profile, '交流済み · ${person.team.label}');
                  } else {
                    runAction(() => demo.selectPeer(person.id));
                  }
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${person.profile.nickname}  ·  ${person.team.label}\n${completed ? '交流済み — プロフィールを見る' : person.profile.hobby}',
                  ),
                ),
              ),
            );
          }),
          if (peer != null) ...[
            const SizedBox(height: 8),
            Text(
              '${peer.profile.nickname}さんと${peer.team == demo.self.team ? '協力' : '対戦'}します',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('confirm-peer'),
              onPressed: () => runAction(() => demo.confirmPeer()),
              child: const Text('この相手とはじめる'),
            ),
          ],
          TextButton(
            onPressed: () => runAction(demo.closePairing),
            child: const Text('ホームへ戻る'),
          ),
        ];
      case AppPhase.game:
        final cooperative = demo.activePeer!.team == demo.self.team;
        return [
          heading(
            '${demo.activePeer!.profile.nickname}さんと${cooperative ? '協力' : '対戦'}',
          ),
          if (demo.isClosing)
            const Text('新しい交流は終了しました。このゲームは終了後30秒まで結果を反映できます。'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'デモ操作：ゲームの結果を選ぶ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('positive-outcome'),
                    onPressed: () => demo.injectOutcome(
                      cooperative ? Outcome.coopSuccess : Outcome.win,
                    ),
                    child: Text(cooperative ? '協力に成功' : '対戦に勝つ'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('negative-outcome'),
                    onPressed: () => demo.injectOutcome(
                      cooperative ? Outcome.coopFailure : Outcome.loss,
                    ),
                    child: Text(cooperative ? '協力に失敗' : '対戦に負ける'),
                  ),
                ],
              ),
            ),
          ),
          demoTimeControls(),
        ];
      case AppPhase.result:
        final result = demo.lastResult!;
        final title = switch (result.outcome) {
          Outcome.win => 'やった！新しい仲間。',
          Outcome.loss => '骨の子分も、大切な仲間。',
          Outcome.coopSuccess => '協力、大成功！',
          Outcome.coopFailure => '一緒に挑んだ、そのしるし。',
        };
        return [
          heading(title),
          Text(
            '${result.peer.profile.nickname}さんの${result.newFollower.kind == FollowerKind.bone ? '骨の子分' : '子分'}を獲得。',
          ),
          if (result.promoted != null)
            Text('${result.promoted!.profile.nickname}さんの骨が、元気な子分に成長しました。'),
          if (result.outcome == Outcome.loss)
            const Text('同じチームの人との協力で、骨の子分が元気になります。'),
          const SizedBox(height: 12),
          Text(
            'ちから +${result.delta}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('return-home'),
            onPressed: returnHome,
            child: const Text('ホームへ戻る'),
          ),
        ];
      case AppPhase.returning:
        return [heading('仲間が、あなたの缶へ。'), const LinearProgressIndicator()];
      case AppPhase.finale:
        final snapshot = demo.finalSnapshot!;
        return [
          heading('集まった仲間の、ちからくらべ。'),
          const Text('交流の時間が終わりました。\n仲間のちからをチームで合わせて、いざ綱引き！'),
          const SizedBox(height: 24),
          _TugOfWar(snapshot: snapshot),
          const SizedBox(height: 20),
          Text(
            snapshot.isDraw ? '引き分け！' : '${snapshot.winnerTeam!.label}の勝利！',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text('子分は3、骨は1のちから。交流で集めた仲間の合計が、そのまま結果になります。'),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('show-results'),
            onPressed: demo.showResults,
            child: const Text('みんなの活躍を見る'),
          ),
        ];
      case AppPhase.results:
        final snapshot = demo.finalSnapshot!;
        final mvps = snapshot.rankings.where(
          (entry) => snapshot.mvpIds.contains(entry.participant.id),
        );
        return [
          heading('今日、つながった仲間。'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 36),
                  const Text(
                    '今日のMVP',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mvps.isEmpty
                        ? '今回は該当者なし'
                        : mvps
                              .map(
                                (entry) => entry.participant.profile.nickname,
                              )
                              .join(' ・ '),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    mvps.isEmpty
                        ? 'まだ交流結果がないため、MVPはいません。'
                        : 'いちばん多くのちからを集めた人。\n同点のときは、みんながMVP。',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'このルームのランキング',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...snapshot.rankings.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(
                '${entry.rank}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(
                '${entry.participant.profile.nickname}${entry.participant.isSelf ? '（あなた）' : ''}',
              ),
              subtitle: Text(
                '${entry.participant.team.label} · 子分${entry.normalCount} / 骨${entry.boneCount} · ちから${entry.power}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => showCollection(null),
            child: const Text('集まった仲間を見る'),
          ),
          TextButton(
            key: const Key('reset-demo'),
            onPressed: reset,
            child: const Text('デモを最初から体験する'),
          ),
        ];
    }
  }

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        height: 1.35,
      ),
    ),
  );

  Widget profileField(
    String label,
    TextEditingController controller,
    String id,
    int limit,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: Key(id),
      controller: controller,
      maxLength: limit,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textInputAction: id == 'comment'
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    ),
  );

  Widget demoTimeControls() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => demo.advance(const Duration(seconds: 30)),
          child: const Text('デモ：30秒進める'),
        ),
        TextButton(
          key: const Key('expire-event'),
          onPressed: () => demo.advance(
            demo.remaining +
                (demo.isClosing ? const Duration(seconds: 30) : Duration.zero),
          ),
          child: const Text('デモ：終了時刻へ'),
        ),
      ],
    ),
  );

  void showCollection(FollowerKind? kind) {
    final followers = demo.followers
        .where((follower) => kind == null || follower.kind == kind)
        .toList();
    openSheets++;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .72,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading('あなたの缶の仲間'),
              if (followers.isEmpty) const Text('まだ仲間はいません。交流すると、ここに集まります。'),
              Expanded(
                child: ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Image.asset(
                        follower.kind == FollowerKind.bone
                            ? boneFollowerAsset
                            : normalFollowerAsset,
                        width: 60,
                      ),
                      title: Text(follower.profile.nickname),
                      subtitle: Text(
                        follower.kind == FollowerKind.bone
                            ? '骨の子分 · ちから1'
                            : '子分 · ちから3',
                      ),
                      onTap: () => showProfile(
                        follower.profile,
                        follower.kind == FollowerKind.bone ? '骨の子分' : '子分',
                      ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => openSheets--);
  }

  void showProfile(Profile profile, String kind) {
    openSheets++;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kind),
            heading(profile.nickname),
            const Text('趣味', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(profile.hobby),
            const SizedBox(height: 16),
            const Text('ひとこと', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(profile.comment.isEmpty ? 'まだひとことはありません。' : profile.comment),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    ).whenComplete(() => openSheets--);
  }
}

String formatTime(Duration time) {
  final seconds = time.inSeconds.clamp(0, 86400);
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _TugOfWar extends StatelessWidget {
  const _TugOfWar({required this.snapshot});
  final FinalSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.redPower + snapshot.bluePower;
    final position = total == 0
        ? 0.0
        : (snapshot.bluePower - snapshot.redPower) / total * .7;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 32,
            children: [
              Text(
                '赤チーム\n${snapshot.redPower}',
                style: const TextStyle(
                  color: Color(0xFFB53A36),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '青チーム\n${snapshot.bluePower}',
                style: const TextStyle(
                  color: Color(0xFF215C9B),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(height: 6, color: const Color(0xFFAC9679)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: position),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(seconds: 2),
                  curve: Curves.easeInOutCubic,
                  builder: (context, value, _) => Align(
                    alignment: Alignment(value, 0),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFF186964),
                      size: 48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
