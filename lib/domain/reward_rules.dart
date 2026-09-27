import 'models.dart';

/// Shared reward and scoring rules, evaluated for both participants together.
class RewardRules {
  const RewardRules();

  RewardPair settle({
    required Participant self,
    required Participant peer,
    required Outcome outcome,
    required List<Follower> selfFollowers,
    required List<Follower> peerFollowers,
  }) {
    if (self.id == peer.id) {
      throw ArgumentError('自分自身とは交流できません。');
    }
    final cooperative = self.team == peer.team;
    final cooperativeOutcome =
        outcome == Outcome.coopSuccess || outcome == Outcome.coopFailure;
    if (cooperative != cooperativeOutcome) {
      throw ArgumentError('所属チームと結果の種類が一致しません。');
    }
    bool hasMet(List<Follower> followers, String participantId) =>
        followers.any(
          (follower) =>
              follower.peerId == participantId ||
              follower.revivedWith?.id == participantId,
        );
    if (hasMet(selfFollowers, peer.id) || hasMet(peerFollowers, self.id)) {
      throw StateError('この相手との交流は完了しています。');
    }

    final first = _apply(self, peer, outcome, selfFollowers);
    final reverseOutcome = switch (outcome) {
      Outcome.win => Outcome.loss,
      Outcome.loss => Outcome.win,
      Outcome.coopSuccess => Outcome.coopSuccess,
      Outcome.coopFailure => Outcome.coopFailure,
    };
    final second = _apply(peer, self, reverseOutcome, peerFollowers);
    return RewardPair(
      selfFollowers: first.followers,
      peerFollowers: second.followers,
      selfResult: first.result,
      peerResult: second.result,
    );
  }

  ({List<Follower> followers, EncounterResult result}) _apply(
    Participant owner,
    Participant peer,
    Outcome outcome,
    List<Follower> previous,
  ) {
    final followers = [...previous];
    Follower? promoted;
    if (outcome == Outcome.coopSuccess) {
      final bones =
          previous
              .where((follower) => follower.kind == FollowerKind.bone)
              .toList()
            ..sort((first, second) {
              final order = first.ordinal.compareTo(second.ordinal);
              return order != 0 ? order : first.id.compareTo(second.id);
            });
      if (bones.isNotEmpty) {
        promoted = bones.first.promote(helpedBy: peer);
        final index = followers.indexWhere((f) => f.id == promoted!.id);
        followers[index] = promoted;
      }
    }

    Follower? added;
    if (promoted == null) {
      var nextOrdinal = 1;
      for (final follower in previous) {
        if (follower.ordinal >= nextOrdinal) {
          nextOrdinal = follower.ordinal + 1;
        }
      }
      added = Follower(
        id: '${owner.id}:${peer.id}',
        ownerId: owner.id,
        peerId: peer.id,
        profile: peer.profile,
        kind: outcome == Outcome.win || outcome == Outcome.coopSuccess
            ? FollowerKind.normal
            : FollowerKind.bone,
        ordinal: nextOrdinal,
      );
      followers.add(added);
    }
    final previousPower = previous.fold(
      0,
      (sum, follower) => sum + follower.power,
    );
    final updatedPower = followers.fold(
      0,
      (sum, follower) => sum + follower.power,
    );
    return (
      followers: List.unmodifiable(followers),
      result: EncounterResult(
        outcome: outcome,
        peer: peer,
        newFollower: added,
        promoted: promoted,
        delta: updatedPower - previousPower,
      ),
    );
  }

  FinalSnapshot summarize(
    List<Participant> participants,
    Map<String, List<Follower>> collections,
  ) {
    final rows =
        participants.map((participant) {
          final followers = collections[participant.id] ?? const <Follower>[];
          final normalCount = followers
              .where((follower) => follower.kind == FollowerKind.normal)
              .length;
          final boneCount = followers.length - normalCount;
          return RankEntry(
            participant: participant,
            normalCount: normalCount,
            boneCount: boneCount,
            power: normalCount * 3 + boneCount,
            rank: 0,
          );
        }).toList()..sort((first, second) {
          final power = second.power.compareTo(first.power);
          return power != 0
              ? power
              : first.participant.id.compareTo(second.participant.id);
        });

    var redPower = 0;
    var bluePower = 0;
    var rank = 0;
    int? previousPower;
    final rankings = <RankEntry>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row.power != previousPower) rank = index + 1;
      previousPower = row.power;
      rankings.add(
        RankEntry(
          participant: row.participant,
          normalCount: row.normalCount,
          boneCount: row.boneCount,
          power: row.power,
          rank: rank,
        ),
      );
      if (row.participant.team == Team.red) {
        redPower += row.power;
      } else {
        bluePower += row.power;
      }
    }
    final highestPower = rankings.isEmpty ? 0 : rankings.first.power;
    return FinalSnapshot(
      redPower: redPower,
      bluePower: bluePower,
      rankings: rankings,
      mvpIds: highestPower == 0
          ? const []
          : rankings
                .where((row) => row.power == highestPower)
                .map((row) => row.participant.id)
                .toList(),
    );
  }
}

class RewardPair {
  RewardPair({
    required List<Follower> selfFollowers,
    required List<Follower> peerFollowers,
    required this.selfResult,
    required this.peerResult,
  }) : selfFollowers = List.unmodifiable(selfFollowers),
       peerFollowers = List.unmodifiable(peerFollowers);

  final List<Follower> selfFollowers;
  final List<Follower> peerFollowers;
  final EncounterResult selfResult;
  final EncounterResult peerResult;
}
