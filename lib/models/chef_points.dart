/// 포인트를 준 이유 — 마이 화면의 "최근 포인트 내역"에 그대로 노출된다
enum PointReason {
  cook,
  kfoodCook,
  kfoodInviteBonus,
  weeklyMission,
  firstIngredient,
  fullMatchCook,
  firstTry,
  boardLikes,
}

/// 포인트 적립 한 건. isKFoodTrack이 true면 K-Food 누적 점수에도 더해진다.
/// labelKo/labelEn을 둘 다 저장해서, 나중에 언어를 바꿔도 과거 내역까지 올바르게 보인다.
class PointEvent {
  final PointReason reason;
  final int amount;
  final bool isKFoodTrack;
  final String labelKo;
  final String labelEn;
  final DateTime timestamp;

  const PointEvent({
    required this.reason,
    required this.amount,
    required this.isKFoodTrack,
    required this.labelKo,
    required this.labelEn,
    required this.timestamp,
  });
}

/// 난이도별 기본 포인트 가중치 — 하 1배, 중 2배, 상 3배
int difficultyWeight(String difficulty) {
  switch (difficulty) {
    case '상':
      return 3;
    case '중':
      return 2;
    default:
      return 1;
  }
}
