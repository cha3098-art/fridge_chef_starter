/// 배틀 코멘트 최대 길이 — DB check 제약(char_length <= 200)과 동일한 값.
const battleCommentMaxLength = 200;

/// battle_participants.role — 1:1 대결이라 배틀당 host/opponent 각 1명으로 제한된다 (DB unique 제약)
enum BattleParticipantRole {
  host,
  opponent,
}

extension BattleParticipantRoleDb on BattleParticipantRole {
  String get dbValue =>
      this == BattleParticipantRole.host ? 'host' : 'opponent';

  static BattleParticipantRole fromDbValue(String value) => switch (value) {
        'host' => BattleParticipantRole.host,
        'opponent' => BattleParticipantRole.opponent,
        _ => throw ArgumentError('알 수 없는 참가자 role: $value'),
      };
}

/// battle_participants 테이블에 대응하는 배틀 참가자 1명 — 완성 사진(photoPath)을 제출하면 submittedAt이 채워진다.
/// comment는 사진과 함께 남기는 짧은 한마디(최대 200자, 선택 사항)다.
class BattleParticipant {
  final String id;
  final String battleId;
  final String userId;
  final BattleParticipantRole role;
  final String? photoPath;
  final String? comment;
  final DateTime? submittedAt;
  final DateTime joinedAt;

  const BattleParticipant({
    required this.id,
    required this.battleId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.photoPath,
    this.comment,
    this.submittedAt,
  });

  bool get hasSubmitted => submittedAt != null;
}
