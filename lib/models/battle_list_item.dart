import 'battle.dart';

/// BattleScreen 목록 카드에서 닉네임까지 한 번에 보여주기 위한 뷰 모델.
/// BattleStore.fetchMyBattleItems() / fetchActiveBattleItems()가 만들어준다.
class BattleListItem {
  final Battle battle;
  final String hostNickname;
  final String? challengerNickname;

  const BattleListItem({
    required this.battle,
    required this.hostNickname,
    this.challengerNickname,
  });
}
