enum RecipeMatchLevel { full, partial, low }

/// recipes 테이블에 대응하는 레시피 모델
/// 매칭 로직(내 냉장고 재료로 몇 개나 만들 수 있는지)은 여기서 계산한다
class Recipe {
  final String title;
  final int cookTimeMin;
  final String difficulty; // 하/중/상
  final String cuisineType; // 한식/중식/양식/분식
  final int caloriesPerServing;
  final List<String> requiredIngredients;

  const Recipe({
    required this.title,
    required this.cookTimeMin,
    required this.difficulty,
    required this.cuisineType,
    required this.caloriesPerServing,
    required this.requiredIngredients,
  });

  int matchedCount(Set<String> fridgeIngredientNames) =>
      requiredIngredients.where(fridgeIngredientNames.contains).length;

  List<String> missingIngredients(Set<String> fridgeIngredientNames) =>
      requiredIngredients.where((name) => !fridgeIngredientNames.contains(name)).toList();

  RecipeMatchLevel matchLevel(Set<String> fridgeIngredientNames) {
    final matched = matchedCount(fridgeIngredientNames);
    final total = requiredIngredients.length;
    if (matched == total) return RecipeMatchLevel.full;
    if (matched * 2 >= total) return RecipeMatchLevel.partial;
    return RecipeMatchLevel.low;
  }
}
