import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../cooperative/cooperative_game.dart';
import '../duel/duel_game.dart';
import '../duel/sea_background.dart';

/// The scene fills the safe viewport. Status takes only its measured height;
/// the game receives the remaining space so enlarged text cannot cover play.
class GameScene extends StatelessWidget {
  const GameScene({
    super.key,
    required this.self,
    required this.peer,
    required this.remainingLabel,
    required this.onDemoMenu,
    required this.onCompleted,
    this.onResolved,
  });

  final Participant self;
  final Participant peer;
  final String remainingLabel;
  final VoidCallback onDemoMenu;
  final ValueChanged<Outcome> onCompleted;
  final ValueChanged<Outcome>? onResolved;

  @override
  Widget build(BuildContext context) {
    final cooperative = peer.team == self.team;
    return SizedBox.expand(
      key: const Key('game-surface'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ゲームと同じ缶の内側の背景を、上部の帯の後ろにも敷く。背景は幅に合わせて
          // 下端をそろえるので、ゲームが自分の領域に描く背景と境目でずれない。
          const Positioned.fill(
            child: IgnorePointer(child: SeaBackground(elapsed: Duration.zero)),
          ),
          Column(
            children: [
              Padding(
                key: const Key('game-status'),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Plate(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${peer.profile.nickname}さんと${cooperative ? '協力' : '対戦'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              remainingLabel,
                              key: const Key('remaining-time'),
                              style: const TextStyle(color: Color(0xFF5C7772)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Plate(
                      padding: EdgeInsets.zero,
                      child: Tooltip(
                        message: 'デモ操作',
                        child: TextButton(
                          key: const Key('game-demo-menu'),
                          onPressed: onDemoMenu,
                          child: const Text('DEMO'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // Game painters may extend beyond their local origin (e.g. rope).
                // Keep that paint inside the assigned area and off the header.
                child: ClipRect(
                  child: cooperative
                      ? CooperativeGame(
                          self: self,
                          peer: peer,
                          onCompleted: (result) => onCompleted(
                            result == CooperativeGameResult.success
                                ? Outcome.coopSuccess
                                : Outcome.coopFailure,
                          ),
                        )
                      : DuelGame(
                          self: self,
                          peer: peer,
                          onResolved: (result) => onResolved?.call(
                            result == DuelGameResult.win
                                ? Outcome.win
                                : Outcome.loss,
                          ),
                          onCompleted: (result) => onCompleted(
                            result == DuelGameResult.win
                                ? Outcome.win
                                : Outcome.loss,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 上部の帯の文字の後ろに敷く、薄い灰色の板。背景の絵の上でも読めるようにする。
class _Plate extends StatelessWidget {
  const _Plate({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xCCE6E8EB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(padding: padding, child: child),
  );
}
