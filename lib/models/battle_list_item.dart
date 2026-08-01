import 'battle.dart';

/// BattleScreen 목록 카드에서 닉네임·득표수까지 한 번에 보여주기 위한 뷰 모델.
/// BattleStore.fetchMyBattleItems() / fetchActiveBattleItems()가 만들어준다.
class BattleListItem {
  final Battle battle;
  final String hostNickname;
  final String? hostParticipantId;
  final int hostVotes;
  final String? hostGender;
  final String? challengerNickname;
  final String? challengerParticipantId;
  final String? challengerUserId;
  final int challengerVotes;
  final String? challengerGender;

  /// 현재 로그인한 유저가 이 배틀의 참가자라면 그 participant id (호스트든 상대든).
  final String? myParticipantId;

  /// 현재 로그인한 유저가 이미 투표했다면 그 투표 대상 participant id.
  final String? myVoteParticipantId;

  const BattleListItem({
    required this.battle,
    required this.hostNickname,
    this.hostParticipantId,
    this.hostVotes = 0,
    this.hostGender,
    this.challengerNickname,
    this.challengerParticipantId,
    this.challengerUserId,
    this.challengerVotes = 0,
    this.challengerGender,
    this.myParticipantId,
    this.myVoteParticipantId,
  });
}
