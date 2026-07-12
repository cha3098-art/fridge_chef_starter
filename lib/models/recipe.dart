enum RecipeMatchLevel { full, partial, low }

/// recipe_ingredients 테이블에 대응하는 레시피 재료 항목
class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;
  final bool isOptional;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.isOptional = false,
  });

  String get quantityLabel => quantityLabelForServings(1);

  /// 재료 수량은 1인분 기준으로 저장되어 있으므로 선택한 인분수만큼 스케일링한다
  String quantityLabelForServings(int servings) {
    final scaled = quantity * servings;
    final isWhole = scaled == scaled.roundToDouble();
    final q = isWhole ? scaled.toInt().toString() : scaled.toString();
    return '$q$unit';
  }
}

/// recipe_steps 테이블에 대응하는 조리 단계
class RecipeStep {
  final int order;
  final String description;
  final int? timerSec;

  const RecipeStep({required this.order, required this.description, this.timerSec});

  String? get timerLabel {
    final sec = timerSec;
    if (sec == null) return null;
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m == 0) return '$s초';
    if (s == 0) return '$m분';
    return '$m분 $s초';
  }
}

/// recipes 테이블에 대응하는 레시피 모델
/// 매칭 로직(내 냉장고 재료로 몇 개나 만들 수 있는지)은 여기서 계산한다
class Recipe {
  final String title;
  final int cookTimeMin;
  final String difficulty; // 하/중/상
  final String cuisineType; // 한식/중식/양식/분식
  final int caloriesPerServing;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  const Recipe({
    required this.title,
    required this.cookTimeMin,
    required this.difficulty,
    required this.cuisineType,
    required this.caloriesPerServing,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
    required this.ingredients,
    required this.steps,
  });

  /// 필수(비선택) 재료 이름만 — 매칭 계산 대상
  List<String> get requiredIngredients =>
      ingredients.where((i) => !i.isOptional).map((i) => i.name).toList();

  int matchedCount(Set<String> fridgeIngredientNames) =>
      requiredIngredients.where(fridgeIngredientNames.contains).length;

  List<String> missingIngredients(Set<String> fridgeIngredientNames) =>
      requiredIngredients.where((name) => !fridgeIngredientNames.contains(name)).toList();

  RecipeMatchLevel matchLevel(Set<String> fridgeIngredientNames) {
    final matched = matchedCount(fridgeIngredientNames);
    final total = requiredIngredients.length;
    if (total == 0 || matched == total) return RecipeMatchLevel.full;
    if (matched * 2 >= total) return RecipeMatchLevel.partial;
    return RecipeMatchLevel.low;
  }
}
