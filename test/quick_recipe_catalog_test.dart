import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_chef/data/quick_recipe_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quick_recipes.json이 20종 모두 파싱된다', () async {
    final recipes = await QuickRecipeCatalog.load();
    expect(recipes.length, 20);

    for (final recipe in recipes) {
      expect(recipe.id, isNotEmpty);
      expect(recipe.title, isNotEmpty);
      expect(recipe.cuisineType, isNotEmpty);
      expect(recipe.cookTimeMin, greaterThan(0));
      expect(recipe.ingredients, isNotEmpty);
      expect(recipe.steps, isNotEmpty);
    }

    final ids = recipes.map((r) => r.id).toSet();
    expect(ids.length, 20, reason: 'id가 중복되지 않아야 한다');
  });
}
