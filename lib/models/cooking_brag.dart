/// user_recipe_history 테이블에 대응하는 요리 완료 자랑 게시물 모델
class CookingBrag {
  final String recipeTitle;
  final String caption;
  final DateTime completedAt;

  const CookingBrag({
    required this.recipeTitle,
    required this.caption,
    required this.completedAt,
  });
}
