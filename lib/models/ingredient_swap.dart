/// ingredient_swaps 테이블에 대응하는 식재료 대체 룰 모델
class IngredientSwap {
  final String originalIngredient;
  final String substituteIngredient;
  final String category;
  final String tip;

  const IngredientSwap({
    required this.originalIngredient,
    required this.substituteIngredient,
    required this.category,
    required this.tip,
  });

  factory IngredientSwap.fromRow(Map<String, dynamic> row) {
    return IngredientSwap(
      originalIngredient: row['original_ingredient'] as String,
      substituteIngredient: row['substitute_ingredient'] as String,
      category: row['category'] as String,
      tip: row['tip'] as String,
    );
  }

  Map<String, dynamic> toRow() => {
        'original_ingredient': originalIngredient,
        'substitute_ingredient': substituteIngredient,
        'category': category,
        'tip': tip,
      };
}
