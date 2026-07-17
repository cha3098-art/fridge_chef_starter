/// battle_votes 테이블에 대응하는 투표 1건 — 유저당 배틀 하나에 투표 1표만 가능하다 (DB unique 제약).
class BattleVote {
  final String id;
  final String battleId;
  final String voterId;
  final String votedForParticipantId;
  final DateTime createdAt;

  const BattleVote({
    required this.id,
    required this.battleId,
    required this.voterId,
    required this.votedForParticipantId,
    required this.createdAt,
  });
}
