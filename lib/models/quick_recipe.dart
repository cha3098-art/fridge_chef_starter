/// assets/data/quick_recipes.json 한 항목에 대응하는 초간단 레시피 모델
/// (5~10분 내 완성 가능한 레시피 전용 — 기존 recipe.dart의 정식 Recipe와는 별도 데이터셋)
class QuickRecipe {
  final String id;
  final String title;
  final String cuisineType; // 한식/중식/양식/분식/일식
  final int cookTimeMin;
  final List<String> ingredients;
  final List<String> steps;

  /// steps와 같은 길이의 단계별 비주얼 이미지 경로 목록(assets/images/steps/...).
  /// JSON에 stepImages가 없으면(아직 이미지가 준비되지 않은 레시피) 전부 null로 채워지고,
  /// StepVisual이 카테고리 라인 아이콘으로 자동 대체한다.
  final List<String?> stepImages;

  const QuickRecipe({
    required this.id,
    required this.title,
    required this.cuisineType,
    required this.cookTimeMin,
    required this.ingredients,
    required this.steps,
    this.stepImages = const [],
  });

  factory QuickRecipe.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List).cast<String>();
    final stepImages = (json['stepImages'] as List?)?.cast<String?>() ??
        List<String?>.filled(steps.length, null);
    return QuickRecipe(
      id: json['id'] as String,
      title: json['title'] as String,
      cuisineType: json['cuisineType'] as String,
      cookTimeMin: json['cookTimeMin'] as int,
      ingredients: (json['ingredients'] as List).cast<String>(),
      steps: steps,
      stepImages: stepImages,
    );
  }
}
