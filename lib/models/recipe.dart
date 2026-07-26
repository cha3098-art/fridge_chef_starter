enum RecipeMatchLevel { full, partial, low }

/// 부동소수점 곱셈 오차(예: 0.3 * 3 == 0.8999999999999999)를 소수 둘째 자리에서
/// 반올림해 정리하고, 뒤에 붙는 불필요한 0과 소수점은 잘라낸다 (1.50 -> 1.5, 2.00 -> 2)
/// recipe.dart와 l10n/recipe_i18n.dart(영어 단위 환산) 양쪽에서 같이 쓰는 공용 포맷터.
String formatRecipeAmount(double value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

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

  /// 재료 수량은 1인분 기준으로 저장되어 있으므로 선택한 인분수만큼 스케일링한다.
  /// 항상 한글 단위 그대로 표시한다 — 언어별 표시는 l10n/recipe_i18n.dart의
  /// localizedQuantityLabelForServings()를 화면에서 대신 쓴다.
  String quantityLabelForServings(int servings) {
    return '${formatRecipeAmount(quantity * servings)}$unit';
  }
}

/// recipe_steps 테이블에 대응하는 조리 단계
class RecipeStep {
  final int order;
  final String description;
  final String descriptionEn;
  final int? timerSec;

  const RecipeStep({
    required this.order,
    required this.description,
    required this.descriptionEn,
    this.timerSec,
  });
}

/// recipes 테이블에 대응하는 레시피 모델
/// 매칭 로직(내 냉장고 재료로 몇 개나 만들 수 있는지)은 여기서 계산한다
class Recipe {
  final String title;
  final String titleEn;
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

  /// 사진 로딩 실패 시 대신 보여주는 대표 이모지
  final String emoji;

  /// 위키미디어 커먼즈에서 요리명으로 직접 검증한 실제 음식 사진 URL (CC 라이선스)
  final String photoUrl;

  /// K-Food 만들기 메뉴 소속 여부 — K-Food 포인트 트랙에 반영된다
  final bool isKFood;

  const Recipe({
    required this.title,
    required this.titleEn,
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
    required this.emoji,
    required this.photoUrl,
    this.isKFood = false,
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

  /// 이 레시피가 유통기한 임박 재료를 얼마나 "구출"해주는지 점수화한다.
  /// daysLeftByName은 재료 이름 -> 남은 일수 맵 (냉장고에 없는 재료는 키가 없음).
  /// 오늘 만료(0일 이하) 재료를 쓰면 +100, 3일 이내면 +50 — 여러 개 겹치면 누적된다.
  int expiryUrgencyScore(Map<String, int> daysLeftByName) {
    var score = 0;
    for (final name in requiredIngredients) {
      final daysLeft = daysLeftByName[name];
      if (daysLeft == null) continue;
      if (daysLeft <= 0) {
        score += 100;
      } else if (daysLeft <= 3) {
        score += 50;
      }
    }
    return score;
  }
}
