/// meal_invites 테이블에 대응하는 식사 초대 모델
class MealInvite {
  /// meal_invites.id — 딥링크(https://fridgechef.app/invite/{id})의 조회 키로도 쓰인다
  final String id;
  final String recipeTitle;
  final String message;
  final String inviteLink;
  final DateTime createdAt;
  final String hostNickname;

  const MealInvite({
    required this.id,
    required this.recipeTitle,
    required this.message,
    required this.inviteLink,
    required this.createdAt,
    required this.hostNickname,
  });
}
