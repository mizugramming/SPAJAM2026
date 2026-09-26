import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../cooperative/cooperative_game.dart';
import '../duel/duel_game.dart';

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
      child: Column(
        children: [
          Padding(
            key: const Key('game-status'),
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '${peer.profile.nickname}さんと${cooperative ? '協力' : '対戦'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                Text(
                  remainingLabel,
                  key: const Key('remaining-time'),
                  style: const TextStyle(color: Color(0xFF5C7772)),
                ),
              ],
            ),
          ),
          Expanded(
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
                    onCompleted: (result) => onCompleted(
                      result == DuelGameResult.win ? Outcome.win : Outcome.loss,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
