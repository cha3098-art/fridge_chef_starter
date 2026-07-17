/// battles.status — 배틀의 진행 단계
enum BattleStatus {
  waitingOpponent,
  submitted,
  voting,
  completed,
  cancelled,
}

extension BattleStatusDb on BattleStatus {
  /// DB check 제약과 동일한 snake_case 값 (battles.status)
  String get dbValue => switch (this) {
        BattleStatus.waitingOpponent => 'waiting_opponent',
        BattleStatus.submitted => 'submitted',
        BattleStatus.voting => 'voting',
        BattleStatus.completed => 'completed',
        BattleStatus.cancelled => 'cancelled',
      };

  static BattleStatus fromDbValue(String value) => switch (value) {
        'waiting_opponent' => BattleStatus.waitingOpponent,
        'submitted' => BattleStatus.submitted,
        'voting' => BattleStatus.voting,
        'completed' => BattleStatus.completed,
        'cancelled' => BattleStatus.cancelled,
        _ => throw ArgumentError('알 수 없는 battle status: $value'),
      };
}

/// battles 테이블에 대응하는 배틀 1건 — 참가자 목록/투표는 BattleParticipant/BattleVote로 별도 관리한다.
class Battle {
  final String id;
  final String hostUserId;
  final String? recipeId;
  final String? themeTitle;
  final BattleStatus status;
  final String? inviteLink;
  final DateTime? votingEndsAt;
  final String? winnerUserId;
  final DateTime createdAt;

  const Battle({
    required this.id,
    required this.hostUserId,
    required this.status,
    required this.createdAt,
    this.recipeId,
    this.themeTitle,
    this.inviteLink,
    this.votingEndsAt,
    this.winnerUserId,
  });
}
