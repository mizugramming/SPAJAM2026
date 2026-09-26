import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/tsunagun_theme.dart';
import '../../data/demo_controller.dart';
import '../../domain/models.dart';
import 'can_stage.dart';
import 'game_scene.dart';
import 'illustrated_details.dart';
import 'tug_of_war_finale.dart';

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
  final sceneScroll = ScrollController();
  String? error;
  int durationMinutes = 3;
  int openSheets = 0;
  int encounterGeneration = 0;
  AppPhase? observedPhase;

  @override
  void initState() {
    super.initState();
    observedPhase = demo.phase;
    demo.addListener(handlePhase);
  }

  void handlePhase() {
    final changed = demo.phase != observedPhase;
    final reachedFinale =
        demo.phase == AppPhase.finale && observedPhase != AppPhase.finale;
    final leftGame =
        observedPhase == AppPhase.game && demo.phase != AppPhase.game;
    if (changed && demo.phase == AppPhase.game) encounterGeneration++;
    observedPhase = demo.phase;
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !sceneScroll.hasClients) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          sceneScroll.jumpTo(0);
        } else {
          sceneScroll.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    if ((reachedFinale || leftGame) && openSheets > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            (demo.phase == AppPhase.finale ||
                (leftGame && demo.phase != AppPhase.game)) &&
            openSheets > 0) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  @override
  void dispose() {
    demo.removeListener(handlePhase);
    nickname.dispose();
    hobby.dispose();
    comment.dispose();
    roomCode.dispose();
    sceneScroll.dispose();
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
  }

  void reset() {
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
        const scenePadding = EdgeInsets.fromLTRB(20, 14, 20, 24);
        final peerId = demo.activePeer?.id;
        final generation = encounterGeneration;
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: phase == AppPhase.game
                    ? GameScene(
                        key: ValueKey(generation),
                        self: demo.self,
                        peer: demo.activePeer!,
                        remainingLabel: demo.isClosing
                            ? '結果の受付 残り ${formatTime(demo.settlementRemaining)}'
                            : '残り ${formatTime(demo.remaining)}',
                        onDemoMenu: showGameDemoMenu,
                        onCompleted: (outcome) =>
                            completeGame(generation, peerId!, outcome),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          controller: sceneScroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: scenePadding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: phase == AppPhase.entry
                                  ? (constraints.maxHeight -
                                            scenePadding.vertical)
                                        .clamp(0.0, double.infinity)
                                  : 0,
                            ),
                            child: Column(
                              mainAxisAlignment: phase == AppPhase.entry
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    const TsunagunWordmark(),
                                    TextButton.icon(
                                      key: const Key('demo-info'),
                                      onPressed: showDemoInfo,
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                      ),
                                      label: const Text('1台用 DEMO'),
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: demo.self.team == Team.red
                                              ? TsunagunColors.red
                                              : TsunagunColors.blue,
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
                                if (phase != AppPhase.finale &&
                                    phase != AppPhase.results)
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeInOut,
                                    child: CanStage(
                                      phase: phase,
                                      profile: demo.profileDraft,
                                      result: demo.lastResult,
                                      team: inEvent ? demo.self.team : null,
                                      onReturnComplete: demo.finishReturn,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  switchInCurve: Curves.easeOut,
                                  child: Column(
                                    key: ValueKey(phase),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
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
          heading('あなたのラベル'),
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
              TextButton.icon(
                onPressed: () => showCollection(FollowerKind.normal),
                icon: Image.asset(
                  normalFollowerAsset,
                  width: 28,
                  height: 28,
                  excludeFromSemantics: true,
                ),
                label: Text('子分 ${demo.normalCount} 匹'),
              ),
              TextButton.icon(
                onPressed: () => showCollection(FollowerKind.bone),
                icon: Image.asset(
                  boneFollowerAsset,
                  width: 28,
                  height: 28,
                  excludeFromSemantics: true,
                ),
                label: Text('骨 ${demo.boneCount} 匹'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Text(
                  'ちから ${demo.power}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('meet-peer'),
            onPressed: () => runAction(demo.openPairing),
            icon: const Icon(Icons.waving_hand_outlined),
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
          const SizedBox(height: 12),
          ...demo.peers.map((person) {
            final completed = demo.completedPeerIds.contains(person.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                key: Key('peer-${person.id}'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () {
                  if (completed) {
                    showProfile(person.profile, '交流済み · ${person.team.label}');
                  } else {
                    runAction(() => demo.selectPeer(person.id));
                  }
                },
                icon: Icon(
                  peer?.id == person.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                ),
                label: Align(
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
        // GameScene occupies the viewport outside the scrolling panels.
        return const [];
      case AppPhase.result:
        final result = demo.lastResult!;
        final isSetback =
            result.outcome == Outcome.loss ||
            result.outcome == Outcome.coopFailure;
        final title = switch (result.outcome) {
          Outcome.win => '新しい仲間が、缶にやってきた！',
          Outcome.loss || Outcome.coopFailure => '骨の子分も、大切な仲間。',
          Outcome.coopSuccess => '力を合わせて、元気いっぱい！',
        };
        return [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSetback
                ? '同じチームと協力ゲーム！\n力を合わせて、元気にしよう。'
                : result.promoted != null
                ? '${result.promoted!.profile.nickname}の子分が、元気に！'
                : '${result.peer.profile.nickname}と、ツナがった！',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.7),
          ),
          if (result.promoted != null &&
              result.promoted!.id != result.newFollower.id)
            Text(
              '${result.peer.profile.nickname}の骨の子分も仲間入り！',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.7),
            ),
          const SizedBox(height: 12),
          Text(
            'ちから +${result.delta}',
            textAlign: TextAlign.center,
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
        return [heading('仲間が、あなたの缶へ。')];
      case AppPhase.finale:
        return [
          TugOfWarFinale(
            snapshot: demo.finalSnapshot!,
            onShowResults: demo.showResults,
          ),
        ];
      case AppPhase.results:
        final snapshot = demo.finalSnapshot!;
        final mvps = snapshot.rankings.where(
          (entry) => snapshot.mvpIds.contains(entry.participant.id),
        );
        return [
          heading('今日、つながった仲間。'),
          Padding(
            padding: EdgeInsets.zero,
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
        fontWeight: FontWeight.w900,
        height: 1.4,
        color: TsunagunColors.ink,
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

  void completeGame(int generation, String peerId, Outcome outcome) {
    // Ignore duplicate, expired, and previous-game callbacks, including
    // callbacks from a room that was reset and started again.
    if (!mounted ||
        generation != encounterGeneration ||
        demo.phase != AppPhase.game ||
        demo.activePeer?.id != peerId) {
      return;
    }
    runAction(() => demo.injectOutcome(outcome));
  }

  Future<void> showGameDemoMenu() async {
    final peer = demo.activePeer;
    if (demo.phase != AppPhase.game || peer == null || openSheets > 0) return;
    final cooperative = peer.team == demo.self.team;
    final generation = encounterGeneration;
    openSheets++;
    Outcome? outcome;
    try {
      outcome = await showModalBottomSheet<Outcome>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading('デモ操作'),
              const Text('ミニゲームの結果を選んで、続きを確認できます。'),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('positive-outcome'),
                onPressed: () => Navigator.pop(
                  sheetContext,
                  cooperative ? Outcome.coopSuccess : Outcome.win,
                ),
                child: Text(cooperative ? '協力に成功' : '対戦に勝つ'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('negative-outcome'),
                onPressed: () => Navigator.pop(
                  sheetContext,
                  cooperative ? Outcome.coopFailure : Outcome.loss,
                ),
                child: Text(cooperative ? '協力に失敗' : '対戦に負ける'),
              ),
              demoTimeControls(),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('ゲームへ戻る'),
              ),
            ],
          ),
        ),
      );
    } finally {
      openSheets--;
    }
    if (outcome != null) completeGame(generation, peer.id, outcome);
  }

  void showDemoInfo() {
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
            heading('1台用の体験デモ'),
            const Text('相手は仮想の参加者です。ミニゲームは結果を選んで体験できます。'),
            const SizedBox(height: 12),
            const Text('端末間通信・保存は行いません。アプリを閉じると、入力や仲間はリセットされます。'),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(follower.profile.hobby),
                          const SizedBox(height: 4),
                          Text(
                            follower.kind == FollowerKind.bone
                                ? '骨の子分 · ちから1'
                                : '子分 · ちから3',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  kind == '骨の子分' ? boneFollowerAsset : normalFollowerAsset,
                  width: 80,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind),
                      const SizedBox(height: 4),
                      heading(profile.nickname),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('趣味', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(profile.hobby),
            const SizedBox(height: 18),
            const Text('ひとこと', style: TextStyle(fontWeight: FontWeight.w800)),
            FollowerQuote(
              text: profile.comment.isEmpty ? 'まだひとことはありません。' : profile.comment,
            ),
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
