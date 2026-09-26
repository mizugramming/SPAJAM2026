import 'package:flutter/foundation.dart';

enum AppPhase {
  entry,
  profile,
  lobby,
  home,
  pairing,
  game,
  result,
  returning,
  finale,
  results,
}

enum Team {
  red,
  blue;

  String get label => this == red ? '赤チーム' : '青チーム';
}

enum Outcome { win, loss, coopSuccess, coopFailure }

enum FollowerKind { normal, bone }

@immutable
class Profile {
  const Profile({
    required this.nickname,
    required this.hobby,
    required this.comment,
  });

  const Profile.empty() : nickname = '', hobby = '', comment = '';

  final String nickname;
  final String hobby;
  final String comment;

  Profile copyWith({String? nickname, String? hobby, String? comment}) {
    return Profile(
      nickname: nickname ?? this.nickname,
      hobby: hobby ?? this.hobby,
      comment: comment ?? this.comment,
    );
  }
}

@immutable
class Participant {
  const Participant({
    required this.id,
    required this.profile,
    required this.team,
    this.isSelf = false,
  });

  final String id;
  final Profile profile;
  final Team team;
  final bool isSelf;
}

@immutable
class Follower {
  const Follower({
    required this.id,
    required this.ownerId,
    required this.peerId,
    required this.profile,
    required this.kind,
    required this.ordinal,
  });

  final String id;
  final String ownerId;
  final String peerId;
  final Profile profile;
  final FollowerKind kind;
  final int ordinal;

  int get power => kind == FollowerKind.normal ? 3 : 1;

  Follower promote() => Follower(
    id: id,
    ownerId: ownerId,
    peerId: peerId,
    profile: profile,
    kind: FollowerKind.normal,
    ordinal: ordinal,
  );
}

@immutable
class EncounterResult {
  const EncounterResult({
    required this.outcome,
    required this.peer,
    required this.newFollower,
    required this.delta,
    this.promoted,
  });

  final Outcome outcome;
  final Participant peer;
  final Follower newFollower;
  final Follower? promoted;
  final int delta;
}

@immutable
class RankEntry {
  const RankEntry({
    required this.participant,
    required this.normalCount,
    required this.boneCount,
    required this.power,
    required this.rank,
  });

  final Participant participant;
  final int normalCount;
  final int boneCount;
  final int power;
  final int rank;
}

@immutable
class FinalSnapshot {
  FinalSnapshot({
    required this.redPower,
    required this.bluePower,
    required List<RankEntry> rankings,
    required List<String> mvpIds,
  }) : rankings = List.unmodifiable(rankings),
       mvpIds = List.unmodifiable(mvpIds);

  final int redPower;
  final int bluePower;
  final List<RankEntry> rankings;
  final List<String> mvpIds;

  bool get isDraw => redPower == bluePower;
  Team? get winnerTeam => isDraw
      ? null
      : redPower > bluePower
      ? Team.red
      : Team.blue;
}
