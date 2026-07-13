/// user_recipe_history 테이블에 대응하는 요리 완료 자랑 게시물 모델
class CookingBrag {
  final String recipeTitle;
  final String caption;
  final DateTime completedAt;

  /// 사용자가 실제로 촬영/선택한 사진의 로컬 경로 (photo_url 컬럼에 대응)
  /// null이면 레시피 대표 사진으로 대신 보여준다
  final String? photoPath;

  const CookingBrag({
    required this.recipeTitle,
    required this.caption,
    required this.completedAt,
    this.photoPath,
  });
}
