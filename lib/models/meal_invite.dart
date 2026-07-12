/// meal_invites 테이블에 대응하는 식사 초대 모델
class MealInvite {
  final String recipeTitle;
  final String message;
  final String inviteLink;
  final DateTime createdAt;

  const MealInvite({
    required this.recipeTitle,
    required this.message,
    required this.inviteLink,
    required this.createdAt,
  });
}
