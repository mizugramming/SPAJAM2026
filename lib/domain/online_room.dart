import 'models.dart';

/// Authoritative online snapshots. Presentation code never changes these maps.
class OnlineRoom {
  OnlineRoom.fromJson(Map<String, dynamic> json)
    : code = json['code'] as String,
      mode = json['mode'] as String,
      status = json['status'] as String,
      hostId = json['hostId'] as String,
      selfId = json['selfId'] as String,
      pairCode = json['pairCode'] as String,
      revision = (json['revision'] as num).toInt(),
      serverTime = (json['serverNow'] as num).toInt(),
      endsAt = (json['endsAt'] as num?)?.toInt(),
      finaleStartsAt = (json['finaleStartsAt'] as num?)?.toInt(),
      participants = List.unmodifiable(
        (json['participants'] as List).map(
          (p) => participantFromJson(p, json['selfId'] as String),
        ),
      ),
      followers = List.unmodifiable(
        (json['followers'] as List).map(followerFromJson),
      ),
      encounter = json['encounter'] == null
          ? null
          : OnlineEncounter.fromJson(
              Map<String, dynamic>.from(json['encounter'] as Map),
              json['selfId'] as String,
            ),
      finalSnapshot = json['finalSnapshot'] == null
          ? null
          : finalSnapshotFromJson(
              json['finalSnapshot'],
              json['selfId'] as String,
            );

  final String code, mode, status, hostId, selfId, pairCode;
  final int revision, serverTime;
  final int? endsAt, finaleStartsAt;
  final List<Participant> participants;
  final List<Follower> followers;
  final OnlineEncounter? encounter;
  final FinalSnapshot? finalSnapshot;
  bool get presentation => mode == 'presentation';
}

class OnlineEncounter {
  OnlineEncounter.fromJson(Map<String, dynamic> json, String selfId)
    : id = json['id'] as String,
      kind = json['kind'] as String,
      status = json['status'] as String,
      round = (json['round'] as num).toInt(),
      playerIds = List<String>.unmodifiable(json['playerIds'] as List),
      readyIds = List<String>.unmodifiable(json['readyIds'] as List),
      startAt = (json['startAt'] as num?)?.toInt(),
      fallMs = (json['fallMs'] as num?)?.toInt() ?? 1800,
      decisions = Map<String, dynamic>.unmodifiable(
        json['decisions'] as Map? ?? const {},
      ),
      coop = Map<String, dynamic>.unmodifiable(
        json['coop'] as Map? ?? const {},
      ),
      message = json['message'] as String?,
      result = json['result'] == null
          ? null
          : resultFromJson(json['result'], selfId);

  final String id, kind, status;
  final int round, fallMs;
  final List<String> playerIds, readyIds;
  final int? startAt;
  final Map<String, dynamic> decisions, coop;
  final EncounterResult? result;
  final String? message;
  bool get cooperative => kind == 'coop';
}

Profile profileFromJson(dynamic value) {
  final json = Map<String, dynamic>.from(value as Map);
  return Profile(
    nickname: json['nickname'] as String,
    hobby: json['hobby'] as String,
    comment: json['comment'] as String,
  );
}

Map<String, Object> profileToJson(Profile profile) => {
  'nickname': profile.nickname,
  'hobby': profile.hobby,
  'comment': profile.comment,
};

Participant participantFromJson(dynamic value, [String? selfId]) {
  final json = Map<String, dynamic>.from(value as Map);
  return Participant(
    id: json['id'] as String,
    profile: profileFromJson(json['profile']),
    team: Team.values.byName(json['team'] as String),
    isSelf: json['id'] == selfId,
  );
}

Follower followerFromJson(dynamic value) {
  final json = Map<String, dynamic>.from(value as Map);
  return Follower(
    id: json['id'] as String,
    ownerId: json['ownerId'] as String,
    peerId: json['peerId'] as String,
    profile: profileFromJson(json['profile']),
    kind: FollowerKind.values.byName(json['kind'] as String),
    ordinal: (json['ordinal'] as num).toInt(),
    revivedWith: json['revivedWith'] == null
        ? null
        : participantFromJson(json['revivedWith']),
  );
}

EncounterResult resultFromJson(dynamic value, String selfId) {
  final json = Map<String, dynamic>.from(value as Map);
  return EncounterResult(
    outcome: Outcome.values.byName(json['outcome'] as String),
    peer: participantFromJson(json['peer'], selfId),
    newFollower: json['newFollower'] == null
        ? null
        : followerFromJson(json['newFollower']),
    promoted: json['promoted'] == null
        ? null
        : followerFromJson(json['promoted']),
    delta: (json['delta'] as num).toInt(),
  );
}

FinalSnapshot finalSnapshotFromJson(dynamic value, String selfId) {
  final json = Map<String, dynamic>.from(value as Map);
  return FinalSnapshot(
    redPower: (json['redPower'] as num).toInt(),
    bluePower: (json['bluePower'] as num).toInt(),
    rankings: (json['rankings'] as List)
        .map(
          (dynamic row) => RankEntry(
            participant: participantFromJson(row['participant'], selfId),
            normalCount: (row['normalCount'] as num).toInt(),
            boneCount: (row['boneCount'] as num).toInt(),
            power: (row['power'] as num).toInt(),
            rank: (row['rank'] as num).toInt(),
          ),
        )
        .toList(),
    mvpIds: List<String>.from(json['mvpIds'] as List),
  );
}

/// QR payloads contain a room/invitation code only, never session credentials.
abstract final class OnlineCodes {
  static final _room = RegExp(r'^[A-F0-9]{12}$');
  static final _pair = RegExp(r'^[A-F0-9]{8}$');
  static String _clean(String input) =>
      input.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static String room(String input) {
    final value = input.trim().startsWith('tsunagun:room:')
        ? input.trim().substring('tsunagun:room:'.length)
        : input;
    final code = _clean(value);
    if (!_room.hasMatch(code)) {
      throw const FormatException('ルームのQRか、12桁のルームコードを入力してください。');
    }
    return code;
  }

  static String pair(String input, String expectedRoom) {
    var value = input.trim();
    if (value.startsWith('tsunagun:pair:')) {
      final parts = value.split(':');
      if (parts.length != 4 || parts[2] != expectedRoom) {
        throw const FormatException('同じルームの相手のQRを読み取ってください。');
      }
      value = parts[3];
    }
    final code = _clean(value);
    if (!_pair.hasMatch(code)) {
      throw const FormatException('相手のQRか、8桁の相手コードを入力してください。');
    }
    return code;
  }
}
