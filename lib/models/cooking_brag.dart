/// user_recipe_history 테이블에 대응하는 요리 완료 자랑 게시물 모델
class CookingBrag {
  /// 사용자가 직접 입력한 게시글 제목 (상세화면/목록에 표시되는 제목)
  final String title;
  /// "만든 레시피" 선택값 — 카탈로그 매칭(포인트 적립)용. 직접입력 시 사용자가 쓴 이름 그대로 저장된다.
  final String recipeTitle;
  final String caption;
  final DateTime completedAt;

  /// 사용자가 실제로 촬영/선택한 사진의 로컬 경로 (photo_url 컬럼에 대응)
  /// null이면 레시피 대표 사진으로 대신 보여준다
  final String? photoPath;

  /// 글쓰기 화면에서 사용자가 직접 고른 장식 프레임 카테고리 (예: '한식', '이탈리아식').
  /// 상세 화면에서 food_visuals.dart의 bragFrameAsset()으로 실제 프레임 이미지를 찾는 키로 쓰인다.
  final String frameCategory;

  const CookingBrag({
    required this.title,
    required this.recipeTitle,
    required this.caption,
    required this.completedAt,
    required this.frameCategory,
    this.photoPath,
  });
}
