import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../cooperative/cooperative_game.dart';
import '../duel/duel_game.dart';
import 'can_stage.dart';

/// The game owns the full safe viewport. Status and demo tools are overlays,
/// so a future minigame can replace the placeholder without losing play space.
class GameScene extends StatelessWidget {
  const GameScene({
    super.key,
    required this.self,
    required this.peer,
    required this.remainingLabel,
    required this.onDemoMenu,
    required this.onCompleted,
  });

  final Participant self;
  final Participant peer;
  final String remainingLabel;
  final VoidCallback onDemoMenu;
  final ValueChanged<Outcome> onCompleted;

  @override
  Widget build(BuildContext context) {
    final cooperative = peer.team == self.team;
    return SizedBox.expand(
      key: const Key('game-surface'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cooperative)
            CooperativeGame(
              self: self,
              peer: peer,
              onCompleted: (result) => onCompleted(
                result == CooperativeGameResult.success
                    ? Outcome.coopSuccess
                    : Outcome.coopFailure,
              ),
            )
          else
            DuelGame(
              self: self,
              peer: peer,
              onCompleted: (result) => onCompleted(
                result == DuelGameResult.win ? Outcome.win : Outcome.loss,
              ),
            ),
          IgnorePointer(
            child: CanStage(
              phase: AppPhase.game,
              profile: self.profile,
              team: self.team,
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${peer.profile.nickname}さんと${cooperative ? '協力' : '対戦'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remainingLabel,
                        key: const Key('remaining-time'),
                        style: const TextStyle(color: Color(0xFF5C7772)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'デモ操作',
                  child: TextButton(
                    key: const Key('game-demo-menu'),
                    onPressed: onDemoMenu,
                    child: const Text('DEMO'),
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
